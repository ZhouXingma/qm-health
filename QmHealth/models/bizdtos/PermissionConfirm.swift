//
//  PermissionConfirm.swift
//  QmHealth
//
//  Created by Kiro on 2026/7/15.
//
//  对应后端 HITL 机制 A（Permission ASK）：
//  工具执行前被权限引擎拦截，Agent 通过 CUSTOM(require_user_confirm) 事件
//  询问用户是否允许调用某个工具。这与 ask_user（机制 B，信息收集表单）
//  是完全不同的交互——这里问的是"能不能调用"，不是"需要你填什么"。
//
//  设计上不把它塞进消息流里的推理时间线（会和 TOOL_CALL_START 产生的卡片重复），
//  而是作为一条独立于消息列表的"待处理事项”，展示在输入框上方的授权条中。
//

import Foundation

/// 一个等待用户授权的工具调用（机制 A：Permission ASK）
struct PendingToolConfirmation: Identifiable {
    /// 对应 ToolUseBlock.id / toolCallId
    let id: String
    /// 工具方法名
    let name: String
    /// 工具调用参数（仅用于展示，不参与提交）
    let input: AnyCodable?

    init(id: String, name: String, input: AnyCodable? = nil) {
        self.id = id
        self.name = name
        self.input = input
    }
}

extension PendingToolConfirmation: Equatable {
    static func == (lhs: PendingToolConfirmation, rhs: PendingToolConfirmation) -> Bool {
        lhs.id == rhs.id
    }
}

/// 提交给后端的单条确认结果
/// 对应后端 ConfirmResult(confirmed, toolUseBlock, suggestedRules) 的精简版：
/// 后端应根据 toolCallId 从会话中挂起的 ASKING 状态里找回对应的 ToolUseBlock，
/// 不需要客户端把完整的工具调用结构再传回去。
struct ConfirmResultPayload: Codable {
    let toolCallId: String
    let toolName: String
    let confirmed: Bool

    enum CodingKeys: String, CodingKey {
        case toolCallId
        case toolName
        case confirmed
    }
}
