//
//  GeneralSettingsView.swift
//  QmHealth
//
//  通用设置页面
//
//  注：项目要求"液态玻璃效果永远开启，不做关闭操作"，
//  原有的"材质效果"分组（含 ToggleRow 开关）已移除。
//

import SwiftUI

struct GeneralSettingsView: View {
    @Environment(\.dismiss) var dismiss

    /// 是否自动创建每日任务
    @State private var autoCreateDailyTask: Bool = false
    /// 配置加载状态
    @State private var isLoadingConfig: Bool = true
    /// 当前正在保存的开关 key，用于单独显示开关上的加载态
    @State private var savingKey: String? = nil
    /// AI 模型设置 sheet
    @State private var showAISettings: Bool = false
    /// 请求地址设置 sheet
    @State private var showApiSettings: Bool = false

    // 当前页面作用域的弹窗管理器（避免从 sheet 内部弹全局弹窗被遮挡到背后）
    private let subPopManager = SubPopManager()
    // 当前页面作用域的 PopManager，给 BgResultNetWork 使用，
    // 让网络错误弹窗显示在 sheet 内部而不是被 sheet 遮到背后。
    @StateObject private var popManager = PopManager()

    /// 请求地址副标题：从当前生效的地址生成简短展示
    private var apiSubtitle: String {
        let basic = ApiConfig.currentBasicUrl
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
        let ai = ApiConfig.currentAiUrl
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
        return "业务 \(basic) · AI \(ai)"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.card) {
                    // 说明文字
                    sectionHeader(
                        title: "每日任务",
                        subtitle: "开启后，系统将按你的健康数据自动生成每日的健康任务清单"
                    )

                    // 设置卡片：开关列表
                    VStack(spacing: 0) {
                        toggleRow(
                            icon: "list.bullet.clipboard.fill",
                            iconColor: AppColor.primary,
                            title: "自动创建每日任务",
                            subtitle: "开启后每天自动生成今日任务",
                            isOn: $autoCreateDailyTask,
                            isLoading: savingKey == "autoCreateDailyTask",
                            onChange: { newValue in
                                saveConfig(autoCreateDailyTask: newValue)
                            }
                        )

                        Divider().padding(.leading, 56)

                        // 请求地址设置入口
                        Button {
                            showApiSettings = true
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(AppColor.primary.opacity(0.12))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "network")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AppColor.primary)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("请求地址")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(AppColor.textPrimary)
                                    Text(apiSubtitle)
                                        .font(.system(size: 12))
                                        .foregroundColor(AppColor.textSecondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppColor.textSecondary.opacity(0.6))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppColor.content)
                    )
                    .appShadow(AppShadow.card)
                    .padding(.horizontal, AppSpacing.screen)

                    /*
                    // 临时关闭：通用设置下的 AI 模型设置入口
                    // AI 模型设置入口
                    sectionHeader(
                        title: "AI 模型",
                        subtitle: "配置你需要的主智能体与 OCR 模型（DeepSeek / OpenAI / GLM / KIMI / MiniMax）"
                    )

                    Button {
                        showAISettings = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(AppColor.primary.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "cpu.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppColor.primary)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("AI 模型设置")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AppColor.textPrimary)
                                Text("配置主智能体、OCR 模型及参数")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColor.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppColor.textSecondary.opacity(0.6))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.clear)
                        .glassContainer(.regular.interactive(), cornerRadius: 16)
                        .contentShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, AppSpacing.screen)
                    */

                    Spacer(minLength: 20)
                }
                .padding(.bottom, 30)
            }
            .pageBackground()
            .navigationTitle("通用设置")
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
        .withLocalSubPop(subPopManager)
        .withLocalPop(popManager)
        /*
        // 临时关闭：AI 模型设置 sheet
        .sheet(isPresented: $showAISettings) {
            // 二级 sheet：从通用设置进入 AI 模型设置
            AIConfigListView()
        }
        */
        .sheet(isPresented: $showApiSettings) {
            ApiSettingsView()
        }
        .onAppear {
            loadConfig()
        }
    }

    // MARK: - 子视图

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
        .padding(.top, 4)
    }

    /// 单行设置：图标 + 标题 + 副标题 + Toggle
    /// 加载中时 toggle 禁用，避免重复触发保存
    private func toggleRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        isLoading: Bool,
        onChange: @escaping (Bool) -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            // 标题 / 副标题
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColor.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(AppColor.textSecondary)
            }

            Spacer()

            // 开关 / 加载
            if isLoading {
                ProgressView()
                    .scaleEffect(0.85)
            } else {
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(AppColor.primary)
                    .disabled(isLoadingConfig)
                    .onChange(of: isOn.wrappedValue) { newValue in
                        onChange(newValue)
                    }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - 数据加载与保存

    /// 加载当前用户的配置
    private func loadConfig() {
        isLoadingConfig = true
        SysUserConfigApi.getByUserId(
            completion: { dto in
                DispatchQueue.main.async {
                    autoCreateDailyTask = dto.autoCreateDailyTask ?? SysUserConfigApi.defaultAutoCreateDailyTask
                    isLoadingConfig = false
                }
            },
            popManager: popManager
        )
    }

    /// 保存配置：自动创建每日任务开关状态变化时调用
    ///
    /// 关键约束：
    /// 1. 失败时回滚本地状态，避免 UI 显示与服务端不一致
    /// 2. 失败时通过本地 subPopManager 弹窗提示用户（避免被 sheet 遮挡到背后）
    private func saveConfig(autoCreateDailyTask newValue: Bool) {
        // 防抖：相同 key 正在保存时忽略新请求
        guard savingKey == nil else { return }
        savingKey = "autoCreateDailyTask"
        let previousValue = autoCreateDailyTask

        SysUserConfigApi.saveOrUpdate(
            autoCreateDailyTask: newValue,
            completion: {
                DispatchQueue.main.async {
                    savingKey = nil
                }
            },
            errorHandle: { _, error in
                DispatchQueue.main.async {
                    // 保存失败 → 回滚 UI
                    autoCreateDailyTask = previousValue
                    savingKey = nil
                    // 失败提示：在 sheet 内部弹本地 sub-pop，避免被 sheet 遮挡到背后
                    showLocalErrorPop(message: "\(error)")
                }
            },
            popManager: popManager
        )
    }

    /// 使用当前页面的本地弹窗（subPopManager）展示错误提示，
    /// 避免在 sheet 内部使用全局弹窗 PopManager.shared 被遮挡到页面背后。
    private func showLocalErrorPop(message: String) {
        subPopManager.showCustomSubPopWithHeight(height: 200, customAction: {}) {
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color("warning"))
                    .padding(.top, 8)
                Text("保存失败")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color("text_primary"))
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(Color("text_secondary"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                Spacer()
            }
            .padding(.horizontal, 16)
        }
    }
}

#Preview {
    GeneralSettingsView()
}
