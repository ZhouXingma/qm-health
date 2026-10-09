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

    // 输入合法：非空、以 http:// 或 https:// 开头
    private var basicIsValid: Bool { Self.isValidUrl(basicUrl) }
    private var aiIsValid: Bool { Self.isValidUrl(aiUrl) }

    var body: some View {
        NavigationView {
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

    private func save() {
        ApiConfig.setBasicUrl(basicUrl.trimmingCharacters(in: .whitespacesAndNewlines))
        ApiConfig.setAiUrl(aiUrl.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

#Preview {
    ApiSettingsView()
}
