//
//  MedicineReminderSettingsView.swift
//  QmHealth
//
//  用药提醒设置：总开关 + 错过提醒后的补发宽限期。
//

import SwiftUI

struct MedicineReminderSettingsView: View {
    @Environment(\.dismiss) var dismiss

    @State private var enabled = MedicineReminder.shared.isEnabled
    @State private var graceMinutes = MedicineReminder.shared.graceMinutes
    @State private var isRequestingAuth = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.card) {
                    sectionHeader(
                        title: "用药提醒",
                        subtitle: "按用药计划的时间提醒您服药，提醒会穿透专注模式"
                    )

                    toggleCard

                    if enabled {
                        sectionHeader(
                            title: "错过提醒后补发",
                            subtitle: "本地提醒必须在到点前排出，若手机当时未收到，可在打开 App 时补发一次"
                        )

                        graceCard
                    }

                    sectionHeader(title: "说明", subtitle: nil)
                    notesCard

                    Spacer(minLength: 20)
                }
                .padding(.bottom, 30)
            }
            .pageBackground()
            .navigationTitle("用药提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundStyle(AppColor.primary)
                }
            }
        }
    }

    // MARK: - 总开关

    private var toggleCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(AppColor.primary.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColor.primary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("开启用药提醒")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)

                Text("按用药计划的时间提醒服药")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColor.textSecondary)
            }

            Spacer(minLength: 8)

            if isRequestingAuth {
                ProgressView()
                    .controlSize(.small)
            } else {
                Toggle("", isOn: $enabled)
                    .labelsHidden()
                    .tint(AppColor.primary)
                    .onChange(of: enabled) { _, value in
                        handleToggle(value)
                    }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(AppColor.content)
        )
        .appShadow(AppShadow.card)
        .padding(.horizontal, AppSpacing.screen)
    }

    // MARK: - 宽限期选项

    private var graceCard: some View {
        let options = MedicineReminder.GraceOption.allCases

        return VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                Button {
                    graceMinutes = option.rawValue
                    MedicineReminder.shared.graceMinutes = option.rawValue
                    // 宽限期变化后按新设置重排一次。
                    MedicineReminder.shared.refresh()
                } label: {
                    HStack(spacing: 12) {
                        Text(option.title)
                            .font(.system(size: 15))
                            .foregroundStyle(AppColor.textPrimary)

                        Spacer()

                        if graceMinutes == option.rawValue {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColor.primary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())

                if index < options.count - 1 {
                    Divider().padding(.leading, 14)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(AppColor.content)
        )
        .appShadow(AppShadow.card)
        .padding(.horizontal, AppSpacing.screen)
    }

    // MARK: - 说明

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            noteLine(
                icon: "clock.badge.checkmark",
                text: "到服药时间弹出横幅并响铃，开启专注模式也能收到。"
            )
            noteLine(
                icon: "speaker.slash.fill",
                text: "手机静音时只弹横幅、不响铃，这是系统对普通通知的限制。"
            )
            noteLine(
                icon: "arrow.clockwise",
                text: "提醒只排未来 7 天，随日常使用自动往后滚动。"
            )
            noteLine(
                icon: "checkmark.circle.fill",
                text: "已记录的服药时间点不会再提醒。"
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(AppColor.content)
        )
        .appShadow(AppShadow.card)
        .padding(.horizontal, AppSpacing.screen)
    }

    private func noteLine(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(AppColor.textSecondary)
                .frame(width: 16)

            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(AppColor.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 分组标题

    private func sectionHeader(title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColor.textPrimary)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColor.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.screen)
    }

    // MARK: - 开关处理

    /// 打开时先要通知权限；用户拒绝则把开关回退，避免开关与实际能力不一致。
    private func handleToggle(_ value: Bool) {
        guard value else {
            MedicineReminder.shared.isEnabled = false
            MedicineReminder.shared.clearAll()
            return
        }

        isRequestingAuth = true
        MedicineReminder.shared.requestAuthorization { granted in
            isRequestingAuth = false

            guard granted else {
                enabled = false
                MedicineReminder.shared.isEnabled = false
                PopManager.shared.showSimplePop(
                    title: "无法开启用药提醒",
                    description: "请在系统设置中允许 QmHealth 发送通知"
                )
                return
            }

            MedicineReminder.shared.isEnabled = true
            MedicineReminder.shared.refresh()
        }
    }
}

#Preview {
    MedicineReminderSettingsView()
}
