//
//  AddMedicinePlanView.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/7/22.
//

import SwiftUI

// MARK: - 添加用药计划
/// 当前仅实现本地表单样式与交互，不提交后端。
struct AddMedicinePlanView: View {
    @Environment(\.dismiss) private var dismiss
    /// 由父视图加载的值域；使用绑定确保异步返回后菜单能立即刷新。
    @Binding var valueScopes: [String: ValueScopeInfo]
    /// 剂型名称对应的默认剂量单位，由父视图统一加载。
    @Binding var medicineFormUnits: [String: [String]]
    /// 新增成功或更新成功后回传计划，供父视图刷新列表。
    let onSaved: (UsersMedicinePlanDTO) -> Void
    /// 删除成功后通知父视图刷新计划列表。
    let onDeleted: () -> Void
    /// 设置后，完成表单仅将药品计划作为草稿回传，不会调用独立的用药计划接口。
    let onDraftSaved: ((UsersMedicinePlanDTO) -> Void)?
    /// 非空时表示编辑模式，表单会使用详情接口返回的完整计划预填。
    let editingPlan: UsersMedicinePlanDTO?

    private var isDraftMode: Bool {
        onDraftSaved != nil
    }

    @State private var medicineName = ""
    @State private var selectedForm = "2"
    @State private var specification = ""
    @State private var specificationUnit = "mg"
    @State private var frequencyType: MedicineFrequencyType = .daily
    /// 每天、循环定时、每隔 N 天共用的时间点数组。
    @State private var commonDoseTimes = [PlanDoseTime()]
    /// 每个星期对应独立的服药时间数组；初始均为空。
    /// 仅含有至少一个时间点的星期会被写入 TakingInfoRaw。
    @State private var weeklyDoseTimes: [String: [PlanDoseTime]] = [:]
    /// 当前正在编辑的星期，点击上方星期仅切换该值。
    @State private var selectedWeeklyDayKey = "mon"
    /// 循环单位：1-天，2-周。
    @State private var cycleUnit = 1
    @State private var cycleUseTimes = 3
    @State private var cycleStopTimes = 1
    @State private var intervalDays = 7
    @State private var startDate = Date()
    @State private var isLongTerm = true
    @State private var endDate = Date()
    @State private var sourceType: Int16 = MedicineSourceType.selfAdded.rawValue
    @State private var medicalAdvice = ""
    @State private var isSubmitting = false
    @State private var isDeleting = false
    @State private var showsDeleteConfirmation = false
    /// 药品名称输入后返回的已有计划，用于展示同名候选和精确重复提示。
    @State private var planSuggestions: [UsersMedicinePlanDTO] = []
    @State private var isLoadingPlanSuggestions = false
    @State private var showPlanSuggestions = false
    @State private var planSearchTask: Task<Void, Never>?
    @FocusState private var isMedicineNameFocused: Bool
    /// 保存前二次校验到的精确重复计划。
    @State private var duplicatePlanForConfirmation: UsersMedicinePlanDTO?
    @State private var showsDuplicateConfirmation = false
    /// 在当前页面内打开已有计划的编辑界面。
    @State private var existingPlanForEditing: UsersMedicinePlanDTO?
    /// 当前向导步骤：0-药品信息，1-计划设置，2-医嘱备注。
    @State private var currentStep = 0

    private let weekdays: [WeeklyDay] = [
        WeeklyDay(key: "mon", label: "周一"),
        WeeklyDay(key: "tue", label: "周二"),
        WeeklyDay(key: "wed", label: "周三"),
        WeeklyDay(key: "thu", label: "周四"),
        WeeklyDay(key: "fri", label: "周五"),
        WeeklyDay(key: "sat", label: "周六"),
        WeeklyDay(key: "sun", label: "周日")
    ]

    init(
        valueScopes: Binding<[String: ValueScopeInfo]>,
        medicineFormUnits: Binding<[String: [String]]>,
        onSaved: @escaping (UsersMedicinePlanDTO) -> Void,
        editingPlan: UsersMedicinePlanDTO? = nil,
        onDeleted: @escaping () -> Void = {},
        onDraftSaved: ((UsersMedicinePlanDTO) -> Void)? = nil
    ) {
        self._valueScopes = valueScopes
        self._medicineFormUnits = medicineFormUnits
        self.onSaved = onSaved
        self.editingPlan = editingPlan
        self.onDeleted = onDeleted
        self.onDraftSaved = onDraftSaved
    }

    private var medicineForms: [ValueScopeItem] {
        valueScopes["medicineForm"]?.valueScope ?? []
    }

    private var specificationUnits: [ValueScopeItem] {
        valueScopes["medicineSpecificationUnit"]?.valueScope ?? []
    }

    private var frequencyTypes: [MedicineFrequencyType] {
        valueScopes["medicineFrequencyType"]?.valueScope.compactMap {
            Int16($0.value).flatMap(MedicineFrequencyType.init(rawValue:))
        } ?? []
    }

    /// 用药计划来源由 medicinePlanSourceType 值域驱动；值域尚未返回时使用已知默认项，避免表单空白。
    private var planSources: [ValueScopeItem] {
        let sources = valueScopes["medicinePlanSourceType"]?.valueScope ?? []
        if !sources.isEmpty {
            return sources
        }
        return MedicineSourceType.allCases.map {
            ValueScopeItem(value: String($0.rawValue), desc: $0.displayName)
        }
    }

    private var selectedFormDescription: String {
        valueScopes["medicineForm"]?.desc(forValue: selectedForm) ?? "请选择"
    }

    private var specificationUnitDescription: String {
        valueScopes["medicineSpecificationUnit"]?.desc(forValue: specificationUnit) ?? "请选择"
    }

    private var doseUnits: [String] {
        medicineFormUnits[selectedFormDescription] ?? []
    }

    private var defaultDoseUnit: String? {
        doseUnits.first
    }

    /// 值域异步到达后，为新建计划选择实际存在的默认剂型和规格单位。
    private func applyMetadataDefaults() {
        guard editingPlan == nil else { return }
        if !medicineForms.contains(where: { $0.value == selectedForm }), let firstForm = medicineForms.first {
            selectedForm = firstForm.value
        }
        if !specificationUnits.contains(where: { $0.value == specificationUnit }), let firstUnit = specificationUnits.first {
            specificationUnit = firstUnit.value
        }
        applyDefaultDoseUnit()
    }

    private var isFormValid: Bool {
        !medicineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !specification.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 当前输入是否与已有计划在名称、剂型、规格和规格单位上完全一致。
    private var exactDuplicatePlan: UsersMedicinePlanDTO? {
        let name = normalized(medicineName)
        let spec = normalized(specification)
        guard !name.isEmpty, !spec.isEmpty else { return nil }
        return planSuggestions.first {
            normalized($0.medicineName ?? "") == name
                && $0.medicineForm == selectedForm
                && normalized($0.specification ?? "") == spec
                && $0.specificationUnit == specificationUnit
                && $0.id != editingPlan?.id
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: isDraftMode ? "添加就诊用药" : (editingPlan == nil ? "添加用药计划" : "编辑用药计划"))
                .padding(.bottom, 12)

            planPreview
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

            ScrollView(.vertical, showsIndicators: false) {
                stepContent
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            .id(currentStep)
            .simultaneousGesture(TapGesture().onEnded { hideKeyboard() })

            wizardActionButtons
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("background"))
        .alert("删除用药计划？", isPresented: $showsDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deletePlan()
            }
        } message: {
            Text("删除后无法恢复，确定要删除“\(medicineName)”吗？")
        }
        .alert("已存在相同药品计划", isPresented: $showsDuplicateConfirmation) {
            Button("查看已有计划") {
                if let plan = duplicatePlanForConfirmation {
                    openExistingPlan(plan)
                }
            }
            Button("仍然创建") {
                savePlan()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("“\(duplicatePlanForConfirmation?.medicineName ?? medicineName)”（\(selectedFormDescription) · \(duplicatePlanForConfirmation?.specificationString ?? previewSpecification)）已有用药计划。继续创建可能导致重复提醒。")
        }
        .sheet(item: $existingPlanForEditing) { plan in
            AddMedicinePlanView(
                valueScopes: $valueScopes,
                medicineFormUnits: $medicineFormUnits,
                onSaved: onSaved,
                editingPlan: plan,
                onDeleted: onDeleted
            )
        }
        .onAppear {
            populateFormIfNeeded()
            applyMetadataDefaults()
        }
        .onChange(of: medicineForms.count) { _, _ in
            applyMetadataDefaults()
        }
        .onChange(of: medicineFormUnits) { _, _ in
            applyMetadataDefaults()
        }
        .onDisappear {
            planSearchTask?.cancel()
        }
    }

    // MARK: - 向导概览
    private var planPreview: some View {
        HStack(spacing: 12) {
            Image(systemName: MedicineFormIcon.systemName(for: selectedFormDescription))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.theme(.primary))
                .frame(width: 46, height: 46)
                .background {
                    RoundedRectangle(cornerRadius: AppRadius.max, style: .continuous)
                        .fill(Color.theme(.primary).opacity(0.1))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(medicineName.isEmpty ? "新建用药计划" : medicineName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                    .lineLimit(1)

                Text(previewSpecification)
                    .font(.system(size: 12))
                    .foregroundStyle(Color("text_secondary"))
                    .lineLimit(1)

                Text(previewSchedule)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.theme(.primary))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    @ViewBuilder
    private var stepContent: some View {
        VStack(spacing: 12) {
            switch currentStep {
            case 0:
                medicineSection
            case 1:
                frequencySection
                scheduleSection
                periodSection
                sourceSection
            default:
                adviceSection
            }
        }
    }

    private var previewSpecification: String {
        let specificationText = specification.isEmpty ? "待填写规格" : "\(specification)\(specificationUnit)"
        return "\(selectedFormDescription) · \(specificationText)"
    }

    private var previewSchedule: String {
        switch frequencyType {
        case .daily:
            return "\(frequencyTitle(frequencyType)) · \(commonDoseTimes.count) 个服药时间"
        case .cyclic:
            let unit = cycleUnit == 1 ? "天" : "周"
            return "循环：服 \(cycleUseTimes)\(unit)，停 \(cycleStopTimes)\(unit)"
        case .weekly:
            let dayCount = weeklyDoseTimes.values.filter { !$0.isEmpty }.count
            return "每周特定日 · 已设置 \(dayCount) 天"
        case .interval:
            return "每隔 \(intervalDays) 天 · \(commonDoseTimes.count) 个服药时间"
        case .asNeeded:
            return frequencyTitle(frequencyType)
        }
    }

    // MARK: - 药品信息
    private var medicineSection: some View {
        formCard {
            sectionTitle(icon: "pills.fill", title: "药品信息")

            TextField("请输入药品名称", text: $medicineName)
                .padding(.horizontal, 10)
                .inputFieldStyle()
                .focused($isMedicineNameFocused)
                .onChange(of: medicineName) { _, newValue in
                    schedulePlanSearch(for: newValue)
                }
                .onChange(of: isMedicineNameFocused) { _, focused in
                    if !focused {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            showPlanSuggestions = false
                        }
                    }
                }

            if showPlanSuggestions {
                planSuggestionsView
            }

            HStack(spacing: 10) {
                selectorField(title: "剂型", value: selectedForm) {
                    Menu {
                        ForEach(medicineForms, id: \.value) { form in
                            Button(form.desc) {
                                selectedForm = form.value
                                applyDefaultDoseUnit()
                            }
                        }
                    } label: {
                        selectorLabel(selectedFormDescription)
                    }
                }
                .frame(width: 150)

                selectorField(title: "规格", value: specification) {
                    HStack(spacing: 8) {
                        TextField("如 500", text: $specification)
                            .font(.system(size: 14, weight: .medium))
                            .keyboardType(.decimalPad)
                            .foregroundStyle(Color("text_primary"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer(minLength: 0)
                        Menu {
                            ForEach(specificationUnits, id: \.value) { unit in
                                Button(unit.desc) { specificationUnit = unit.value }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(specificationUnitDescription)
                                    .font(.system(size: 13, weight: .semibold))
                                    .lineLimit(1)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(Color.theme(.primary))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .frame(height: 20)
                    .inputFieldStyle()
                }
                .frame(maxWidth: .infinity)
            }

            if let duplicatePlan = exactDuplicatePlan {
                exactDuplicateNotice(plan: duplicatePlan)
            }
        }
    }

    private var planSuggestionsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoadingPlanSuggestions {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在查找已有用药计划…")
                }
                .font(.system(size: 12))
                .foregroundStyle(Color("text_secondary"))
                .padding(10)
            } else if planSuggestions.isEmpty {
                Text("未找到同名用药计划")
                    .font(.system(size: 12))
                    .foregroundStyle(Color("text_secondary"))
                    .padding(10)
            } else {
                Text("已有用药计划")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color("text_secondary"))
                    .padding(.horizontal, 10)
                    .padding(.top, 9)
                    .padding(.bottom, 5)

                ForEach(Array(planSuggestions.prefix(5))) { plan in
                    Button {
                        if !isDraftMode {
                            openExistingPlan(plan)
                        }
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: MedicineFormIcon.systemName(for: valueScopes["medicineForm"]?.desc(forValue: plan.medicineForm ?? "") ?? ""))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.theme(.primary))
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.medicineName ?? "未知药品")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color("text_primary"))
                                Text(planDisplayDescription(plan))
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color("text_secondary"))
                            }
                            Spacer()
                            Text(isDraftMode ? "已有计划" : "查看")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color("text_secondary"))
                            if !isDraftMode {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color("text_secondary").opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .glassContainer(.regular.interactive(), cornerRadius: 10)
    }

    private func exactDuplicateNotice(plan: UsersMedicinePlanDTO) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color("warning"))
            VStack(alignment: .leading, spacing: 3) {
                Text("已存在相同药品计划")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                Text("\(plan.medicineName ?? "") · \(planDisplayDescription(plan))")
                    .font(.system(size: 12))
                    .foregroundStyle(Color("text_secondary"))
                Text(isDraftMode ? "该用药计划已存在，仍可作为本次就诊用药加入。" : "建议编辑已有计划，避免重复提醒。")
                    .font(.system(size: 11))
                    .foregroundStyle(Color("text_secondary"))
            }
            Spacer(minLength: 6)
            if !isDraftMode {
                Button("查看") {
                    openExistingPlan(plan)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.theme(.primary))
            }
        }
        .padding(10)
        .appGlass(
            Glass.clear.interactive().tint(Color("warning").opacity(0.25)),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        ) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color("warning").opacity(0.1))
        }
    }

    // MARK: - 用药频次
    private var frequencySection: some View {
        formCard {
            sectionTitle(icon: "repeat", title: "服药频次")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(frequencyTypes, id: \.self) { type in
                    Button {
                        frequencyType = type
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: type.icon)
                                .font(.system(size: 14, weight: .semibold))
                            Text(frequencyTitle(type))
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(frequencyType == type ? Color.white : Color("text_secondary"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .contentShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                        .glassCardStyle(.regular.interactive().tint(frequencyType == type ? Color.theme(.primary) : Color.clear), cornerRadius: AppRadius.medium)
                    }
                }
            }
        }
    }

    // MARK: - 服药安排
    private var scheduleSection: some View {
        formCard {
            sectionTitle(icon: "clock.fill", title: "服药安排")

            switch frequencyType {
            case .daily:
                Text("每天按以下时间服药")
                    .hintTextStyle()
                doseTimeEditor(times: $commonDoseTimes)
            case .cyclic:
                cycleSettings
                doseTimeEditor(times: $commonDoseTimes)
            case .weekly:
                Text("点击星期切换编辑；有服药时间的日期会高亮显示")
                    .hintTextStyle()
                weekdaySelector
                if let selectedDay = weekdays.first(where: { $0.key == selectedWeeklyDayKey }) {
                    weeklyDoseTimeEditor(for: selectedDay)
                }
            case .interval:
                intervalSettings
                doseTimeEditor(times: $commonDoseTimes)
            case .asNeeded:
                HStack(spacing: 10) {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(Color.theme(.primary))
                    Text("按需服用，不会生成服药安排数据")
                        .font(.system(size: 13))
                        .foregroundStyle(Color("text_secondary"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCardStyle()
            }
        }
    }

    private var cycleSettings: some View {
        VStack(spacing: 10) {
            Picker("周期单位", selection: $cycleUnit) {
                Text("按天循环").tag(1)
                Text("按周循环").tag(2)
            }
            .pickerStyle(.segmented)

            cycleCountControl(
                title: "连续服用",
                subtitle: "服用后进入停用阶段",
                value: $cycleUseTimes,
                unit: cycleUnit == 1 ? "天" : "周",
                icon: "pills.fill",
                color: Color.theme(.primary)
            )

            cycleCountControl(
                title: "停用",
                subtitle: "停用后重新开始循环",
                value: $cycleStopTimes,
                unit: cycleUnit == 1 ? "天" : "周",
                icon: "pause.fill",
                color: Color("warning")
            )
        }
    }

    private var intervalSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("设置相邻两次服药周期之间的间隔")
                .hintTextStyle()

            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.theme(.primary))
                    .frame(width: 34, height: 34)
                    .appGlass(
                        Glass.clear.interactive().tint(Color.theme(.primary).opacity(0.25)),
                        in: Circle()
                    ) {
                        Circle().fill(Color.theme(.primary).opacity(0.1))
                    }

                Text("每隔")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color("text_primary"))

                counterControl(value: $intervalDays, unit: "天")

                Spacer()
            }
            .inputFieldStyle()
        }
    }

    private var weekdaySelector: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
            ForEach(weekdays) { weekday in
                let hasDoseTimes = weeklyDoseTimes[weekday.key]?.isEmpty == false
                Button {
                    // 星期按钮仅用于切换编辑对象，不会修改该日的服药数据。
                    selectedWeeklyDayKey = weekday.key
                } label: {
                    Text(String(weekday.label.suffix(1)))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(hasDoseTimes ? Color.white : Color("text_secondary"))
                        .frame(width: 34, height: 34)
                        .contentShape(Circle())
                        .appGlass(
                            hasDoseTimes ? Glass.regular.interactive().tint(Color.theme(.primary)) : Glass.clear.interactive(),
                            in: Circle()
                        ) {
                            Circle().fill(hasDoseTimes ? Color.theme(.primary) : Color("input_bg"))
                        }
                        .overlay {
                            if selectedWeeklyDayKey == weekday.key {
                                Circle().stroke(Color.theme(.primary), lineWidth: 2)
                                    .padding(-3)
                            }
                        }
                }
            }
        }
    }

    private func weeklyDoseTimeEditor(for weekday: WeeklyDay) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.theme(.primary))
                Text("\(weekday.label)服药安排")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                Spacer()
                Text("切换上方日期可分别编辑")
                    .font(.system(size: 11))
                    .foregroundStyle(Color("text_secondary"))
            }
            doseTimeEditor(
                times: weeklyDoseTimesBinding(for: weekday.key),
                allowsEmpty: true
            )
        }
        .padding(10)
        .appGlass(.regular.interactive(), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func doseTimeEditor(
        times: Binding<[PlanDoseTime]>,
        allowsEmpty: Bool = false
    ) -> some View {
        VStack(spacing: 8) {
            ForEach(times) { $doseTime in
                HStack(spacing: 8) {
                    DatePicker("", selection: $doseTime.time, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(Color.theme(.primary))

                    TextField("剂量", text: $doseTime.amount)
                        .font(.system(size: 14, weight: .medium))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .inputFieldStyle()

                    Menu {
                        ForEach(doseUnits, id: \.self) { unit in
                            Button(unit) { doseTime.unit = unit }
                        }
                    } label: {
                        compactDoseUnitLabel(doseTime.unit)
                    }

                    Button {
                        times.wrappedValue.removeAll { $0.id == doseTime.id }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(allowsEmpty || times.wrappedValue.count > 1 ? Color("text_secondary") : Color("divider"))
                    }
                    .disabled(!allowsEmpty && times.wrappedValue.count == 1)
                }
            }

            Button {
                times.wrappedValue.append(makeDoseTime(at: times.wrappedValue.count))
            } label: {
                Label("添加服药时间", systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.theme(.primary))
                    .frame(maxWidth: .infinity)
            }.buttonStyle(SecondaryActionButtonStyle())
        }
    }

    // MARK: - 计划周期
    private var periodSection: some View {
        formCard {
            sectionTitle(icon: "calendar", title: "计划周期")

            HStack {
                Text("开始日期")
                    .formLabelStyle()
                Spacer()
                DatePicker("", selection: $startDate, displayedComponents: .date)
                    .labelsHidden()
                    .tint(Color.theme(.primary))
            }

            Divider().overlay(Color("divider"))

            Toggle("长期服药", isOn: $isLongTerm)
                .font(.system(size: 14, weight: .medium))
                .tint(Color.theme(.primary))

            if !isLongTerm {
                HStack {
                    Text("结束日期")
                        .formLabelStyle()
                    Spacer()
                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                        .labelsHidden()
                        .tint(Color.theme(.primary))
                }
            }
        }
    }

    // MARK: - 来源和医嘱
    private var sourceSection: some View {
        formCard {
            sectionTitle(icon: "tag.fill", title: "计划来源")

            HStack(spacing: 8) {
                ForEach(planSources, id: \.value) { source in
                    if let sourceValue = Int16(source.value) {
                        Button {
                            sourceType = sourceValue
                        } label: {
                            Text(source.desc)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(sourceType == sourceValue ? Color.white : Color("text_secondary"))
                                .frame(maxWidth: .infinity)
                        }.buttonStyle(SecondaryActionButtonStyle(tintColor: sourceType == sourceValue ? Color.theme(.primary) : Color.clear))
                    }
                }
            }
        }
    }

    private var adviceSection: some View {
        formCard {
            sectionTitle(icon: "note.text", title: "医嘱与备注", optional: true)

            TextField("如：饭后服用，避免空腹", text: $medicalAdvice, axis: .vertical)
                .font(.system(size: 14))
                .foregroundStyle(Color("text_primary"))
                .lineLimit(3...5)
                .formTextFieldStyle()
        }
    }

    // MARK: - 向导底部操作
    private var wizardActionButtons: some View {
        HStack(spacing: 12) {
            Button(leftActionTitle) {
                if currentStep == 0 {
                    if editingPlan != nil {
                        showsDeleteConfirmation = true
                    } else {
                        dismiss()
                    }
                } else {
                    currentStep -= 1
                }
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .disabled(isDeleting)

            
            Button {
                if currentStep == 2 {
                    submitPlan()
                } else {
                    currentStep += 1
                }
            } label: {
                Text(currentStep == 2 && isSubmitting ? "保存中…" : (currentStep == 2 ? (isDraftMode ? "加入就诊记录" : (editingPlan == nil ? "完成" : "保存修改")) : "下一步"))
                    .foregroundStyle(AppColor.primary)
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .disabled(!isCurrentStepValid || isSubmitting)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color("background"))
    }

    private var leftActionTitle: String {
        guard currentStep == 0 else { return "上一步" }
        if isDeleting { return "删除中…" }
        return editingPlan == nil ? "取消" : "删除"
    }

    private var isCurrentStepValid: Bool {
        switch currentStep {
        case 0:
            return isFormValid
        case 1:
            switch frequencyType {
            case .asNeeded:
                return true
            case .weekly:
                return weeklyDoseTimes.values.contains { !$0.isEmpty }
            case .daily, .cyclic, .interval:
                return !commonDoseTimes.isEmpty
            }
        default:
            return true
        }
    }

    // MARK: - 通用视图
    private func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .cardStyle()
    }

    private func sectionTitle(icon: String, title: String, optional: Bool = false) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.theme(.primary))
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color("text_primary"))
            if optional {
                Text("选填")
                    .font(.system(size: 11))
                    .foregroundStyle(Color("text_secondary"))
            }
        }
    }

    private func selectorField<Content: View>(title: String, value: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).formLabelStyle()
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectorLabel(_ value: String) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(Color("text_primary"))
        .frame(height: 20, alignment: .center)
        .inputFieldStyle()
    }

    private func cycleCountControl(
        title: String,
        subtitle: String,
        value: Binding<Int>,
        unit: String,
        icon: String,
        color: Color
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .appGlass(
                    Glass.clear.interactive().tint(color.opacity(0.25)),
                    in: Circle()
                ) {
                    Circle().fill(color.opacity(0.1))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color("text_secondary"))
            }

            Spacer()
            counterControl(value: value, unit: unit)
        }
        .inputFieldStyle()
    }

    private func counterControl(value: Binding<Int>, unit: String) -> some View {
        HStack(spacing: 8) {
            Button {
                value.wrappedValue = max(1, value.wrappedValue - 1)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(value.wrappedValue > 1 ? Color("text_secondary") : Color("divider"))
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
                    .appGlass(
                        Glass.clear.interactive().tint(value.wrappedValue > 1 ? Color("text_secondary").opacity(0.2) : Color("divider").opacity(0.4)),
                        in: Circle()
                    ) {
                        Circle().fill(value.wrappedValue > 1 ? Color("text_secondary").opacity(0.1) : Color("divider").opacity(0.35))
                    }
            }
            .disabled(value.wrappedValue <= 1)

            Text("\(value.wrappedValue)\(unit)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.theme(.primary))
                .frame(minWidth: 38)

            Button {
                value.wrappedValue = min(99, value.wrappedValue + 1)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.theme(.primary))
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
                    .appGlass(
                        Glass.clear.interactive().tint(Color.theme(.primary).opacity(0.25)),
                        in: Circle()
                    ) {
                        Circle().fill(Color.theme(.primary).opacity(0.1))
                    }
            }
        }
    }

    private func frequencyTitle(_ type: MedicineFrequencyType) -> String {
        valueScopes["medicineFrequencyType"]?.desc(forValue: String(type.rawValue)) ?? ""
    }

    /// 编辑模式下，将详情接口返回的动态 takingInfo 还原为三步表单状态。
    private func populateFormIfNeeded() {
        guard let plan = editingPlan else { return }
        medicineName = plan.medicineName ?? ""
        selectedForm = plan.medicineForm ?? selectedForm
        specification = plan.specification ?? ""
        specificationUnit = plan.specificationUnit ?? specificationUnit
        frequencyType = plan.frequencyTypeEnum ?? frequencyType
        sourceType = plan.sourceType ?? sourceType
        medicalAdvice = plan.medicalAdvice ?? ""

        if let start = date(from: plan.startDate) {
            startDate = start
        }
        if let end = date(from: plan.endDate) {
            isLongTerm = false
            endDate = end
        } else {
            isLongTerm = true
        }

        let info = plan.takingInfo
        commonDoseTimes = planDoseTimes(from: info?.times)
        cycleUnit = info?.cycleUnit ?? cycleUnit
        cycleUseTimes = info?.cycleUseTimes ?? cycleUseTimes
        cycleStopTimes = info?.cycleStopTimes ?? cycleStopTimes
        intervalDays = info?.intervalDays ?? intervalDays
        weeklyDoseTimes = weeklyDoseTimes(from: info)
        selectedWeeklyDayKey = weekdays.first(where: { weeklyDoseTimes[$0.key]?.isEmpty == false })?.key ?? "mon"
    }

    private func date(from value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = DateUtils.DateFormat.ymd
        return formatter.date(from: value)
    }

    private func planDoseTimes(from times: [DoseTime]?) -> [PlanDoseTime] {
        guard let times, !times.isEmpty else { return [PlanDoseTime()] }
        return times.map { doseTime in
            PlanDoseTime(
                time: time(from: doseTime.time),
                amount: Self.doseAmountText(doseTime.doseAmount),
                unit: doseTime.doseUnit
            )
        }
    }

    private func weeklyDoseTimes(from info: TakingInfoRaw?) -> [String: [PlanDoseTime]] {
        let mapping: [(String, [DoseTime]?)] = [
            ("sun", info?.sun), ("mon", info?.mon), ("tue", info?.tue), ("wed", info?.wed),
            ("thu", info?.thu), ("fri", info?.fri), ("sat", info?.sat)
        ]
        return Dictionary(uniqueKeysWithValues: mapping.compactMap { key, times in
            guard let times, !times.isEmpty else { return nil }
            return (key, planDoseTimes(from: times))
        })
    }

    private func time(from value: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = DateUtils.DateFormat.hm
        return formatter.date(from: value) ?? PlanDoseTime.suggestedTime(at: 0)
    }

    private static func doseAmountText(_ amount: Double) -> String {
        amount == amount.rounded() ? String(Int(amount)) : String(amount)
    }

    /// 按当前频次组装的 takingInfo；保存接口接入时可直接使用该值。
    private var takingInfoForCurrentSchedule: TakingInfoRaw? {
        switch frequencyType {
        case .daily:
            return TakingInfoRaw(times: doseTimesPayload(from: commonDoseTimes))
        case .cyclic:
            return TakingInfoRaw(
                times: doseTimesPayload(from: commonDoseTimes),
                cycleUnit: cycleUnit,
                cycleUseTimes: cycleUseTimes,
                cycleStopTimes: cycleStopTimes
            )
        case .weekly:
            return TakingInfoRaw(
                sun: weeklyPayload(for: "sun"),
                mon: weeklyPayload(for: "mon"),
                tue: weeklyPayload(for: "tue"),
                wed: weeklyPayload(for: "wed"),
                thu: weeklyPayload(for: "thu"),
                fri: weeklyPayload(for: "fri"),
                sat: weeklyPayload(for: "sat")
            )
        case .interval:
            return TakingInfoRaw(
                times: doseTimesPayload(from: commonDoseTimes),
                intervalDays: intervalDays
            )
        case .asNeeded:
            return nil
        }
    }

    // MARK: - 已有计划查询与重复校验
    private func schedulePlanSearch(for keyword: String) {
        planSearchTask?.cancel()
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard editingPlan == nil, !trimmed.isEmpty else {
            showPlanSuggestions = false
            planSuggestions = []
            return
        }

        planSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            searchMedicinePlans(keyword: trimmed)
        }
    }

    private func searchMedicinePlans(keyword: String) {
        isLoadingPlanSuggestions = true
        showPlanSuggestions = true
        let params = MedicinePlanPageParam(medicineName: keyword, pageNumber: 1, pageSize: 10)
        BgResultNetWork<MedicinePlanPageParam, Page<UsersMedicinePlanDTO>>.post(
            apiUrl(MEDICINE_PLAN_PAGE),
            params: params
        )
        .complicationHand { (page: Page<UsersMedicinePlanDTO>?) in
            planSuggestions = page?.datas ?? []
            isLoadingPlanSuggestions = false
        }
        .errorHandle { _, _ in
            isLoadingPlanSuggestions = false
            planSuggestions = []
        }
        .responseDecodable()
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func isExactDuplicate(_ plan: UsersMedicinePlanDTO) -> Bool {
        normalized(plan.medicineName ?? "") == normalized(medicineName)
            && plan.medicineForm == selectedForm
            && normalized(plan.specification ?? "") == normalized(specification)
            && plan.specificationUnit == specificationUnit
            && plan.id != editingPlan?.id
    }

    private func planDisplayDescription(_ plan: UsersMedicinePlanDTO) -> String {
        let form = valueScopes["medicineForm"]?.desc(forValue: plan.medicineForm ?? "") ?? "未知剂型"
        let specification = plan.specificationString.isEmpty ? "未填写规格" : plan.specificationString
        return "\(form) · \(specification)"
    }

    private func openExistingPlan(_ plan: UsersMedicinePlanDTO) {
        // 就诊记录中的草稿只能提示已有计划，不能跳转并修改全局用药计划。
        guard !isDraftMode else { return }
        showPlanSuggestions = false
        isMedicineNameFocused = false
        hideKeyboard()
        guard let planId = plan.id else {
            existingPlanForEditing = plan
            return
        }

        BgResultNetWork<MedicinePlanDetailParam, UsersMedicinePlanDTO>.post(
            apiUrl(MEDICINE_PLAN_DETAIL),
            params: MedicinePlanDetailParam(id: planId)
        )
        .complicationHand { (detail: UsersMedicinePlanDTO?) in
            existingPlanForEditing = detail ?? plan
        }
        .responseDecodable()
    }

    /// 新建计划在保存前重新查询，避免输入期间其他端新增同一药品导致漏判。
    private func checkDuplicateBeforeSubmitting() {
        guard !isSubmitting else { return }
        isSubmitting = true
        let params = MedicinePlanListParam(medicineName: medicineName.trimmingCharacters(in: .whitespacesAndNewlines))
        BgResultNetWork<MedicinePlanListParam, [UsersMedicinePlanDTO]>.post(
            apiUrl(MEDICINE_PLAN_LIST),
            params: params
        )
        .complicationHand { (plans: [UsersMedicinePlanDTO]?) in
            let matchedPlans = plans ?? []
            planSuggestions = matchedPlans
            isSubmitting = false
            if let duplicate = matchedPlans.first(where: isExactDuplicate) {
                duplicatePlanForConfirmation = duplicate
                showsDuplicateConfirmation = true
            } else {
                savePlan()
            }
        }
        .errorHandle { _, _ in
            isSubmitting = false
        }
        .responseDecodable()
    }

    /// 删除当前编辑的计划；删除成功后由父视图刷新列表。
    private func deletePlan() {
        guard !isDeleting, let planId = editingPlan?.id else { return }
        isDeleting = true

        BgResultNetWork<MedicinePlanDetailParam, Int>.post(
            apiUrl(MEDICINE_PLAN_DELETE),
            params: MedicinePlanDetailParam(id: planId)
        )
        .errorHandle { _, _ in
            isDeleting = false
        }
        .complicationHand { (_: Int?) in
            onDeleted()
            dismiss()
        }
        .responseDecodable()
    }

    /// 根据当前模式保存表单；就诊记录内使用时仅回传草稿，新增计划才会进行重复校验。
    private func submitPlan() {
        guard !isSubmitting else { return }
        if isDraftMode {
            saveDraft()
        } else if editingPlan == nil {
            checkDuplicateBeforeSubmitting()
        } else {
            savePlan()
        }
    }

    private func makePlan() -> UsersMedicinePlanDTO {
        UsersMedicinePlanDTO(
            id: editingPlan?.id,
            medicineName: medicineName.trimmingCharacters(in: .whitespacesAndNewlines),
            medicineForm: selectedForm,
            specification: specification.trimmingCharacters(in: .whitespacesAndNewlines),
            specificationUnit: specificationUnit,
            frequencyType: frequencyType.rawValue,
            takingInfo: takingInfoForCurrentSchedule,
            startDate: DateUtils.formatDate(startDate, format: DateUtils.DateFormat.ymd),
            endDate: isLongTerm ? nil : DateUtils.formatDate(endDate, format: DateUtils.DateFormat.ymd),
            sourceType: sourceType,
            medicalAdvice: medicalAdvice.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    /// 将用药计划暂存到父级表单；最终由父级与就诊记录一起保存。
    private func saveDraft() {
        onDraftSaved?(makePlan())
        dismiss()
    }

    private func savePlan() {
        guard !isSubmitting else { return }
        isSubmitting = true

        let plan = makePlan()

        if editingPlan != nil {
            BgResultNetWork<UsersMedicinePlanDTO, Int>.post(
                apiUrl(MEDICINE_PLAN_UPDATE),
                params: plan
            )
            .errorHandle { _, _ in
                isSubmitting = false
            }
            .complicationHand { (_: Int?) in
                onSaved(plan)
                dismiss()
            }
            .responseDecodable()
        } else {
            BgResultNetWork<UsersMedicinePlanDTO, String>.post(
                apiUrl(MEDICINE_PLAN_ADD),
                params: plan
            )
            .errorHandle { _, _ in
                isSubmitting = false
            }
            .complicationHand { planId in
                var savedPlan = plan
                savedPlan.id = planId
                onSaved(savedPlan)
                dismiss()
            }
            .responseDecodable()
        }
    }

    private func weeklyPayload(for key: String) -> [DoseTime]? {
        guard let times = weeklyDoseTimes[key], !times.isEmpty else {
            return nil
        }
        return doseTimesPayload(from: times)
    }

    private func doseTimesPayload(from times: [PlanDoseTime]) -> [DoseTime] {
        times.map {
            DoseTime(
                time: DateUtils.formatDate($0.time, format: DateUtils.DateFormat.hm),
                doseUnit: $0.unit,
                doseAmount: Double($0.amount) ?? 0
            )
        }
    }

    private func weeklyDoseTimesBinding(for key: String) -> Binding<[PlanDoseTime]> {
        Binding(
            get: { weeklyDoseTimes[key] ?? [] },
            set: { newTimes in
                if newTimes.isEmpty {
                    weeklyDoseTimes.removeValue(forKey: key)
                } else {
                    weeklyDoseTimes[key] = newTimes
                }
            }
        )
    }

    private func compactDoseUnitLabel(_ unit: String) -> some View {
        HStack(spacing: 3) {
            Text(unit)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
        }
        .foregroundStyle(Color("text_primary"))
        .inputFieldStyle()
    }

    private func makeDoseTime(at index: Int) -> PlanDoseTime {
        var doseTime = PlanDoseTime(time: PlanDoseTime.suggestedTime(at: index))
        if let defaultDoseUnit {
            doseTime.unit = defaultDoseUnit
        }
        return doseTime
    }

    private func applyDefaultDoseUnit() {
        guard let defaultDoseUnit else { return }
        commonDoseTimes = commonDoseTimes.map { doseTime in
            var updatedDoseTime = doseTime
            updatedDoseTime.unit = defaultDoseUnit
            return updatedDoseTime
        }
        weeklyDoseTimes = weeklyDoseTimes.mapValues { times in
            times.map { doseTime in
                var updatedDoseTime = doseTime
                updatedDoseTime.unit = defaultDoseUnit
                return updatedDoseTime
            }
        }
    }
}

// MARK: - 本地表单辅助类型
private struct WeeklyDay: Identifiable {
    let key: String
    let label: String

    var id: String { key }
}

private struct PlanDoseTime: Identifiable {
    private static let suggestedHours = [8, 12, 15, 20, 22, 23]

    let id = UUID()
    var time: Date
    var amount: String
    var unit: String

    init(time: Date = PlanDoseTime.suggestedTime(at: 0), amount: String = "1", unit: String = "片") {
        self.time = time
        self.amount = amount
        self.unit = unit
    }

    /// 根据当前时间条数生成建议时间：08:00、12:00、15:00、20:00、22:00、23:00。
    static func suggestedTime(at index: Int) -> Date {
        let hour = suggestedHours[min(index, suggestedHours.count - 1)]
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
    }
}

private struct PlanActionButtonStyle: ButtonStyle {
    let isPrimary: Bool
    let enabled: Bool
    @ObservedObject private var config = AppGlassConfig.shared

    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(isPrimary ? Color.white : Color("text_primary"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        let styled: AnyView
        if config.enabled {
            if isPrimary {
                styled = AnyView(
                    label.glassEffect(
                        Glass.regular.interactive().tint(enabled ? Color.theme(.primary) : Color.gray.opacity(0.4)),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                )
            } else {
                styled = AnyView(
                    label.glassEffect(
                        Glass.clear.interactive().tint(AppColor.content.opacity(0.6)),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                )
            }
        } else {
            styled = AnyView(
                label.background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isPrimary ? (enabled ? Color.theme(.primary) : Color.gray.opacity(0.4)) : Color("content_bg"))
                )
                .overlay {
                    if !isPrimary {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color("text_secondary").opacity(0.2), lineWidth: 1)
                    }
                }
            )
        }

        return styled
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

private extension View {
    func formTextFieldStyle() -> some View {
        padding(12)
            .appGlass(.regular.interactive().tint(AppColor.content.opacity(0.5)), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    func formLabelStyle() -> some View {
        font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color("text_secondary"))
    }

    func hintTextStyle() -> some View {
        font(.system(size: 12))
            .foregroundStyle(Color("text_secondary"))
    }
}

#Preview {
    AddMedicinePlanView(valueScopes: .constant([
        "medicineForm": ValueScopeInfo(
            code: "medicineForm",
            desc: "药品类型",
            valueScope: [ValueScopeItem(value: "2", desc: "药片")]
        ),
        "medicineSpecificationUnit": ValueScopeInfo(
            code: "medicineSpecificationUnit",
            desc: "规格单位",
            valueScope: [ValueScopeItem(value: "mg", desc: "毫克（mg）")]
        ),
        "medicineFrequencyType": ValueScopeInfo(
            code: "medicineFrequencyType",
            desc: "用药频率单位",
            valueScope: MedicineFrequencyType.allCases.map {
                ValueScopeItem(value: String($0.rawValue), desc: "频次")
            }
        ),
        "medicinePlanSourceType": ValueScopeInfo(
            code: "medicinePlanSourceType",
            desc: "用药计划来源",
            valueScope: MedicineSourceType.allCases.map {
                ValueScopeItem(value: String($0.rawValue), desc: $0.displayName)
            }
        )
    ]), medicineFormUnits: .constant([
        "药片": ["片"]
    ])) { _ in }
}
