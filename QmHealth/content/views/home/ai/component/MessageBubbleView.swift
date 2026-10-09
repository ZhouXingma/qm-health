//
//  MessageBubbleView.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/2/10.
//  Redesigned by Kiro on 2026/7/15.
//

import SwiftUI

// 消息气泡视图 - 根据消息类型显示不同组件
struct MessageBubbleView: View {
    @ObservedObject var message: DisplayChatMessage
    var onAskUserResponse: ((InteractiveHandleBlockMessage) -> Void)?
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // 检查是否是交互处理消息（虽然 role 是 user，但内容是 interactiveHandle）
            let isInteractiveHandleMessage = message.role == .user && 
                                            message.contents.count == 1 && 
                                            message.contents.first.map { content in
                                                if case .interactiveHandle = content {
                                                    return true
                                                }
                                                return false
                                            } ?? false
            
            if message.role == .user && !isInteractiveHandleMessage {
                Spacer(minLength: 60)
                
                HStack(alignment: .bottom, spacing: 6) {
                    // 状态指示器
                    Group {
                        if message.displayState == .sending {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else if case .failed = message.displayState {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(ChatTheme.danger)
                                .font(.system(size: 16))
                        }
                    }
                    .frame(width: 16, height: 16)
                    .opacity(message.displayState.isLoading || message.displayState.isFailed ? 1 : 0)
                    
                    UserMessageView(message: message)
                }
                
            } else if message.role == .assistant || isInteractiveHandleMessage {
                // 根据消息类型显示不同的 AI 消息组件
                VStack(alignment: .leading, spacing: 6) {
                    AIMessageView(message: message, onAskUserResponse: onAskUserResponse)
                    
                    // AI 消息错误状态提示
                    if case .failed = message.displayState {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(ChatTheme.danger)
                            
                            Text("响应失败")
                                .font(.system(size: 12))
                                .foregroundStyle(ChatTheme.danger)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
