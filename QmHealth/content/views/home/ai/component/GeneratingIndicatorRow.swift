//
//  GeneratingIndicatorRow.swift
//  QmHealth
//
//  Created by Kiro on 2026/7/16.
//
//  "正在生成回复"指示器。
//
//  背景：发送消息后，从连接建立到模型吐出第一个 token 之间可能有数秒延迟
//  （见实测日志：RUN_STARTED 后思考首字延迟可达 3~4 秒，工具执行等待更久）。
//  这段时间如果 UI 毫无反馈，用户很容易误以为程序卡死。此组件填补这段
//  "无内容但确实在处理"的空窗期，在第一个可见内容块（思考/工具调用/文本）
//  到达后由调用方隐藏。
//

import SwiftUI

/// 呼吸感的"正在生成回复"提示行，独立于消息内容展示。
struct GeneratingIndicatorRow: View {
    @State private var pulse: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(ChatTheme.accent)
                        .frame(width: 6, height: 6)
                        .scaleEffect(pulse ? 1.0 : 0.4)
                        .opacity(pulse ? 1.0 : 0.35)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.15),
                            value: pulse
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(ChatTheme.surface)
            )
            .overlay(
                Capsule().stroke(ChatTheme.hairline, lineWidth: 1)
            )

            Spacer()
        }
        .onAppear { pulse = true }
        .onDisappear { pulse = false }
    }
}

#Preview {
    VStack {
        GeneratingIndicatorRow()
            .padding()
        Spacer()
    }
    .background(Color("background"))
}
