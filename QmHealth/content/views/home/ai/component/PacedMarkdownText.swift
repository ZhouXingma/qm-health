//
//  PacedMarkdownText.swift
//  QmHealth
//
//  Created by Kiro on 2026/7/28.
//
//  逐字显示的 Markdown 文本视图，节奏由 StreamingTextPacer 控制。
//

import SwiftUI

// MARK: - 逐字显示的 Markdown 文本视图

/// 支持逐字显示的 Markdown 文本视图。
///
/// 流式进行中（`isStreaming == true`）时由 `StreamingTextPacer` 控制显示节奏，
/// 结束后立即补齐剩余内容；非流式场景等价于直接使用 `MarkdownText`。
struct PacedMarkdownText: View {
    let text: String
    let fontSize: CGFloat
    let isStreaming: Bool

    @StateObject private var pacer: StreamingTextPacer

    init(_ text: String, fontSize: CGFloat = 16, isStreaming: Bool) {
        self.text = text
        self.fontSize = fontSize
        self.isStreaming = isStreaming
        // 非流式场景（历史消息）直接用完整文本初始化，不再依赖 onAppear 的回调延迟
        _pacer = StateObject(wrappedValue: StreamingTextPacer(initialText: isStreaming ? "" : text))
    }

    var body: some View {
        Group {
            if pacer.displayedText.isEmpty {
                // 还没有可显示的字符，不占位，避免出现空白块
                EmptyView()
            } else {
                MarkdownText(pacer.displayedText, fontSize: fontSize)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear {
            pacer.setTarget(text, paced: isStreaming)
        }
        .onChange(of: text) { _, newValue in
            pacer.setTarget(newValue, paced: isStreaming)
        }
        .onChange(of: isStreaming) { _, _ in
            // 流结束时不做硬性截断：仍以 paced 方式把剩余积压平滑放完，
            // 收尾阶段积压通常很小，观感上就是"最后几个字继续流完"。
            pacer.setTarget(text, paced: true)
        }
        .onDisappear {
            pacer.flush()
        }
    }
}
