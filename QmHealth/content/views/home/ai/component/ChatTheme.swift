//
//  ChatTheme.swift
//  QmHealth
//
//  Created by Kiro on 2026/7/15.
//
//  AI 对话页全新视觉设计的主题令牌。
//  不引入新的颜色资源，而是基于现有 Assets.xcassets 中的语义色
//  （mainPrimary / mainSecondary / background / content_bg / text_primary /
//   text_secondary / divider / error / warning / input_bg）派生出一套
//  更具层次感的配色和间距规范，自动适配深色/浅色模式。
//

import SwiftUI

/// AI 对话消息区域的视觉主题
struct ChatTheme {
    // MARK: - 品牌色
    static let accent = Color.theme(.primary)
    static let accentSoft = Color.theme(.secondary)

    // MARK: - 派生表面色（用于卡片、时间线轨道等）
    /// 用户消息气泡的渐变
    static let userBubbleGradient = LinearGradient(
        colors: [accent, accent.opacity(0.82)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// AI 内容区域的轨道/卡片底色
    static let surface = Color("content_bg").opacity(0.55)
    static let surfaceStrong = Color("content_bg")

    /// 思考/流程时间线的轨道线颜色
    static let timelineTrack = accent.opacity(0.22)

    /// 卡片描边
    static let hairline = Color("divider").opacity(0.35)

    // MARK: - 文本色
    static let textPrimary = Color("text_primary")
    static let textSecondary = Color("text_secondary")

    // MARK: - 状态色
    static let success = accent
    static let danger = Color("error")
    static let warning = Color("warning")

    // MARK: - 间距 / 圆角规范
    static let radiusSm: CGFloat = 10
    static let radiusMd: CGFloat = 16
    static let radiusLg: CGFloat = 22

    static let spacingXs: CGFloat = 4
    static let spacingSm: CGFloat = 8
    static let spacingMd: CGFloat = 12
    static let spacingLg: CGFloat = 18

    // MARK: - 字体
    static func title(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .semibold) }
    static func body(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .regular) }
    static func caption(_ size: CGFloat = 11) -> Font { .system(size: size, weight: .medium) }
}

// MARK: - 通用小组件：圆点状态指示灯
struct ChatStatusDot: View {
    enum Status { case pending, active, done, failed }
    let status: Status
    var size: CGFloat = 7

    /// .active 状态下驱动呼吸动画的开关，onAppear 时置真
    @State private var isPulsing: Bool = false

    private var color: Color {
        switch status {
        case .pending: return ChatTheme.textSecondary.opacity(0.35)
        case .active: return ChatTheme.accent
        case .done: return ChatTheme.accent
        case .failed: return ChatTheme.danger
        }
    }

    var body: some View {
        ZStack {
            if status == .active {
                // 外层光晕呼吸动画：持续放大淡出，明确传达"仍在进行中"
                Circle()
                    .fill(color.opacity(0.25))
                    .frame(width: size + 8, height: size + 8)
                    .scaleEffect(isPulsing ? 1.6 : 1.0)
                    .opacity(isPulsing ? 0 : 0.7)
                    .animation(
                        .easeOut(duration: 1.1).repeatForever(autoreverses: false),
                        value: isPulsing
                    )
            }
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .scaleEffect(status == .active && isPulsing ? 1.15 : 1.0)
                .animation(
                    status == .active
                        ? .easeInOut(duration: 0.55).repeatForever(autoreverses: true)
                        : .default,
                    value: isPulsing
                )
        }
        .onAppear {
            if status == .active { isPulsing = true }
        }
    }
}

// MARK: - 通用小组件：生成中的"打字中"提示（三个跳动圆点）
/// 用于在消息内容仍在流式生成时，附着在最新内容末尾持续提示"AI 仍在输出"，
/// 不会因为已经渲染出思考/正文内容而消失，只在整条消息真正结束
/// （displayState 不再是 .responding）时才隐藏。
struct TypingDotsIndicator: View {
    var color: Color = ChatTheme.accent
    var dotSize: CGFloat = 5
    @State private var animate: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(animate ? 1.0 : 0.4)
                    .opacity(animate ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}

// MARK: - 通用小组件：轻量分段标签（用于 "思考中" / "已完成" 等）
struct ChatPill: View {
    let text: String
    var tint: Color = ChatTheme.accent
    var filled: Bool = false

    var body: some View {
        Text(text)
            .font(ChatTheme.caption(10))
            .foregroundStyle(filled ? Color.white : tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(filled ? tint : tint.opacity(0.12))
            )
    }
}
