//
//  AIModelConfigEditView.swift
//  QmHealth
//
//  AI 模型配置 - 新增 / 编辑表单
//
//  - 用 Picker 选择用途（主智能体 / OCR / 聊天标题）
//  - 用 Picker 选择模型类型（DeepSeek / OpenAI / GLM / KIMI / MiniMax）
//  - 请求地址、模型名称、API Token、是否多模态、是否启用、备注
//  - 模型名称：可以从下拉候选选，也可自由输入（直接编辑）
//  - 保存时根据 isEdit 调 add 或 update
//

import SwiftUI

struct AIModelConfigEditView: View {
    @Environment(\.dismiss) var dismiss

    /// 传入的编辑项（nil 表示新增）
    let editingDTO: UsersModelConfigDTO?

    /// 新增时的初始用途（从列表页"+ 按钮"传入）；编辑场景忽略
    let initialPurpose: AIModelPurpose?

    /// 当前用户的所有配置（用于保存时启用互斥：同 purpose 下只能一个 enabled）
    let allConfigs: [UsersModelConfigDTO]

    /// 表单 ViewModel
    @StateObject private var form: AIModelConfigEditForm

    /// 默认 DTO 缓存（key 为 subCode），用于切换模型类型时填默认 baseUrl / canSelectModels
    @State private var defaultDtos: [String: SysConfigDTO] = [:]

    /// 当前模型类型对应的可下拉候选模型列表（来自默认配置）
    @State private var canSelectModels: [String] = []

    /// 是否显示 API Token
    @State private var isTokenVisible: Bool = false

    /// 是否展开参数面板
    @State private var isParamsExpanded: Bool = false

    /// 是否正在保存
    @State private var isSaving: Bool = false

    private let subPopManager = SubPopManager()
    @StateObject private var popManager = PopManager()

    init(
        editingDTO: UsersModelConfigDTO? = nil,
        initialPurpose: AIModelPurpose? = nil,
        allConfigs: [UsersModelConfigDTO] = []
    ) {
        self.editingDTO = editingDTO
        self.initialPurpose = initialPurpose
        self.allConfigs = allConfigs
        let form = AIModelConfigEditForm(dto: editingDTO)
        // 新增场景：覆盖为列表页选中的用途
        if editingDTO == nil, let p = initialPurpose {
            form.purpose = p.rawValue
            // OCR 用途强制开启多模态
            if p == .ocr {
                form.isMultimodal = true
            }
        }
        _form = StateObject(wrappedValue: form)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.card) {
                    purposeCard
                    // OCR 使用说明：仅在 purpose=ocr 时显示
                    if AIModelPurpose(rawValue: form.purpose) == .ocr {
                        ocrTipsCard
                    }
                    modelTypeCard
                    baseUrlCard
                    modelNameCard
                    apiKeyCard
                    optionsCard
                    paramsCard
                    remarksCard
                    Spacer(minLength: 24)
                }
                .padding(.vertical, 8)
                .padding(.bottom, 30)
            }
            .pageBackground()
            .navigationTitle(form.isEdit ? "编辑模型" : "新增模型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(AppColor.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView().scaleEffect(0.85)
                        } else {
                            Text("保存").bold()
                        }
                    }
                    .disabled(isSaving)
                    .foregroundStyle(AppColor.primary)
                }
            }
        }
        .withLocalSubPop(subPopManager)
        .withLocalPop(popManager)
        .onAppear {
            loadDefaultConfigs()
        }
        .onChange(of: form.purpose) { _, newValue in
            // OCR 用途强制开启多模态：用途切到 ocr 时自动设为 true
            if AIModelPurpose(rawValue: newValue) == .ocr, !form.isMultimodal {
                form.isMultimodal = true
            }
        }
    }

    // MARK: - 卡片

    /// 用途选择卡片
    private var purposeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("用途", selection: $form.purpose) {
                ForEach(AIModelPurpose.allCases) { p in
                    Text(p.displayName).tag(p.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .tint(AppColor.primary)

            if let p = AIModelPurpose(rawValue: form.purpose) {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColor.textSecondary)
                    Text(p.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
        }.padding(.horizontal,20)
    }

    /// 模型类型选择卡片
    private var modelTypeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("模型类型")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColor.textSecondary)
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(AIModelType.allCases) { type in
                    modelTypeChip(type)
                }
            }
        }
        .padding(14)
        .background(Color.clear)
            .appGlass(.clear.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, AppSpacing.screen)
    }

    private func modelTypeChip(_ type: AIModelType) -> some View {
        let isSelected = form.modelType == type.rawValue
        let tint = type.color
        return Button {
            // 点击时直接走完整切换流程：是否弹确认由 handleChipTap 决定，
            // 完全不依赖 SwiftUI 的 onChange 时机（iOS 17 onChange 是异步触发的，
            // 容易和 applyDefault 的副作用产生循环）。
            handleChipTap(newType: type.rawValue)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if isSelected {
                        // 选中：渐变背景 + 阴影让深色图标更立体
                        Circle()
                            .fill(LinearGradient(
                                colors: [tint, tint.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .shadow(color: tint.opacity(0.45), radius: 6, x: 0, y: 3)
                    } else {
                        Circle().fill(tint.opacity(0.12))
                    }
                    Image(systemName: type.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isSelected ? .white : tint)
                }
                .frame(width: 36, height: 36)

                Text(type.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? AppColor.textPrimary : AppColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            // 选中态用淡色填充区分，不加描边
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? tint.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    /// 请求地址卡片
    private var baseUrlCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("请求地址")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColor.textSecondary)
            TextField("https://...", text: $form.baseUrl)
                .font(.system(size: 14, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColor.background))
        }
        .padding(14)
        .background(Color.clear)
            .appGlass(.clear.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, AppSpacing.screen)
    }

    /// 模型名称卡片：候选下拉 + 自由输入
    private var modelNameCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("模型名称")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                if !canSelectModels.isEmpty {
                    Menu {
                        ForEach(canSelectModels, id: \.self) { name in
                            Button(name) { form.modelName = name }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 11))
                            Text("从默认选择")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(AppColor.primary)
                    }
                }
            }
            TextField("例如：deepseek-chat", text: $form.modelName)
                .font(.system(size: 14, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColor.background))
        }
        .padding(14)
        .background(Color.clear)
            .appGlass(.clear.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, AppSpacing.screen)
    }

    /// API Token 卡片：密码框 + 显示切换
    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("API Token")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColor.textSecondary)
            HStack {
                Group {
                    if isTokenVisible {
                        TextField("请输入 Token", text: $form.apiKey)
                    } else {
                        SecureField("请输入 Token", text: $form.apiKey)
                    }
                }
                .font(.system(size: 14, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)

                Button {
                    isTokenVisible.toggle()
                } label: {
                    Image(systemName: isTokenVisible ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColor.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColor.background))
        }
        .padding(14)
        .background(Color.clear)
            .appGlass(.clear.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, AppSpacing.screen)
    }

    /// 选项卡片：多模态 + 启用
    ///
    /// OCR 用途下多模态必须开启：Toggle 锁定为 true 且不可关闭，
    /// 防止用户配置了不支持图片的模型作为 OCR。
    private var optionsCard: some View {
        let isOCR = AIModelPurpose(rawValue: form.purpose) == .ocr
        return VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.pink)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.pink.opacity(0.12)))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text("支持多模态")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColor.textPrimary)
                        if isOCR {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                        }
                    }
                    Text(isOCR ? "OCR 必须开启多模态" : "开启后可发送图片给模型识别")
                        .font(.system(size: 11))
                        .foregroundStyle(isOCR ? Color.orange : AppColor.textSecondary)
                }
                Spacer()
                if isOCR {
                    // OCR 模式下锁定为开启：Toggle 不可交互，状态永远为 true
                    Toggle("", isOn: .constant(true))
                        .labelsHidden()
                        .tint(AppColor.primary)
                        .disabled(true)
                } else {
                    Toggle("", isOn: $form.isMultimodal)
                        .labelsHidden()
                        .tint(AppColor.primary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider().padding(.leading, 14)

            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.green)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.green.opacity(0.12)))
                VStack(alignment: .leading, spacing: 3) {
                    Text("启用此配置")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColor.textPrimary)
                    Text("关闭后该配置将不参与实际请求")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColor.textSecondary)
                }
                Spacer()
                Toggle("", isOn: $form.enabled)
                    .labelsHidden()
                    .tint(AppColor.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(Color.clear)
            .appGlass(.clear.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, AppSpacing.screen)
    }

    /// OCR 使用提示（仅在 purpose=ocr 时显示）
    private var ocrTipsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.orange)
                Text("OCR 使用说明")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
            }
            tipRow(icon: "1.circle.fill", text: "如果主智能体模型支持多模态，OCR 识别可不设置")
            tipRow(icon: "2.circle.fill", text: "如果设置了 OCR 模型，识别时优先使用 OCR 配置的模型")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.orange.opacity(0.25), lineWidth: 0.8)
        )
        .padding(.horizontal, AppSpacing.screen)
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Color.orange)
                .frame(width: 14)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 备注卡片（可选）
    private var remarksCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("备注（可选）")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColor.textSecondary)
            TextField("例如：用于主对话的国内模型", text: $form.remarks, axis: .vertical)
                .font(.system(size: 14))
                .lineLimit(2...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColor.background))
        }
        .padding(14)
        .background(Color.clear)
            .appGlass(.clear.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, AppSpacing.screen)
    }

    /// 可配置参数卡片（折叠）
    ///
    /// 数据来自系统默认 configParams（如 deepseek 的 temperature / maxTokens 等）。
    /// 按字段类型自动渲染：Bool -> Toggle，Int/Double -> 数字输入框，
    /// String -> 文本输入框，字典/数组 -> 只读占位。
    private var paramsCard: some View {
        let params = form.configParams
        let keys = params.keys.sorted()
        return VStack(alignment: .leading, spacing: 0) {
            // 标题栏（点击展开/收起）
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isParamsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.teal.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.teal)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("可配置参数")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColor.textPrimary)
                        Text(keys.isEmpty ? "该模型暂无默认参数" : "共 \(keys.count) 项 · 来源系统默认配置")
                            .font(.system(size: 11))
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: isParamsExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColor.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            // 展开后的参数列表
            if isParamsExpanded && !keys.isEmpty {
                Divider().padding(.leading, 14)
                VStack(spacing: 10) {
                    ForEach(keys, id: \.self) { key in
                        ParamField(
                            key: key,
                            value: params[key],
                            onChange: { newValue in
                                form.configParams[key] = newValue
                            }
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .background(Color.clear)
            .appGlass(.clear.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, AppSpacing.screen)
    }

    // MARK: - 数据加载与保存

    /// 拉取系统默认配置，填充下拉选项
    private func loadDefaultConfigs() {
        SysConfigApi.listByCode(code: AIConfigConst.code, completion: { dtos in
            DispatchQueue.main.async {
                var map: [String: SysConfigDTO] = [:]
                for dto in dtos {
                    if let sub = dto.subCode {
                        map[sub] = dto
                    }
                }
                defaultDtos = map
                applyDefaultForCurrentModelType()
            }
        }, errorHandle: { _, _ in
            // 默认配置拉取失败不影响提交，保留用户已填值
        }, popManager: popManager)
    }

    /// 切换模型类型时，把默认 baseUrl / canSelectModels / configParams 应用到表单
    private func applyDefaultForCurrentModelType() {
        guard let dto = defaultDtos[form.modelType] else {
            canSelectModels = []
            return
        }
        let models = dto.jsonConfig?.canSelectModels ?? []
        canSelectModels = models
        // form.applyDefault 内部会判断是否覆盖：baseUrl / modelName 仅在用户未填时填入；
        // configParams 仅在用户未编辑时填入默认值，编辑已有配置时不覆盖。
        form.applyDefault(dto: dto, canSelectModels: models)
    }

    /// 处理模型类型切换：已有用户填写内容时弹确认
    ///
    /// - 用户选择"应用新默认"：清空 baseUrl / modelName / configParams 后重新加载
    /// - 用户选择"保留我的"：回滚到旧类型
    /// - API Token 和备注始终保留（与模型类型无关）
    /// chip 点击处理：所有切换决策在按钮 action 内同步完成，不依赖 onChange 时机
    ///
    /// 为什么不用 onChange(of: form.modelType)：
    /// iOS 17+ 的 onChange 是 view body 重新求值前触发的异步回调，
    /// 而 applyDefault 会在 body 内同步修改 baseUrl/modelName/configParams。
    /// 两者时序错位时（先 applyDefault 后 onChange）会让 onChange 误判
    /// "用户已填内容" 而再次弹确认，形成循环。
    /// 所以这里完全在按钮 action 中决定"直接切换 / 弹确认"，无副作用。
    private func handleChipTap(newType: String) {
        guard newType != form.modelType else { return }
        let hasUserContent = !form.baseUrl.trimmingCharacters(in: .whitespaces).isEmpty
            || !form.modelName.trimmingCharacters(in: .whitespaces).isEmpty
            || !form.configParams.isEmpty
        if !hasUserContent {
            // 用户尚未填写任何内容：直接切换 + 加载默认值
            form.modelType = newType
            applyDefaultForCurrentModelType()
            return
        }
        // 弹确认弹窗（form.modelType 暂不切换，等用户在弹窗里选）
        showSwitchModelTypeConfirm(from: form.modelType, to: newType)
    }

    /// 弹切换确认：保留当前 vs 应用新默认
    private func showSwitchModelTypeConfirm(from oldType: String, to newType: String) {
        let oldName = AIModelType(rawValue: oldType)?.displayName ?? oldType
        let newName = AIModelType(rawValue: newType)?.displayName ?? newType
        subPopManager.showCustomSubPopWithHeight(height: 260, customAction: {}) {
            VStack(spacing: 14) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 28))
                    .foregroundStyle(AppColor.primary)
                    .padding(.top, 8)
                Text("切换模型类型")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)
                Text("从「\(oldName)」切换到「\(newName)」\n应用新默认会替换当前请求地址和参数\nAPI Token 和备注会保留")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                Spacer(minLength: 4)
                HStack(spacing: 10) {
                    Button {
                        // 保留我的：form.modelType 仍是旧值，关闭弹窗即可
                        subPopManager.closeSubPop()
                    } label: {
                        Text("保留我的")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColor.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(AppColor.background)
                            )
                    }
                    .buttonStyle(.plain)
                    Button {
                        applyNewModelTypeDefaults(to: newType)
                    } label: {
                        Text("应用新默认")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(AppColor.primary)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 14)
            }
            .padding(.horizontal, 16)
        }
    }

    /// 用户在弹窗中选了"应用新默认"
    ///
    /// 整个流程在按钮 action 同步执行，无任何 onChange 触发路径：
    /// 1. 先清空 baseUrl / modelName / configParams
    /// 2. 再设置 form.modelType = newType（不会再被任何 onChange 拦截）
    /// 3. 加载新类型默认值
    /// 4. 关闭弹窗
    private func applyNewModelTypeDefaults(to newType: String) {
        // 1. 关闭弹窗（用户已决策）
        subPopManager.closeSubPop()
        // 2. 同步清空受类型影响的字段（baseUrl / modelName / configParams）
        form.baseUrl = ""
        form.modelName = ""
        form.configParams = [:]
        // 3. 切换类型
        form.modelType = newType
        // 4. 加载新类型默认值（form.applyDefault 在 baseUrl 等为空时填入默认值）
        applyDefaultForCurrentModelType()
        // 5. 强制 SwiftUI 立即处理本帧的脏区，避免 onChange 在下一帧再次触发
        //    （虽然我们已经移除了 onChange，但保持显式 flush 更稳）
    }

    /// 保存（新增或更新）
    ///
    /// 互斥规则：同一 purpose 下只能有一个 enabled=1 的配置。保存时（无论新增还是更新），
    /// 先把同 purpose 的其它已启用配置批量禁用，再保存当前配置。
    private func save() {
        guard !isSaving else { return }
        if let error = form.validate() {
            showLocalErrorPop(message: error)
            return
        }
        // 把可配置参数转成 AnyCodable 写入 extraConfig（空字典则不传）
        let extraConfig: AnyCodable? = form.configParams.isEmpty
            ? nil
            : AnyCodable(form.configParams)

        // 找出需要禁用的同 purpose 其它 enabled 配置（仅在当前要启用时）
        let currentId = form.id ?? ""
        let needDisable: [String] = form.enabled ? allConfigs
            .filter { $0.purpose == form.purpose
                && $0.isEnabled
                && ($0.id ?? "") != currentId
                && !($0.id ?? "").isEmpty }
            .compactMap { $0.id } : []

        if needDisable.isEmpty {
            performSave(extraConfig: extraConfig)
        } else {
            // 先串行禁用其它，再保存当前
            isSaving = true
            disableOthersSequentially(ids: needDisable, index: 0, extraConfig: extraConfig)
        }
    }

    /// 串行禁用其它配置：失败也继续，最终都会执行保存
    private func disableOthersSequentially(ids: [String], index: Int, extraConfig: AnyCodable?) {
        if index >= ids.count {
            performSave(extraConfig: extraConfig)
            return
        }
        let id = ids[index]
        let param = UsersModelConfigUpdateDTO(id: id, enabled: 0)
        UsersModelConfigApi.update(param: param, completion: {
            DispatchQueue.main.async {
                self.disableOthersSequentially(ids: ids, index: index + 1, extraConfig: extraConfig)
            }
        }, errorHandle: { _, _ in
            // 失败不阻塞流程，继续禁用下一条
            DispatchQueue.main.async {
                self.disableOthersSequentially(ids: ids, index: index + 1, extraConfig: extraConfig)
            }
        }, popManager: popManager)
    }

    /// 执行真正的 add / update
    private func performSave(extraConfig: AnyCodable?) {
        isSaving = true
        if let id = form.id, !id.isEmpty {
            // 更新
            let param = UsersModelConfigUpdateDTO(
                id: id,
                modelType: form.modelType,
                modelName: form.modelName,
                baseUrl: form.baseUrl,
                apiKey: form.apiKey,
                purpose: form.purpose,
                isMultimodal: form.isMultimodal ? 1 : 0,
                enabled: form.enabled ? 1 : 0,
                extraConfig: extraConfig,
                remarks: form.remarks.isEmpty ? nil : form.remarks
            )
            UsersModelConfigApi.update(param: param, completion: {
                DispatchQueue.main.async {
                    isSaving = false
                    popManager.showSimplePop(title: "成功", description: "已更新")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }
            }, errorHandle: { _, error in
                DispatchQueue.main.async {
                    isSaving = false
                    showLocalErrorPop(message: "保存失败：\(error)")
                }
            }, popManager: popManager)
        } else {
            // 新增
            let param = UsersModelConfigAddDTO(
                modelType: form.modelType,
                modelName: form.modelName,
                baseUrl: form.baseUrl,
                apiKey: form.apiKey,
                purpose: form.purpose,
                isMultimodal: form.isMultimodal ? 1 : 0,
                enabled: form.enabled ? 1 : 0,
                extraConfig: extraConfig,
                remarks: form.remarks.isEmpty ? nil : form.remarks
            )
            UsersModelConfigApi.add(param: param, completion: { _ in
                DispatchQueue.main.async {
                    isSaving = false
                    popManager.showSimplePop(title: "成功", description: "已添加")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }
            }, errorHandle: { _, error in
                DispatchQueue.main.async {
                    isSaving = false
                    showLocalErrorPop(message: "保存失败：\(error)")
                }
            }, popManager: popManager)
        }
    }

    private func showLocalErrorPop(message: String) {
        subPopManager.showCustomSubPopWithHeight(height: 200, customAction: {}) {
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(AppColor.warning)
                    .padding(.top, 8)
                Text("提示")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                Spacer()
            }
            .padding(.horizontal, 16)
        }
    }
}

#Preview {
    AIModelConfigEditView()
}
