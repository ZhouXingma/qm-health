//
//  AddMedicineRecordView.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/12/8.
//

import SwiftUI

struct AddMedicineRecordView: View {
    @Environment(\.dismiss) var dismiss
    var onSave: (() -> Void)? = nil
    /// 从今日用药计划打开时，用于预填表单并关联保存的计划 ID。
    var todayPlan: TodayMedicinePlanDTO? = nil

    init(todayPlan: TodayMedicinePlanDTO? = nil, onSave: (() -> Void)? = nil) {
        self.todayPlan = todayPlan
        self.onSave = onSave
    }
    
    @State private var selectedDate = Date()
    @State private var medicineId: String? = nil
    @State private var planId: String? = nil
    @State private var medicineName = ""
    @State private var specification = ""
    @State private var specificationUnit = "mg"
    @State private var dosageAmount = ""
    @State private var dosageUnit = "片"
    @State private var remark = ""
    @State private var adverseReactions = ""
    @State private var saving = false
    @State private var historyMedicines: [UsersMedicineDTO] = []
    @State private var loadingHistory = false
    @State private var valueScopes: [String: ValueScopeInfo] = [:]
    
    // 用药计划匹配（药品名称输入时联想）
    @State private var planSuggestions: [UsersMedicinePlanDTO] = []
    @State private var loadingPlanSuggestions = false
    @State private var showPlanSuggestions = false
    @State private var planSearchTask: Task<Void, Never>?
    @FocusState private var isMedicineNameFocused: Bool
    /// 标记 medicineName 是否由代码（选择历史用药/用药计划）赋值，避免 onChange 中的 medicineId 重置逻辑覆盖已选中的值
    @State private var isApplyingMedicineSelection = false
    
    let dosageUnits = ["片", "粒", "颗", "支", "袋", "滴", "喷", "勺","吸","枚","包","次","贴","碗","剂","丸","瓶","ml", "mg", "g", "iu"]
    /// 值域接口尚未返回时的兜底规格单位，避免表单空白。
    private let fallbackSpecificationUnits = ["mg", "g", "ml", "μg", "IU"]
    
    /// 规格单位值域：medicineSpecificationUnit，未加载完成时使用兜底列表。
    private var specificationUnitItems: [ValueScopeItem] {
        let items = valueScopes["medicineSpecificationUnit"]?.valueScope ?? []
        if !items.isEmpty {
            return items
        }
        return fallbackSpecificationUnits.map { ValueScopeItem(value: $0, desc: $0) }
    }
    
    private var specificationUnitDescription: String {
        valueScopes["medicineSpecificationUnit"]?.desc(forValue: specificationUnit) ?? specificationUnit
    }
    
    private var isFormValid: Bool {
        !medicineName.isEmpty && !specification.isEmpty && !dosageAmount.isEmpty
    }
    
    // 从历史用药记录中提取药品名称（去重）
    private var historyMedicineNames: [String] {
        Array(Set(historyMedicines.compactMap { $0.medicineName }.filter { !$0.isEmpty })).sorted()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            SheetHeader(title: "添加用药记录")
                .padding(.bottom, 16)
            
            ZStack {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        // 服药时间
                        timeSection

                        if let planId, !planId.isEmpty {
                            planAssociationSection(planId: planId)
                        }
                        
                        // 药品信息（名称+历史记录）
                        medicineSection
                        
                        // 规格和用量（同一行）
                        specDosageSection
                        
                        // 备注
                        remarkSection
                        
                        // 副作用记录
                        adverseReactionsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 80)
                }
                .simultaneousGesture(
                    TapGesture(count: 1)
                        .onEnded { _ in hideKeyboard() }
                )
                VStack {
                    Spacer()
                    // 操作按钮
                    actionButtons
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("background"))
        .onAppear {
            applyTodayPlanIfNeeded()
            loadHistoryMedicines()
            loadValueScopes()
        }
        .onDisappear {
            planSearchTask?.cancel()
        }
    }

    
    // MARK: - 服药时间
    private var timeSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.theme(.primary))

            Text("服药时间")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color("text_secondary"))

            Spacer()

            DatePicker("", selection: $selectedDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .tint(Color.theme(.primary))
        }.cardStyle()
    }

    // MARK: - 关联用药计划
    private func planAssociationSection(planId: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.theme(.primary))

            VStack(alignment: .leading, spacing: 3) {
                Text("已关联今日用药计划")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                Text("计划 ID：\(planId)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color("text_secondary"))
                    .lineLimit(1)
            }

            Spacer()
        }
        .glassCardStyle()
    }

    // MARK: - 药品信息
    private var medicineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "pills.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.theme(.primary))
                Text("药品名称")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color("text_secondary"))
            }

            TextField("请输入药品名称", text: $medicineName)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color("text_primary"))
                .inputFieldStyle()
                .focused($isMedicineNameFocused)
                .onChange(of: medicineName) { _, newValue in
                    // 通过选择历史用药/用药计划回填时，跳过重置逻辑，避免刚设置的 medicineId 被覆盖
                    if isApplyingMedicineSelection {
                        isApplyingMedicineSelection = false
                        return
                    }
                    // 手动修改药品名称时，若与历史记录不匹配，清空已选中的 medicineId
                    if historyMedicines.first(where: { $0.medicineName == newValue })?.medicineId != medicineId {
                        medicineId = historyMedicines.first(where: { $0.medicineName == newValue })?.medicineId
                    }
                    schedulePlanSearch(for: newValue)
                }
                .onChange(of: isMedicineNameFocused) { _, focused in
                    if !focused {
                        // 失焦后延迟收起联想列表，避免点击建议项时列表先消失导致点击失败
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            showPlanSuggestions = false
                        }
                    }
                }

            // 用药计划匹配联想
            if showPlanSuggestions {
                planSuggestionsView
            }

            // 历史记录
            if loadingHistory {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("加载历史用药...")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("text_secondary"))
                }
                .padding(.vertical, 8)
            } else if !historyMedicineNames.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("历史用药")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color("text_secondary").opacity(0.8))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(historyMedicineNames, id: \.self) { name in
                                historyMedicineChip(name: name)
                            }
                        }
                    }
                }
            }
        }.cardStyle()
    }

    /// 历史用药单选项（玻璃胶囊，选中态主题色 tint）
    private func historyMedicineChip(name: String) -> some View {
        let isSelected = medicineName == name
        return Button(action: { selectHistoryMedicine(name: name) }) {
            Text(name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .white : Color("text_primary"))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Capsule())
                .glassEffect(.regular.interactive().tint(isSelected ? AppColor.primary : Color.clear), in: RoundedRectangle(cornerRadius: 20))
        }
    }
    
    // MARK: - 用药计划匹配联想列表
    private var planSuggestionsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if loadingPlanSuggestions {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("正在匹配用药计划...")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("text_secondary"))
                }
                .padding(10)
            } else if planSuggestions.isEmpty {
                Text("未匹配到用药计划中的药品")
                    .font(.system(size: 12))
                    .foregroundStyle(Color("text_secondary"))
                    .padding(10)
            } else {
                ForEach(Array(planSuggestions.enumerated()), id: \.element.id) { index, plan in
                    Button(action: { selectPlanSuggestion(plan) }) {
                        HStack(spacing: 8) {
                            Image(systemName: "pills.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.theme(.primary))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.medicineName ?? "未知药品")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color("text_primary"))
                                if !plan.specificationString.isEmpty {
                                    Text(plan.specificationString)
                                        .font(.system(size: 11))
                                        .foregroundColor(Color("text_secondary"))
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)

                    if index < planSuggestions.count - 1 {
                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
        }
        .glassContainer(.regular.interactive(), cornerRadius: 10)
    }

    
    // MARK: - 规格和用量（并排等分，各自内部单位靠右对齐）
    private var specDosageSection: some View {
        HStack(alignment: .top, spacing: 10) {
            // 规格
            VStack(alignment: .leading, spacing: 6) {
                Text("规格")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color("text_secondary"))

                HStack(spacing: 6) {
                    TextField("50", text: $specification)
                        .font(.system(size: 15, weight: .medium))
                        .keyboardType(.decimalPad)
                        .foregroundColor(Color("text_primary"))
                        .frame(maxWidth: .infinity)

                    specificationUnitSelector
                }.frame(height: 25)
                    .inputFieldStyle()
            }
            .frame(maxWidth: .infinity)
          

            // 用量
            VStack(alignment: .leading, spacing: 6) {
                Text("用量")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color("text_secondary"))

                HStack(spacing: 6) {
                    TextField("1", text: $dosageAmount)
                        .font(.system(size: 15, weight: .medium))
                        .keyboardType(.decimalPad)
                        .foregroundColor(Color("text_primary"))
                        .frame(maxWidth: .infinity)
                    unitSelector(selectedUnit: $dosageUnit, units: dosageUnits)
                }.frame(height: 25)
                    .inputFieldStyle()
            }
            .frame(maxWidth: .infinity)
        }.cardStyle()
    }
    
    // MARK: - 备注
    private var remarkSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "note.text")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.theme(.primary))

            TextField("备注（选填）", text: $remark)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color("text_primary"))
        }.cardStyle()
    }

    // MARK: - 副作用记录
    private var adverseReactionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color("warning"))
                Text("副作用记录")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color("text_secondary"))
            }

            TextField("请输入副作用记录（选填）", text: $adverseReactions, axis: .vertical)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color("text_primary"))
                .lineLimit(3...6)
                .padding(12)
        }.cardStyle()
    }

    
    // MARK: - 操作按钮
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Text("取消")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                    .frame(maxWidth: .infinity)
            }.buttonStyle(SecondaryActionButtonStyle())

            Button { saveRecord() } label: {
                HStack {
                    if saving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColor.primary))
                    }
                    Text("保存")
                        .font(.system(size: 15, weight: .semibold))
                        
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(AppColor.primary)
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .disabled(!isFormValid || saving)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - 规格单位选择器（基于 medicineSpecificationUnit 值域）
    private var specificationUnitSelector: some View {
        Menu {
            ForEach(specificationUnitItems, id: \.value) { item in
                Button(action: { specificationUnit = item.value }) {
                    HStack {
                        Text(item.desc)
                        if specificationUnit == item.value {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            // 带背景色块，设置最小宽度以容纳最长单位文案（如 "ug/mcg"），更短的单位居中不会显得空
            HStack(spacing: 4) {
                Text(specificationUnitDescription)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(Color.theme(.primary))
            .frame(alignment: .trailing)
        }
    }

    // MARK: - 单位选择器
    @ViewBuilder
    private func unitSelector(selectedUnit: Binding<String>, units: [String]) -> some View {
        Menu {
            ForEach(units, id: \.self) { unit in
                Button(action: { selectedUnit.wrappedValue = unit }) {
                    HStack {
                        Text(unit)
                        if selectedUnit.wrappedValue == unit {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            // 带背景色块，设置最小宽度，短单位居中不显得空
            HStack(spacing: 4) {
                Text(selectedUnit.wrappedValue)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(Color.theme(.primary))
            .frame(alignment: .trailing)
        }
    }
    
    // MARK: - 加载值域数据（规格单位）
    private func loadValueScopes() {
        guard valueScopes.isEmpty else { return }
        let params = ValueScopeGetParamDTO(codes: ["medicineSpecificationUnit"])
        BgResultNetWork<ValueScopeGetParamDTO, [String: ValueScopeInfo]>.post(apiUrl(VALUE_SCOPE_LIST), params: params)
            .complicationHand { (data: [String: ValueScopeInfo]?) in
                if let data = data {
                    valueScopes = data
                }
            }
            .responseDecodable()
    }
    
    // MARK: - 用药计划匹配（药品名称输入联想）
    /// 用户停止输入后自动执行模糊查询，避免每次键入都产生网络请求。
    private func schedulePlanSearch(for keyword: String) {
        planSearchTask?.cancel()
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
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
        loadingPlanSuggestions = true
        showPlanSuggestions = true
        
        let params = MedicinePlanPageParam(medicineName: keyword, pageNumber: 1, pageSize: 10)
        BgResultNetWork<MedicinePlanPageParam, Page<UsersMedicinePlanDTO>>.post(
            apiUrl(MEDICINE_PLAN_PAGE),
            params: params
        )
        .complicationHand { (page: Page<UsersMedicinePlanDTO>?) in
            planSuggestions = page?.datas ?? []
            loadingPlanSuggestions = false
        }
        .errorHandle { (result, error) in
            loadingPlanSuggestions = false
        }
        .responseDecodable()
    }
    
    /// 选择用药计划中的药品，回填药品名称、规格、规格单位及关联的 medicineId
    private func selectPlanSuggestion(_ plan: UsersMedicinePlanDTO) {
        medicineId = plan.id
        let newName = plan.medicineName ?? ""
        // 仅当名称真的发生变化时才需要跳过 onChange 中的重置逻辑，否则 onChange 不会触发，flag 会残留
        if medicineName != newName {
            isApplyingMedicineSelection = true
        }
        medicineName = newName
        specification = plan.specification ?? ""
        if let unit = plan.specificationUnit, !unit.isEmpty {
            specificationUnit = unit
        }
        showPlanSuggestions = false
        isMedicineNameFocused = false
        hideKeyboard()
    }
    
    // MARK: - 加载历史用药
    private func loadHistoryMedicines() {
        guard !loadingHistory else { return }
        loadingHistory = true
        
        // POST 请求，不需要参数
        BgResultNetWork<Empty?, [UsersMedicineDTO]>.post(apiUrl(MEDICINE_TAKE_HISTORY), params: nil)
            .complicationHand { (medicines: [UsersMedicineDTO]?) in
                if let medicines = medicines {
                    historyMedicines = medicines
                }
                loadingHistory = false
            }
            .errorHandle { (result, error) in
                loadingHistory = false
            }
            .responseDecodable()
    }
    
    // MARK: - 选择历史药品
    private func selectHistoryMedicine(name: String) {
        // 仅当名称真的发生变化时才需要跳过 onChange 中的重置逻辑，否则 onChange 不会触发，flag 会残留
        if medicineName != name {
            isApplyingMedicineSelection = true
        }
        medicineName = name
        // 从历史记录中找到最近一次使用该药品的记录，填充规格和用量
        if let lastRecord = historyMedicines
            .filter({ $0.medicineName == name })
            .sorted(by: { ($0.takingTime ?? Date.distantPast) > ($1.takingTime ?? Date.distantPast) })
            .first {
            medicineId = lastRecord.medicineId
            specification = lastRecord.specification ?? ""
            specificationUnit = lastRecord.specificationUnit ?? "mg"
            dosageAmount = lastRecord.dose ?? ""
            dosageUnit = lastRecord.doseUnit ?? "片"
        }
    }
    
    // MARK: - 预填今日用药计划
    private func applyTodayPlanIfNeeded() {
        guard let todayPlan, planId == nil else { return }

        planId = todayPlan.planId
        medicineName = todayPlan.medicineName
        specification = todayPlan.specification ?? ""
        specificationUnit = todayPlan.specificationUnit ?? specificationUnit
        dosageAmount = doseAmountText(todayPlan.doseAmount)
        dosageUnit = todayPlan.doseUnit
        remark = todayPlan.medicalAdvice ?? ""
        selectedDate = dateForToday(time: todayPlan.time)
    }

    private func dateForToday(time: String) -> Date {
        let parts = time.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return Date()
        }
        return Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private func doseAmountText(_ amount: Double) -> String {
        amount == amount.rounded() ? String(Int(amount)) : String(amount)
    }

    // MARK: - 保存记录
    private func saveRecord() {
        guard saving == false else {
            return
        }
        saving = true
        
        // 构建请求参数
        var params = UsersMedicineDTO(
            id: nil,
            userId: nil,
            medicineId: medicineId,
            medicineName: medicineName.isEmpty ? nil : medicineName,
            dose: dosageAmount.isEmpty ? nil : dosageAmount,
            doseUnit: dosageUnit.isEmpty ? nil : dosageUnit,
            specification: specification.isEmpty ? nil : specification,
            specificationUnit: specificationUnit.isEmpty ? nil : specificationUnit,
            remarks: remark.isEmpty ? nil : remark,
            takingTime: selectedDate,
            adverseReactions: adverseReactions.isEmpty ? nil : adverseReactions
        )
        params.planId = planId
        
        // 调用后端接口保存
        BgResultNetWork<UsersMedicineDTO, String>.post(apiUrl(MEDICINE_TAKE_SAVE), params: params)
            .complicationHand { (responseId: String?) in
                saving = false
                onSave?()
                dismiss()
            }
            .errorHandle { (result, error) in
                saving = false
            }
            .responseDecodable()
    }
}

#Preview {
    AddMedicineRecordView()
}
