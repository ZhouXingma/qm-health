//
//  ChatStreamEvent.swift
//  QmHealth
//
//  Created by Kiro on 2026/7/15.
//
//  对应后端新版流式事件协议（AgentScope 事件体系简化模型，见 ChatEvent.java / EventType.java）。
//  SSE 帧的 event 字段目前固定为 "data"（后端历史遗留），data 字段是本结构体的 JSON。
//

import Foundation

// MARK: - ChatEventType - 事件类型常量（与后端 EventType.java 保持一致）
struct ChatEventType {
    // 生命周期
    static let RUN_STARTED = "RUN_STARTED"
    static let RUN_FINISHED = "RUN_FINISHED"
    static let RUN_RESULT = "RUN_RESULT"
    static let RUN_ERROR = "RUN_ERROR"

    // 模型调用
    static let MODEL_CALL_START = "MODEL_CALL_START"
    static let MODEL_CALL_END = "MODEL_CALL_END"

    // 内容
    static let TEXT = "TEXT"
    static let TEXT_START = "TEXT_START"
    static let TEXT_END = "TEXT_END"
    static let THINKING = "THINKING"
    static let THINKING_START = "THINKING_START"
    static let THINKING_END = "THINKING_END"

    // 工具调用
    static let TOOL_CALL_START = "TOOL_CALL_START"
    static let TOOL_CALL_DELTA = "TOOL_CALL_DELTA"
    static let TOOL_CALL_END = "TOOL_CALL_END"
    static let TOOL_CALL_RESULT = "TOOL_CALL_RESULT"
    static let TOOL_RESULT_START = "TOOL_RESULT_START"
    static let TOOL_RESULT_TEXT_DELTA = "TOOL_RESULT_TEXT_DELTA"
    static let TOOL_RESULT_DATA_DELTA = "TOOL_RESULT_DATA_DELTA"

    // 自定义 / 透传
    static let RAW = "RAW"
    static let CUSTOM = "CUSTOM"
}

// MARK: - ChatStreamEvent - 统一流式事件（对应后端 ChatEvent.java）
struct ChatStreamEvent: Codable {
    let id: String?
    let timestamp: String?
    let conversationId: String?
    let runId: String?
    let type: String
    let data: [String: AnyCodable]?
    let metadata: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case id, timestamp, conversationId, runId, type, data, metadata
    }

    /// 获取 data 中某个字段的字符串表示
    func dataString(_ key: String) -> String? {
        guard let v = data?[key]?.value else { return nil }
        if let s = v as? String { return s }
        if v is NSNull { return nil }
        return String(describing: v)
    }

    /// 获取 data 中某个字段的字典
    func dataDict(_ key: String) -> [String: Any]? {
        return data?[key]?.dictValue
    }

    /// 获取 data 中某个字段的数组
    func dataArray(_ key: String) -> [Any]? {
        return data?[key]?.arrayValue
    }

    /// 获取 data 中某个字段的原始值
    func dataValue(_ key: String) -> Any? {
        return data?[key]?.value
    }
}
