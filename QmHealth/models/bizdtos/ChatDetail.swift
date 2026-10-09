//
//  ChatDetail.swift
//  QmHealth
//
//  Created by Kiro on 2026/2/24.
//

import Foundation

// 聊天详情请求参数
struct ChatDetailRequest: Codable {
    let conversationId: String
}

// 中断聊天请求参数
struct ChatInterruptRequest: Codable {
    let conversationId: String
    let runId: String
}
