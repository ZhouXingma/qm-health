//
//  ChatStreamAccumulator.swift
//  QmHealth
//
//  Created by Kiro on 2026/7/15.
//
//  负责把后端新版流式协议（ChatStreamEvent / EventType）逐帧转换为
//  单条 DisplayChatMessage 的内容块（复用 MessageContentBlock 模型，
//  但仅作为内存态表示，不涉及历史详情的解码逻辑，两者互不影响）。
//
//  设计要点：
//  - 一次 RUN（由 RUN_STARTED ~ RUN_FINISHED/RUN_ERROR 界定）对应一条 assistant 消息，
//    thinking / text / 工具调用按时间顺序合并进同一个 contents 数组，天然对应
//    "思考 -> 工具调用 -> 文本输出" 的展示顺序，不再需要按 runId 做多消息分组合并。
//  - 用 runId 作为该消息的锚点 id（每个事件都会携带 runId），避免依赖内部的
//    replyId（同一个 run 中可能因多次模型调用而变化）。
//

import Foundation

/// 处理单次 AI 响应（一个 run）的流式事件，增量维护一条 DisplayChatMessage
final class ChatStreamAccumulator {

    // MARK: - 对外回调

    /// 有新的 assistant 消息被创建（RUN_STARTED 时触发一次）
    var onMessageCreated: ((DisplayChatMessage) -> Void)?
    /// 消息内容发生变化（用于触发滚动等）
    var onMessageUpdated: ((DisplayChatMessage) -> Void)?
    /// run 正常结束
    var onRunFinished: ((DisplayChatMessage) -> Void)?
    /// run 出错
    var onRunError: ((DisplayChatMessage, String) -> Void)?
    /// 收到机制 A（Permission ASK）的权限确认请求 —— 与消息流独立，
    /// 由调用方展示在输入框上方的授权条中，而不是塞进消息内容里
    var onPendingConfirmations: (([PendingToolConfirmation]) -> Void)?
    /// 收到某个 toolCallId 的执行结果，但该 id 不属于当前 run（典型场景：
    /// 权限确认后的恢复请求是一个全新的 run，TOOL_CALL_START/END 发生在
    /// 被拦截的上一个 run，结果却在这个新 run 里返回）。
    /// 由调用方在历史消息中定位到对应的 toolUse 块并回填 result。
    var onExternalToolResult: ((String, String) -> Void)?

    // MARK: - 当前 run 状态

    private(set) var message: DisplayChatMessage?
    private var contents: [MessageContentBlock] = []

    private var textBlockIndex: [String: Int] = [:]
    private var thinkingBlockIndex: [String: Int] = [:]
    private var toolUseIndex: [String: Int] = [:]
    private var toolResultBuffer: [String: String] = [:]

    /// 会话/发起方信息，用于创建新消息
    private let conversationIdProvider: () -> String?

    init(conversationIdProvider: @escaping () -> String? = { nil }) {
        self.conversationIdProvider = conversationIdProvider
    }

    // MARK: - 主入口

    func apply(_ event: ChatStreamEvent) {
        switch event.type {
        case ChatEventType.RUN_STARTED:
            startRun(event)

        case ChatEventType.MODEL_CALL_START, ChatEventType.MODEL_CALL_END:
            break // 暂不特殊展示，思考/工具块本身已能反映进度

        case ChatEventType.TEXT_START:
            handleBlockStart(event, indexMap: \Self.textBlockIndex) { .text(TextBlockMessage(text: "")) }

        case ChatEventType.TEXT:
            handleBlockDelta(event, indexMap: \Self.textBlockIndex,
                              extract: { if case .text(let b) = $0 { return b.text } else { return nil } },
                              build: { .text(TextBlockMessage(text: $0)) })

        case ChatEventType.TEXT_END:
            break

        case ChatEventType.THINKING_START:
            handleBlockStart(event, indexMap: \Self.thinkingBlockIndex) { .thinking(ThinkingBlockMessage(thinking: "")) }

        case ChatEventType.THINKING:
            handleBlockDelta(event, indexMap: \Self.thinkingBlockIndex,
                              extract: { if case .thinking(let b) = $0 { return b.thinking } else { return nil } },
                              build: { .thinking(ThinkingBlockMessage(thinking: $0)) })

        case ChatEventType.THINKING_END:
            break

        case ChatEventType.TOOL_CALL_START:
            handleToolCallStart(event)

        case ChatEventType.TOOL_CALL_DELTA:
            handleToolCallDelta(event)

        case ChatEventType.TOOL_CALL_END:
            handleToolCallEnd(event)

        case ChatEventType.TOOL_RESULT_START:
            if let toolCallId = event.dataString("toolCallId") {
                toolResultBuffer[toolCallId] = ""
            }

        case ChatEventType.TOOL_RESULT_TEXT_DELTA:
            handleToolResultTextDelta(event)

        case ChatEventType.TOOL_RESULT_DATA_DELTA:
            handleToolResultDataDelta(event)

        case ChatEventType.TOOL_CALL_RESULT:
            handleToolResultEnd(event)

        case ChatEventType.CUSTOM:
            handleCustom(event)

        case ChatEventType.RUN_FINISHED:
            finishRun()

        case ChatEventType.RUN_ERROR:
            failRun(event)

        case ChatEventType.RUN_RESULT, ChatEventType.RAW:
            break

        default:
            break
        }
    }

    // MARK: - 生命周期

    private func startRun(_ event: ChatStreamEvent) {
        let anchorId = event.runId ?? event.id ?? ULIDUtils.generate()
        let timestamp = DateUtils.dateToTimestamp(Date())

        contents = []
        textBlockIndex.removeAll()
        thinkingBlockIndex.removeAll()
        toolUseIndex.removeAll()
        toolResultBuffer.removeAll()

        let newMessage = DisplayChatMessage(
            conversationId: event.conversationId ?? conversationIdProvider(),
            runId: event.runId,
            messageId: anchorId,
            role: .assistant,
            purpose: .chat,
            timestamp: timestamp,
            contents: [],
            displayState: .responding
        )
        message = newMessage
        onMessageCreated?(newMessage)
    }

    private func finishRun() {
        guard let message = message else { return }
        message.markAsSuccess()
        onRunFinished?(message)
    }

    private func failRun(_ event: ChatStreamEvent) {
        guard let message = message else { return }
        let errMsg = event.dataString("message") ?? "AI 响应出现错误"
        if contents.isEmpty {
            contents.append(.text(TextBlockMessage(text: "抱歉，AI 响应出现错误，请稍后重试")))
            message.updateContents(contents)
        }
        message.markAsFailed(error: errMsg)
        onRunError?(message, errMsg)
    }

    // MARK: - 文本 / 思考块（复用同一套 start/delta 逻辑）

    private func handleBlockStart(_ event: ChatStreamEvent, indexMap: ReferenceWritableKeyPath<ChatStreamAccumulator, [String: Int]>, makeEmpty: () -> MessageContentBlock) {
        guard let blockId = event.dataString("blockId") else { return }
        contents.append(makeEmpty())
        self[keyPath: indexMap][blockId] = contents.count - 1
        commit()
    }

    private func handleBlockDelta(
        _ event: ChatStreamEvent,
        indexMap: ReferenceWritableKeyPath<ChatStreamAccumulator, [String: Int]>,
        extract: (MessageContentBlock) -> String?,
        build: (String) -> MessageContentBlock
    ) {
        guard let blockId = event.dataString("blockId") else { return }
        let delta = event.dataString("delta") ?? ""

        if let idx = self[keyPath: indexMap][blockId], idx < contents.count, let existing = extract(contents[idx]) {
            contents[idx] = build(existing + delta)
        } else {
            contents.append(build(delta))
            self[keyPath: indexMap][blockId] = contents.count - 1
        }
        commit()
    }

    // MARK: - 工具调用

    private func handleToolCallStart(_ event: ChatStreamEvent) {
        guard let toolCallId = event.dataString("toolCallId") else { return }
        let name = event.dataString("toolCallName") ?? ""
        contents.append(.toolUse(ToolUseBlockMessage(id: toolCallId, name: name, input: AnyCodable(""), content: "", result: nil)))
        toolUseIndex[toolCallId] = contents.count - 1
        commit()
    }

    private func handleToolCallDelta(_ event: ChatStreamEvent) {
        guard let toolCallId = event.dataString("toolCallId"),
              let idx = toolUseIndex[toolCallId],
              idx < contents.count,
              case .toolUse(let existing) = contents[idx] else { return }
        let delta = event.dataString("delta") ?? ""
        contents[idx] = .toolUse(ToolUseBlockMessage(
            id: existing.id,
            name: existing.name,
            input: existing.input,
            content: (existing.content ?? "") + delta,
            result: existing.result,
            metadata: existing.metadata
        ))
        commit()
    }

    private func handleToolCallEnd(_ event: ChatStreamEvent) {
        guard let toolCallId = event.dataString("toolCallId"),
              let idx = toolUseIndex[toolCallId],
              idx < contents.count,
              case .toolUse(let existing) = contents[idx] else { return }

        // 工具调用参数以 JSON 字符串形式流式传输，结束时尝试解析为结构化对象，
        // 便于 ask_user 等特殊工具解析 input 字典。
        var parsedInput = existing.input
        if let contentStr = existing.content, !contentStr.isEmpty,
           let data = contentStr.data(using: .utf8),
           let jsonObj = try? JSONSerialization.jsonObject(with: data) {
            parsedInput = AnyCodable(jsonObj)
        }

        contents[idx] = .toolUse(ToolUseBlockMessage(
            id: existing.id,
            name: existing.name,
            input: parsedInput,
            content: existing.content,
            result: existing.result,
            metadata: existing.metadata
        ))
        commit()
    }

    // MARK: - 工具结果

    private func handleToolResultTextDelta(_ event: ChatStreamEvent) {
        guard let toolCallId = event.dataString("toolCallId") else { return }
        let delta = event.dataString("delta") ?? ""
        toolResultBuffer[toolCallId, default: ""] += delta
    }

    private func handleToolResultDataDelta(_ event: ChatStreamEvent) {
        guard let toolCallId = event.dataString("toolCallId") else { return }
        if let value = event.dataValue("data") {
            let str: String
            if let s = value as? String {
                str = s
            } else if JSONSerialization.isValidJSONObject(value),
                      let jsonData = try? JSONSerialization.data(withJSONObject: value),
                      let jsonStr = String(data: jsonData, encoding: .utf8) {
                str = jsonStr
            } else {
                str = String(describing: value)
            }
            toolResultBuffer[toolCallId, default: ""] += str
        }
    }

    private func handleToolResultEnd(_ event: ChatStreamEvent) {
        guard let toolCallId = event.dataString("toolCallId") else { return }

        guard let idx = toolUseIndex[toolCallId],
              idx < contents.count,
              case .toolUse(let existing) = contents[idx] else {
            // 该 toolCallId 不属于当前 run（权限确认恢复场景：TOOL_CALL_START/END
            // 发生在上一个被拦截的 run，结果却在恢复后的新 run 里返回）。
            // 上抛给调用方，在历史消息中定位对应的 toolUse 块并回填。
            if let result = toolResultBuffer[toolCallId], !result.isEmpty {
                onExternalToolResult?(toolCallId, result)
            }
            toolResultBuffer.removeValue(forKey: toolCallId)
            return
        }

        let result = toolResultBuffer[toolCallId] ?? existing.result ?? ""
        contents[idx] = .toolUse(ToolUseBlockMessage(
            id: existing.id,
            name: existing.name,
            input: existing.input,
            content: existing.content,
            result: result.isEmpty ? nil : result,
            metadata: existing.metadata
        ))
        toolResultBuffer.removeValue(forKey: toolCallId)
        commit()
    }

    // MARK: - CUSTOM 事件

    private func handleCustom(_ event: ChatStreamEvent) {
        guard let name = event.dataString("name") else { return }

        switch name {
        case "require_user_confirm":
            handleRequireUserConfirm(event)
        default:
            // hint_block / subagent_exposed / request_stop 等暂不在消息流中展示
            break
        }
    }

    /// require_user_confirm：机制 A（Permission ASK）—— 工具尚未执行，权限引擎
    /// 要求用户确认"是否允许调用"。这与 TOOL_CALL_START/END 已经生成的工具调用
    /// 卡片是同一个 toolCallId，不应再往 contents 里追加重复的 toolUse 块，
    /// 而是作为独立于消息内容的"待授权项"上抛，交由 UI 在输入框上方渲染确认条。
    private func handleRequireUserConfirm(_ event: ChatStreamEvent) {
        guard let toolCalls = event.dataArray("value") else { return }

        var pending: [PendingToolConfirmation] = []
        for item in toolCalls {
            guard let dict = item as? [String: Any] else { continue }
            let id = (dict["toolCallId"] as? String) ?? (dict["id"] as? String)
            guard let toolCallId = id else { continue }

            let name = (dict["toolCallName"] as? String) ?? (dict["name"] as? String) ?? ""
            let rawInput = dict["input"] ?? dict["arguments"]

            pending.append(PendingToolConfirmation(
                id: toolCallId,
                name: name,
                input: rawInput != nil ? AnyCodable(rawInput!) : nil
            ))
        }

        guard !pending.isEmpty else { return }
        onPendingConfirmations?(pending)
    }

    // MARK: - 公共提交

    private func commit() {
        guard let message = message else { return }
        message.updateContents(contents)
        onMessageUpdated?(message)
    }
}
