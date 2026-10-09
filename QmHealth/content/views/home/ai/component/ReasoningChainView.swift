//
//  ReasoningChainView.swift
//  QmHealth
//
//  Created by AI Assistant on 2026/6/4.
//  Redesigned by Kiro on 2026/7/15 — 全新时间线视觉设计。
//

import SwiftUI

// MARK: - 推理链路状态管理类
/// 管理推理链路的展开/收起状态,避免状态变化触发父视图重绘
class ReasoningChainState: ObservableObject {
    @Published var isExpanded: Bool = false
    @Published var expandedSections: Set<String> = []

    func toggleExpanded() {
        isExpanded.toggle()
    }

    func toggleSection(_ id: String) {
        if expandedSections.contains(id) {
            expandedSections.remove(id)
        } else {
            expandedSections.insert(id)
        }
    }

    func isSectionExpanded(_ id: String) -> Bool {
        return expandedSections.contains(id)
    }
}

/// 推理链路视图 —— 以竖直时间线呈现思考与工具调用步骤
/// 视觉设计：左侧细线连接每个步骤的状态点，整体作为一张可折叠的轨道卡片，
/// 与下方的正式回答文本形成明显的层次区分（"过程" vs "结论"）。
struct ReasoningChainView: View {
    let items: [ReasoningChainItem]
    @StateObject private var state = ReasoningChainState()

    /// 是否仍在进行中（末尾项是思考中或工具执行中）
    private var isActive: Bool {
        switch items.last {
        case .thinking(let content):
            return content.isEmpty
        case .toolUse(let tool):
            return tool.result == nil
        case nil:
            return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if state.isExpanded {
                timeline
                    .padding(.top, 2)
                    .padding(.bottom, ChatTheme.spacingSm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
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
        .animation(.easeInOut(duration: 0.22), value: state.isExpanded)
    }

    // MARK: - 头部
    private var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                state.toggleExpanded()
            }
        } label: {
            HStack(spacing: 10) {
                ChatStatusDot(status: isActive ? .active : .done, size: 8)

                Text(isActive ? "正在推理…" : "推理过程")
                    .font(ChatTheme.title(13))
                    .foregroundStyle(ChatTheme.textPrimary)

                summaryText

                Spacer(minLength: 8)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ChatTheme.textSecondary)
                    .rotationEffect(.degrees(state.isExpanded ? 180 : 0))
            }
            .padding(.horizontal, ChatTheme.spacingMd)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var summaryText: some View {
        HStack(spacing: 3) {
            if thinkingCount > 0 {
                Text("\(thinkingCount) 次思考")
            }
            if thinkingCount > 0 && toolUseCount > 0 {
                Text("·")
            }
            if toolUseCount > 0 {
                Text("\(toolUseCount) 次工具调用")
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(ChatTheme.textSecondary.opacity(0.8))
    }

    // MARK: - 时间线
    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                switch item {
                case .thinking(let content):
                    TimelineStepRow(isLast: index == items.count - 1) {
                        ReasoningThinkingItem(content: content)
                            .environmentObject(state)
                    }
                case .toolUse(let toolUse):
                    TimelineStepRow(isLast: index == items.count - 1) {
                        ReasoningToolUseItem(toolUse: toolUse)
                            .environmentObject(state)
                    }
                }
            }
        }
        .padding(.horizontal, ChatTheme.spacingMd)
    }

    private var thinkingCount: Int {
        items.filter { if case .thinking = $0 { return true } else { return false } }.count
    }

    private var toolUseCount: Int {
        items.filter { if case .toolUse = $0 { return true } else { return false } }.count
    }
}

// MARK: - 推理链路项类型
enum ReasoningChainItem {
    case thinking(String)
    case toolUse(ToolUseBlockMessage)
}

// MARK: - 时间线单行容器（负责绘制左侧竖线与状态点）
struct TimelineStepRow<Content: View>: View {
    let isLast: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // 竖线轨道
            VStack(spacing: 0) {
                Circle()
                    .fill(ChatTheme.timelineTrack)
                    .frame(width: 6, height: 6)
                    .padding(.top, 6)
                if !isLast {
                    Rectangle()
                        .fill(ChatTheme.timelineTrack)
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 6)

            content()
                .padding(.bottom, isLast ? 4 : ChatTheme.spacingSm)
        }
    }
}

// MARK: - 思考内容项
struct ReasoningThinkingItem: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("思考")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ChatTheme.accent.opacity(0.85))

            if content.isEmpty {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.6)
                    Text("正在思考…")
                        .font(.system(size: 12))
                        .foregroundStyle(ChatTheme.textSecondary)
                }
            } else {
                Text(content)
                    .font(.system(size: 12.5))
                    .foregroundStyle(ChatTheme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 工具使用项
struct ReasoningToolUseItem: View {
    let toolUse: ToolUseBlockMessage
    @EnvironmentObject var chainState: ReasoningChainState

    private var sectionId: String { "tool_\(toolUse.id)" }
    private var isExpanded: Bool { chainState.isSectionExpanded(sectionId) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    chainState.toggleSection(sectionId)
                }
            } label: {
                HStack(spacing: 6) {
                    Text("调用")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(statusColor)

                    Text(toolUse.name)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(ChatTheme.textPrimary)
                        .lineLimit(1)

                    ChatPill(text: statusText, tint: statusColor)

                    Spacer(minLength: 4)

                    if hasDetails {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(ChatTheme.textSecondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded && hasDetails {
                VStack(alignment: .leading, spacing: 6) {
                    if let input = inputText, !input.isEmpty {
                        ToolDetailBlock(title: "参数", text: input)
                    }
                    if let content = toolUse.content, !content.isEmpty {
                        ToolDetailBlock(title: "过程", text: content)
                    }
                    if let result = toolUse.result, !result.isEmpty {
                        ToolDetailBlock(title: "结果", text: result)
                    }
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inputText: String? {
        if let s = toolUse.input.stringValue, !s.isEmpty { return s }
        if let dict = toolUse.input.dictValue, !dict.isEmpty {
            if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
        }
        return nil
    }

    private var statusIcon: String {
        if toolUse.result != nil { return "checkmark" }
        if let c = toolUse.content, !c.isEmpty { return "ellipsis" }
        return "hourglass"
    }

    private var statusColor: Color {
        toolUse.result != nil ? ChatTheme.accent : ChatTheme.textSecondary
    }

    private var statusText: String {
        if toolUse.result != nil { return "已完成" }
        if let c = toolUse.content, !c.isEmpty { return "执行中" }
        return "准备中"
    }

    private var hasDetails: Bool {
        (inputText?.isEmpty == false) ||
        (toolUse.content?.isEmpty == false) ||
        (toolUse.result?.isEmpty == false)
    }
}

// MARK: - 工具详情文本块
private struct ToolDetailBlock: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(ChatTheme.textSecondary.opacity(0.7))
                .textCase(.uppercase)

            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(ChatTheme.textSecondary)
                .lineLimit(6)
                .textSelection(.enabled)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color("input_bg").opacity(0.5))
                )
        }
    }
}
