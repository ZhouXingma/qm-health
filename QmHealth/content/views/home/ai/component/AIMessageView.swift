//
//  AIMessageView.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/2/10.
//  Redesigned by Kiro on 2026/7/15 — 全新视觉设计：推理时间线 + 简洁文本流。
//

import SwiftUI

// MARK: - 消息结束状态标记

/// 消息非正常结束的原因，用于向用户展示结束标签
enum MessageEndTag: Equatable {
    case interrupted            // 用户点击"停止"中断
    case runError(String)       // 模型/运行异常（携带异常信息）
    case aborted(String)        // 节点崩溃，由 HA 补偿终止（携带补偿原因）
}

/// 从消息（组）中解析结束标记。结束状态互斥，按优先级：用户中断 > 运行异常 > 补偿终止
func resolveMessageEndTag(_ messages: [DisplayChatMessage]) -> MessageEndTag? {
    if messages.contains(where: { $0.isInterrupted }) {
        return .interrupted
    }
    if let reason = messages.compactMap({ $0.runErrorReason }).first {
        return .runError(reason)
    }
    if let reason = messages.compactMap({ $0.runAbortReason }).first {
        return .aborted(reason)
    }
    return nil
}

// AI 消息视图 - 观察单条消息，转交 AIMessageContentView 渲染
struct AIMessageView: View {
    @ObservedObject var message: DisplayChatMessage
    var onAskUserResponse: ((InteractiveHandleBlockMessage) -> Void)?

    var body: some View {
        AIMessageContentView(
            contents: message.contents,
            displayState: message.displayState,
            messageId: message.id,
            endTag: resolveMessageEndTag([message]),
            onAskUserResponse: onAskUserResponse
        )
    }
}

/// AI 消息内容视图 —— 只依赖「内容块数组 + 展示状态」这两个值，
/// 不持有 ObservableObject。这样无论内容来自单条消息还是同一个 run 内
/// 多条消息的合并结果，都能走同一套渲染逻辑，并且刷新范围被限制在这里。
struct AIMessageContentView: View {
    let contents: [MessageContentBlock]
    let displayState: MessageDisplayState
    let messageId: String
    /// 该消息（或组合消息组）的结束状态标记，用于显示"已中断 / 运行异常 / 已终止"
    var endTag: MessageEndTag?
    var onAskUserResponse: ((InteractiveHandleBlockMessage) -> Void)?

    /// 是否正在流式输出中
    private var isResponding: Bool { displayState == .responding }

    var body: some View {
        VStack(alignment: .leading, spacing: ChatTheme.spacingMd) {
            // 将 contents 分组：推理链路（thinking + toolUse）和其他内容
            let groups = groupMessageContents(contents)
            // 正在输出时，最后一个文本块才是真正在增长的那一块，
            // 只对它启用逐字节奏控制，前面已经完成的文本块保持静态
            let lastTextId = groups.last { if case .text = $0.group { return true } else { return false } }?.id

            // 用稳定 id 而不是下标做 ForEach 标识：流式过程中分组数量会变化
            // （例如文本块之后又出现一次思考，推理卡片会被插到最前面），
            // 用下标会让文本视图连同它的逐字节拍器一起被重建、动画从头开始
            ForEach(groups) { item in
                switch item.group {
                case .reasoningChain(let items):
                    // 推理链路 - 可折叠的卡片
                    ReasoningChainView(items: items)
                    
                case .text(let textBlock):
                    AITextMessageView(
                        text: textBlock.text,
                        isStreaming: isResponding && item.id == lastTextId
                    )
                    
                case .askUser(let toolUseBlock):
                    // ask_user 工具特殊处理：根据 result 字段判断用户是否已回复
                    // result 为空、为 "null" 或不存在时，显示交互表单
                    // result 有有效内容时，显示用户的回复
                    if let result = toolUseBlock.result, !result.isEmpty, result != "null" {
                        // 已有结果（用户已回复），显示用户的回复
                        AIAskUserResponseView(toolUse: toolUseBlock, result: result)
                    } else {
                        // 否则显示交互表单
                        AIAskUserMessageView(
                            messageId: messageId,
                            toolUse: toolUseBlock,
                            onSubmit: onAskUserResponse
                        )
                    }
                }
            }
            
            // 生成中的持续提示：只要这条消息仍处于 .responding 状态就一直显示，
            // 不会因为已经渲染出推理过程/正文就消失 —— 模型在多次增量之间常有
            // 数秒停顿（工具执行、下一段模型调用等），这段小动效负责覆盖这些空隙，
            // 避免用户以为程序卡住。等待用户操作的 ask_user 表单不显示（那是用户的回合）。
            if isResponding && !isWaitingForAskUser(groups) {
                TypingDotsIndicator()
                    .padding(.leading, 2)
                    .transition(.opacity)
            }

            // 非正常结束的标记：中断 / 运行异常 / 补偿终止
            if let endTag = endTag {
                MessageEndTagView(tag: endTag)
            }

            // 复制按钮：消息结束（非流式）且含文本时，在底部左侧提供，复制汇总后的全文
            if shouldShowCopyButton {
                AICopyButton(text: copyableText)
                    .padding(.top, ChatTheme.spacingXs)
            }
        }.frame(maxWidth: .infinity, alignment: .center)
    }

    /// 当前可复制的消息全文：汇总所有文本内容块
    private var copyableText: String {
        contents.compactMap { block -> String? in
            if case .text(let textBlock) = block { return textBlock.text }
            return nil
        }
        .joined(separator: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 消息结束（非流式）且包含文本时才显示复制按钮
    private var shouldShowCopyButton: Bool {
        !isResponding && !copyableText.isEmpty
    }

    /// 消息结束状态标签：图标 + 文案，异常/补偿场景附带原因
    private struct MessageEndTagView: View {
        let tag: MessageEndTag

        var body: some View {
            VStack(alignment: .leading, spacing: 3) {
                switch tag {
                case .interrupted:
                    row(icon: "stop.circle.fill", text: "已中断", color: ChatTheme.textSecondary)
                case .runError(let reason):
                    row(icon: "exclamationmark.triangle.fill", text: "运行异常", color: ChatTheme.danger)
                    if !reason.isEmpty {
                        detail(reason)
                    }
                case .aborted(let reason):
                    row(icon: "xmark.circle.fill", text: "已终止", color: ChatTheme.warning)
                    if !reason.isEmpty {
                        detail(reason)
                    }
                }
            }
            .padding(.top, 2)
        }

        private func row(icon: String, text: String, color: Color) -> some View {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(text)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(color)
        }

        private func detail(_ reason: String) -> some View {
            Text(reason)
                .font(.system(size: 11))
                .foregroundStyle(ChatTheme.textSecondary.opacity(0.7))
                .lineLimit(2)
        }
    }
    
    /// 最后一组是否是"等待用户填写 ask_user 表单"——此时轮到用户操作，不应显示打字指示
    private func isWaitingForAskUser(_ groups: [IdentifiedContentGroup]) -> Bool {
        guard case .askUser(let toolUseBlock) = groups.last?.group else { return false }
        let result = toolUseBlock.result
        return result == nil || result!.isEmpty || result == "null"
    }
    
    // 将消息内容分组：推理链路和其他内容
    // 策略：一个消息中所有的 thinking 和 toolUse（非 ask_user）归纳为一个推理链路
    // text 内容和 ask_user 单独显示
    // 每个分组带一个稳定 id，保证流式过程中视图（及其内部状态）不被重建
    private func groupMessageContents(_ contents: [MessageContentBlock]) -> [IdentifiedContentGroup] {
        var groups: [IdentifiedContentGroup] = []
        var reasoningChainItems: [ReasoningChainItem] = []
        var textOrdinal = 0
        
        // 第一遍：收集所有推理链路项（thinking 和普通 toolUse）
        for content in contents {
            switch content {
            case .thinking(let thinkingBlock):
                reasoningChainItems.append(.thinking(thinkingBlock.thinking))
                
            case .toolUse(let toolUseBlock):
                if !toolUseBlock.isAskUserTool {
                    // 普通工具调用加入推理链路
                    reasoningChainItems.append(.toolUse(toolUseBlock))
                }
                
            default:
                break
            }
        }
        
        // 如果有推理链路项，先添加推理链路组
        if !reasoningChainItems.isEmpty {
            groups.append(IdentifiedContentGroup(id: "reasoning", group: .reasoningChain(reasoningChainItems)))
        }
        
        // 第二遍：添加 text 和 ask_user（保持顺序）
        for content in contents {
            switch content {
            case .text(let textBlock):
                groups.append(IdentifiedContentGroup(id: "text_\(textOrdinal)", group: .text(textBlock)))
                textOrdinal += 1
                
            case .toolUse(let toolUseBlock):
                if toolUseBlock.isAskUserTool {
                    groups.append(IdentifiedContentGroup(id: "ask_\(toolUseBlock.id)", group: .askUser(toolUseBlock)))
                }
                
            default:
                break
            }
        }
        
        return groups
    }
}

// MARK: - AI 消息复制按钮

/// AI 消息复制按钮：点击把「汇总后的全文」写入剪贴板，成功后短暂显示"已复制"反馈
struct AICopyButton: View {
    let text: String

    @State private var isCopied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = text
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isCopied = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { isCopied = false }
            }
        } label: {
            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isCopied ? ChatTheme.accent : ChatTheme.textSecondary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: ChatTheme.radiusSm, style: .continuous)
                        .fill(isCopied ? ChatTheme.accent.opacity(0.1) : ChatTheme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ChatTheme.radiusSm, style: .continuous)
                        .stroke(ChatTheme.hairline, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: ChatTheme.radiusSm, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCopied ? "已复制" : "复制消息")
    }
}

// MARK: - 消息内容分组类型
enum MessageContentGroup {
    case reasoningChain([ReasoningChainItem])  // 推理链路（thinking + toolUse）
    case text(TextBlockMessage)                // 文本内容
    case askUser(ToolUseBlockMessage)          // ask_user 工具（需要用户交互）
}

/// 带稳定标识的内容分组，供 ForEach 使用
struct IdentifiedContentGroup: Identifiable {
    let id: String
    let group: MessageContentGroup
}

// AI 文本消息 - 无气泡，简洁设计，支持 Markdown
struct AITextMessageView: View {
    let text: String
    /// 是否正在流式增长中：为 true 时用 PacedMarkdownText 做逐字显示
    var isStreaming: Bool = false
    
    /// 预处理文本：去除多余的空白行和首尾空格
    /// 解决 AI 输出时可能包含过多换行符导致UI显示空白过多的问题
    /// 处理步骤：
    /// 1. 去除整个文本首尾的空白字符
    /// 2. 过滤掉只包含换行符的无效内容块
    /// 3. 将连续的多个换行符（3个及以上）压缩为最多2个换行符
    /// 4. 去除每行行首行尾的空格
    private var processedText: String {
        // 步骤1：去除首尾空白
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 步骤2：过滤掉只包含换行符的无效内容（如纯 "\n\n" 或 "\n\n\n"）
        // 如果文本去除所有空白字符后为空，说明这是无效内容
        if result.replacingOccurrences(of: "\n", with: "").trimmingCharacters(in: .whitespaces).isEmpty {
            return ""
        }
        
        // 步骤3：将连续的多个换行（3个及以上）压缩为最多2个
        // 使用正则表达式匹配连续的换行符
        result = result.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )
        
        // 步骤4：去除每行行首行尾的空格（但保留换行符结构）
        result = result
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
        
        return result
    }
    
    var body: some View {
        // 如果处理后的文本为空（纯换行符内容），不显示任何内容，避免显示大量空白
        if processedText.isEmpty {
            EmptyView()
        } else {
            // 使用 Markdown 渲染处理后的文本
            // 流式期间交给 PacedMarkdownText 控制显示节奏（逐字流出），
            // 已完成的文本直接整体渲染，避免不必要的动画开销。
            // 两个分支都不加 .id(text)，避免每次内容变化时整个视图销毁重建
            PacedMarkdownText(processedText, fontSize: 16, isStreaming: isStreaming)
                .frame(maxWidth: .infinity, alignment: .leading)
                // 长按文本直接复制（在文本拖蓝选择不可用/不方便的场景下作为兜底）
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = processedText
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                }
        }
    }
}

// AI 工具调用消息（独立展示的兜底样式，正常场景下工具调用会被归入 ReasoningChainView 的时间线）
struct AIToolUseMessageView: View {
    let toolUse: ToolUseBlockMessage
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    ChatStatusDot(status: toolUse.result != nil ? .done : .active, size: 7)
                    Text(toolUse.name)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(ChatTheme.textPrimary)
                    ChatPill(text: toolUse.result != nil ? "已完成" : "执行中",
                             tint: toolUse.result != nil ? ChatTheme.accent : ChatTheme.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ChatTheme.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, ChatTheme.spacingMd)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if !formatJSON(toolUse.input).isEmpty {
                        toolDetailBlock(title: "参数", text: formatJSON(toolUse.input))
                    }
                    if let content = toolUse.content, !content.isEmpty {
                        toolDetailBlock(title: "过程", text: content)
                    }
                    if let result = toolUse.result, !result.isEmpty {
                        toolDetailBlock(title: "结果", text: result)
                    }
                }
                .padding(.horizontal, ChatTheme.spacingMd)
                .padding(.bottom, ChatTheme.spacingMd)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: ChatTheme.radiusMd)
                .fill(ChatTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChatTheme.radiusMd)
                .stroke(ChatTheme.hairline, lineWidth: 1)
        )
    }

    private func toolDetailBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(ChatTheme.textSecondary.opacity(0.7))
                .textCase(.uppercase)
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(ChatTheme.textSecondary)
                .lineLimit(6)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color("input_bg").opacity(0.5)))
        }
    }

    private func formatJSON(_ value: AnyCodable) -> String {
        if let stringValue = value.stringValue, !stringValue.isEmpty {
            return stringValue
        } else if let dictValue = value.dictValue, !dictValue.isEmpty {
            if let jsonData = try? JSONSerialization.data(withJSONObject: dictValue, options: [.sortedKeys]),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
            return String(describing: dictValue)
        } else if let arrayValue = value.arrayValue, !arrayValue.isEmpty {
            if let jsonData = try? JSONSerialization.data(withJSONObject: arrayValue),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
            return String(describing: arrayValue)
        }
        return ""
    }
}

