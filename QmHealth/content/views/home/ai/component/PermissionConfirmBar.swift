//
//  PermissionConfirmBar.swift
//  QmHealth
//
//  Created by Kiro on 2026/7/15.
//
//  机制 A（Permission ASK）授权条。
//  对应场景：Agent 想调用某个工具，但权限引擎在工具执行之前拦截，
//  要求用户确认"是否允许"。这与 ask_user（信息收集表单，机制 B）完全不同，
//  也不属于消息内容的一部分，因此单独设计为一条悬浮在输入框正上方的
//  授权条，而不是塞进消息列表里的工具卡片（避免和 TOOL_CALL_START/END
//  产生的卡片重复显示）。
//

import SwiftUI

/// 权限确认条 —— 展示在输入框上方，列出所有等待授权的工具调用，
/// 提供"允许"/"拒绝"两个操作。
struct PermissionConfirmBar: View {
    let confirmations: [PendingToolConfirmation]
    let isSubmitting: Bool
    let onAllow: () -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 6) {
                ForEach(confirmations) { item in
                    HStack(spacing: 6) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(ChatTheme.warning)
                        Text(item.name)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(ChatTheme.textPrimary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, ChatTheme.spacingMd)
            .padding(.bottom, ChatTheme.spacingSm)

            actionButtons
        }
        .background(
            RoundedRectangle(cornerRadius: ChatTheme.radiusMd)
                .fill(ChatTheme.warning.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChatTheme.radiusMd)
                .stroke(ChatTheme.warning.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .disabled(isSubmitting)
        .opacity(isSubmitting ? 0.6 : 1)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 13))
                .foregroundStyle(ChatTheme.warning)

            Text(confirmations.count == 1 ? "AI 请求调用一个工具" : "AI 请求调用 \(confirmations.count) 个工具")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ChatTheme.textPrimary)

            Spacer()

            if isSubmitting {
                ProgressView().scaleEffect(0.7)
            }
        }
        .padding(.horizontal, ChatTheme.spacingMd)
        .padding(.top, ChatTheme.spacingMd)
        .padding(.bottom, 6)
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button(action: onDeny) {
                Text("拒绝")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: ChatTheme.radiusSm)
                            .fill(Color("input_bg"))
                    )
                    .foregroundStyle(ChatTheme.textPrimary)
            }
            .buttonStyle(.plain)

            Button(action: onAllow) {
                Text("允许")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: ChatTheme.radiusSm)
                            .fill(ChatTheme.accent)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, ChatTheme.spacingMd)
        .padding(.bottom, ChatTheme.spacingMd)
    }
}

#Preview {
    VStack {
        Spacer()
        PermissionConfirmBar(
            confirmations: [
                PendingToolConfirmation(id: "1", name: "user_disease_list"),
                PendingToolConfirmation(id: "2", name: "delete_medical_record")
            ],
            isSubmitting: false,
            onAllow: {},
            onDeny: {}
        )
    }
    .background(Color("background"))
}
