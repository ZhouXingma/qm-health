//
//  ApiSettingsView.swift
//  QmHealth
//
//  请求地址设置：业务 API + AI API，支持快速恢复默认值。
//  仅本地保存（UserDefaults），不请求后端。
//

import SwiftUI

struct ApiSettingsView: View {
    @Environment(\.dismiss) var dismiss

    @State private var basicUrl: String = ApiConfig.currentBasicUrl
    @State private var aiUrl: String = ApiConfig.currentAiUrl
    @State private var showResetConfirm: Bool = false
    /// 保存过的地址对（两个地址成对记录，最近使用的在最前）
    @State private var history: [ApiConfig.EndpointPair] = ApiConfig.endpointHistory

    // 输入合法：非空、以 http:// 或 https:// 开头
    private var basicIsValid: Bool { Self.isValidUrl(basicUrl) }
    private var aiIsValid: Bool { Self.isValidUrl(aiUrl) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.card) {
                    sectionHeader(
                        title: "请求地址",
                        subtitle: "修改后立即生效，无需重启 App。仅保存在本机，不会上传到服务端。"
                    )

                    VStack(spacing: 0) {
                        urlRow(
                            icon: "network",
                            iconColor: AppColor.primary,
                            title: "业务 API 地址",
                            placeholder: ApiConfig.defaultBasicUrl,
                            text: $basicUrl,
                            isInvalid: !basicIsValid
                        )

                        Divider().padding(.leading, 56)

                        urlRow(
                            icon: "cpu",
                            iconColor: .purple,
                            title: "智能体 API 地址",
                            placeholder: ApiConfig.defaultAiUrl,
                            text: $aiUrl,
                            isInvalid: !aiIsValid
                        )
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppColor.content)
                    )
                    .appShadow(AppShadow.card)
                    .padding(.horizontal, AppSpacing.screen)

                    // 历史记录：保存过的地址对，点击直接切换
                    sectionHeader(
                        title: "历史记录",
                        subtitle: "保存过的地址会成对记录在这里，点击即可切换，长按可删除；最多保留 \(ApiConfig.maxHistoryCount) 条。"
                    )

                    VStack(spacing: 0) {
                        if history.isEmpty {
                            Text("暂无记录，保存一次请求地址后会自动出现在这里")
                                .font(.system(size: 13))
                                .foregroundStyle(AppColor.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                        } else {
                            ForEach(Array(history.enumerated()), id: \.element.id) { index, pair in
                                if index > 0 {
                                    Divider().padding(.leading, 56)
                                }
                                historyRow(pair)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppColor.content)
                    )
                    .appShadow(AppShadow.card)
                    .padding(.horizontal, AppSpacing.screen)

                    Text("记录保存在本机文件：Documents/api_endpoints.json")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppSpacing.screen + 4)

                    // 快速恢复默认
                    Button {
                        showResetConfirm = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.uturn.backward.circle")
                                .font(.system(size: 15, weight: .semibold))
                            Text("快速恢复默认地址")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundStyle(AppColor.error)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppColor.content)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppColor.error.opacity(0.3), lineWidth: 1)
                    )
                    .appShadow(AppShadow.card)
                    .padding(.horizontal, AppSpacing.screen)

                    Spacer(minLength: 20)
                }
                .padding(.bottom, 30)
            }
            .pageBackground()
            .navigationTitle("请求地址")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        save()
                        dismiss()
                    }
                    .foregroundStyle(AppColor.primary)
                    .disabled(!basicIsValid || !aiIsValid)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
        }
        .alert("恢复默认地址？", isPresented: $showResetConfirm) {
            Button("取消", role: .cancel) {}
            Button("恢复", role: .destructive) {
                basicUrl = ApiConfig.defaultBasicUrl
                aiUrl = ApiConfig.defaultAiUrl
                save()
            }
        } message: {
            Text("将覆盖已保存的业务 API 与 AI API 地址，恢复为默认的 \(ApiConfig.defaultBasicUrl) 与 \(ApiConfig.defaultAiUrl)。")
        }
    }

    // MARK: - 子视图

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColor.textPrimary)

            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(AppColor.textSecondary)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.screen)
        .padding(.top, 4)
    }

    /// 单行设置：图标 + 标题 + 输入框
    private func urlRow(
        icon: String,
        iconColor: Color,
        title: String,
        placeholder: String,
        text: Binding<String>,
        isInvalid: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColor.textPrimary)
                    if isInvalid {
                        Text("地址无效，需以 http:// 或 https:// 开头")
                            .font(.system(size: 11))
                            .foregroundColor(AppColor.error)
                    } else {
                        Text("默认：\(placeholder)")
                            .font(.system(size: 11))
                            .foregroundColor(AppColor.textSecondary)
                    }
                }

                Spacer()
            }

            // 输入框：使用 KeyboardUtils 自动隐藏键盘
            TextField(placeholder, text: text)
                .font(.system(size: 14, design: .monospaced))
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppColor.background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isInvalid ? AppColor.error : AppColor.divider, lineWidth: 1)
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - 校验

    private static func isValidUrl(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
    }

    /// 单条历史记录：业务 + 智能体地址成对展示，点击直接切换
    private func historyRow(_ pair: ApiConfig.EndpointPair) -> some View {
        let isCurrent = pair.basicUrl == ApiConfig.currentBasicUrl
            && pair.aiUrl == ApiConfig.currentAiUrl

        return Button {
            apply(pair)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(AppColor.primary.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: isCurrent ? "checkmark" : "clock.arrow.circlepath")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColor.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("业务 \(Self.stripScheme(pair.basicUrl))")
                        .font(.system(size: 13, weight: isCurrent ? .semibold : .regular, design: .monospaced))
                        .foregroundColor(AppColor.textPrimary)
                        .lineLimit(1)
                    Text("智能体 \(Self.stripScheme(pair.aiUrl))")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(AppColor.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if isCurrent {
                    Text("当前")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColor.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(AppColor.primary.opacity(0.12)))
                } else {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColor.textSecondary.opacity(0.6))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                delete(pair)
            } label: {
                Label("删除这条记录", systemImage: "trash")
            }
        }
    }

    private static func stripScheme(_ url: String) -> String {
        url.replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
    }

    // MARK: - 保存与应用

    /// 点击历史记录：填入输入框并立即生效，同时把该记录提到最前
    private func apply(_ pair: ApiConfig.EndpointPair) {
        basicUrl = pair.basicUrl
        aiUrl = pair.aiUrl
        save()
        dismiss()
    }

    /// 长按菜单删除一条历史记录（不影响当前生效的地址）
    private func delete(_ pair: ApiConfig.EndpointPair) {
        ApiConfig.removeEndpointHistory(pair)
        history = ApiConfig.endpointHistory
    }

    private func save() {
        let basic = basicUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let ai = aiUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        ApiConfig.setBasicUrl(basic)
        ApiConfig.setAiUrl(ai)
        // 每保存一次记录一次，两个地址都一致则视为重复、提到最前
        ApiConfig.recordEndpointHistory(basicUrl: basic, aiUrl: ai)
        history = ApiConfig.endpointHistory
    }
}

#Preview {
    ApiSettingsView()
}
