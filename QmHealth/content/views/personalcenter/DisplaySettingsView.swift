//
//  DisplaySettingsView.swift
//  QmHealth
//
//  Created on 2026/1/24.
//
//  显示设置：液态玻璃化版本。
//  页面背景使用 .glassBackground() 弥散动画底；主题卡片统一走 glassCardStyle，
//  选中态用 primary 描边 + 对勾，避免 tinted 玻璃遮挡内容；颜色区整体一个玻璃容器。
//

import SwiftUI

struct DisplaySettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("appThemeMode") private var themeMode: Int = 0 // 0: 跟随系统, 1: 浅色, 2: 深色
    @StateObject private var themeManager = ThemeManager.shared
    // 注：液态玻璃开关已移除（项目要求"玻璃永远开启"），glassConfig 引用清理。

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.card) {
                    sectionHeader(
                        title: "外观主题",
                        subtitle: "选择您喜欢的主题模式，让应用更符合您的使用习惯"
                    )

                    // 主题卡片：跟随系统占满，浅色/深色并排
                    VStack(spacing: AppSpacing.regular) {
                        ThemeCard(
                            title: "跟随系统",
                            description: "自动适配系统设置",
                            icon: "circle.lefthalf.filled",
                            themeMode: 0,
                            currentMode: $themeMode
                        )

                        HStack(spacing: AppSpacing.regular) {
                            ThemeCard(
                                title: "浅色",
                                description: "明亮清爽",
                                icon: "sun.max.fill",
                                themeMode: 1,
                                currentMode: $themeMode
                            )

                            ThemeCard(
                                title: "深色",
                                description: "护眼舒适",
                                icon: "moon.fill",
                                themeMode: 2,
                                currentMode: $themeMode
                            )
                        }
                    }
                    .padding(.horizontal, AppSpacing.screen)

                    sectionHeader(
                        title: "主题颜色",
                        subtitle: "选择您喜欢的应用主色调，让界面更有个人风格"
                    )

                    // 主题颜色网格：整块一个玻璃卡片承载
                    themeColorGrid
                        .padding(.horizontal, AppSpacing.screen)

                    Spacer(minLength: 20)
                }
                .padding(.bottom, 30)
            }
            .pageBackground()
            .navigationTitle("显示设置")
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
        .preferredColorScheme(themeManager.colorScheme)
    }

    /// 分组标题：标题 + 副标题，统一左对齐、内边距
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
    }

    /// 主题颜色区：整块一个玻璃卡片，内部 5 列色块网格
    private var themeColorGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.regular), count: 5),
            spacing: AppSpacing.card
        ) {
            ForEach(AppThemeColor.allCases) { theme in
                ThemeColorCircle(theme: theme, themeManager: themeManager)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.card)
        .padding(.horizontal, AppSpacing.compact)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(AppColor.content)
        )
        .appShadow(AppShadow.card)
    }
}

// MARK: - 主题卡片

/// 主题模式卡片：上半部预览（图标 + 浅色背景），下半部文字信息。
/// 整张走 glassCardStyle(.regular)；选中态叠加 primary 描边 + 对勾，**不**使用 tinted 玻璃以免遮挡内容。
struct ThemeCard: View {
    let title: String
    let description: String
    let icon: String
    let themeMode: Int
    @Binding var currentMode: Int

    private var isSelected: Bool { currentMode == themeMode }

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                currentMode = themeMode
            }
        }) {
            VStack(spacing: 0) {
                // 预览区域
                VStack {
                    Image(systemName: icon)
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(isSelected ? AppColor.primary : AppColor.textSecondary)
                }
                .frame(height: 100)
                .frame(maxWidth: .infinity)

                Divider().opacity(0.25)

                // 信息区域
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColor.textPrimary)
                        Text(description)
                            .font(.system(size: 12))
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(AppColor.primary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(AppColor.content)
            }
            .background {
                RoundedRectangle(cornerRadius: 16).fill(LinearGradient(
                    gradient: Gradient(colors: [
                        isSelected ? AppColor.primary.opacity(0.35) : AppColor.textSecondary.opacity(0.12),
                        isSelected ? AppColor.primary.opacity(0.15) : AppColor.textSecondary.opacity(0.04)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            }
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? AppColor.primary : Color.clear,
                        lineWidth: isSelected ? 2 : 0
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
        }
    }
}

// MARK: - 主题颜色圆形

/// 主题颜色：渐变圆 + 选中描边 + 名称。
/// 不再使用独立玻璃容器，整体在父级玻璃卡片内展示，保持视觉简洁。
struct ThemeColorCircle: View {
    let theme: AppThemeColor
    @ObservedObject var themeManager: ThemeManager

    private var isSelected: Bool { themeManager.appearanceTheme == theme }

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                themeManager.setTheme(theme)
            }
        }) {
            VStack(spacing: 6) {
                ZStack {
                    // 选中描边（外圈）
                    Circle()
                        .stroke(
                            isSelected ? AppColor.primary : AppColor.divider,
                            lineWidth: isSelected ? 2 : 1
                        )
                        .frame(width: 52, height: 52)

                    // 颜色圆
                    Circle()
                        .fill(LinearGradient(
                            colors: [theme.previewPrimary, theme.previewSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 42, height: 42)

                    // 选中对勾
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 56, height: 56)

                Text(theme.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AppColor.textPrimary : AppColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    DisplaySettingsView()
}
