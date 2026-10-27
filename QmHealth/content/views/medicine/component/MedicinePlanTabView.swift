//
//  MedicinePlanTabView.swift
//  QmHealth
//

import SwiftUI

// MARK: - 用药计划子页面
struct MedicinePlanTabView: View {
    @Binding var showAddPlanRecord: Bool
    /// 由页头左侧按钮触发的用药 OCR 识别。
    @Binding var showOcrPlan: Bool

    @State private var plans: [UsersMedicinePlanDTO] = []
    @State private var editingPlan: UsersMedicinePlanDTO?
    @State private var isLoadingPlanDetail = false
    @State private var searchText = ""
    @State private var isLoadingPlans = false
    @State private var statusFilter: PlanStatusFilter = .all
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool
    // 值域数据：medicineForm / medicineSpecificationUnit / medicineFrequencyType / medicinePlanSourceType
    @State private var valueScopes: [String: ValueScopeInfo] = [:]
    // 剂型对应的默认剂量单位，例如：药片 -> ["片"]
    @State private var medicineFormUnits: [String: [String]] = [:]

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            if !plans.isEmpty {
                statusFilterBar
            }

            Group {
                if isLoadingPlans && plans.isEmpty {
                    Spacer()
                    ProgressView("正在加载用药计划…")
                        .tint(Color.theme(.primary))
                    Spacer()
                } else if displayPlans.isEmpty {
                    Spacer()
                    emptyStateView
                    Spacer()
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 14) {
                            ForEach(displayPlans) { plan in
                                MedicinePlanCard(plan: plan, valueScopes: valueScopes) {
                                if let planId = plan.id {
                                    loadPlanDetail(id: planId)
                                }
                            }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                        // 底部占位，避免被导航栏遮挡
                        Color.clear.frame(height: 60)
                    }
                    .refreshable {
                        loadPlans()
                    }
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded {
                isSearchFocused = false
            })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showAddPlanRecord) {
            AddMedicinePlanView(
                valueScopes: $valueScopes,
                medicineFormUnits: $medicineFormUnits
            ) { _ in
                // 以服务端列表为准，确保新计划与动态 takingInfo 均为最新数据。
                loadPlans()
                // 新增计划需要排入对应提醒。
                MedicineReminder.shared.refresh()
            }
        }
        .sheet(item: $editingPlan) { plan in
            AddMedicinePlanView(
                valueScopes: $valueScopes,
                medicineFormUnits: $medicineFormUnits,
                onSaved: { _ in
                    loadPlans()
                    // 计划时间/频次可能已变更，重排提醒。
                    MedicineReminder.shared.refresh()
                },
                editingPlan: plan,
                onDeleted: {
                    loadPlans()
                    MedicineReminder.shared.refresh()
                }
            )
        }
        .sheet(isPresented: $showOcrPlan) {
            MedicineOcrRecognizeView(saveMode: .directPlan) { _ in
                // 组件内已完成保存，这里只刷新列表与提醒。
                loadPlans()
                MedicineReminder.shared.refresh()
            }
        }
        .onAppear {
            loadValueScopes()
            loadMedicineFormUnits()
            loadPlans()
        }
        .onChange(of: searchText) { _, _ in
            schedulePlanSearch()
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    // MARK: - 搜索
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isLoadingPlans ? Color.theme(.primary) : Color("text_secondary"))
                .symbolEffect(.pulse, options: .repeating, isActive: isLoadingPlans)

            TextField("搜索药品名称", text: $searchText)
                .font(.system(size: 14))
                .foregroundStyle(Color("text_primary"))
                .focused($isSearchFocused)
                .submitLabel(.search)
                .onSubmit(loadPlans)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    isSearchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color("text_secondary").opacity(0.58))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .inputFieldStyle()
        .scaleEffect(isSearchFocused ? 1 : 0.985)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .animation(.spring(response: 0.3, dampingFraction: 0.86), value: isSearchFocused)
        .animation(.easeInOut(duration: 0.2), value: searchText.isEmpty)
    }

    /// 用户停止输入后自动执行模糊查询，避免每次键入都产生网络请求。
    private func schedulePlanSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(420))
            guard !Task.isCancelled else { return }
            loadPlans()
        }
    }

    // MARK: - 状态筛选
    private var statusFilterBar: some View {
        GlassPillSegmentedSelector(
            selection: Binding(
                get: { PlanStatusFilter.allCases.firstIndex(of: statusFilter) ?? 0 },
                set: { statusFilter = PlanStatusFilter.allCases[$0] }
            ),
            titles: PlanStatusFilter.allCases.map(\.title)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }

    /// 按状态筛选，并按「使用中 → 未开始 → 已失效」排序；同状态内保持服务端顺序。
    private var displayPlans: [UsersMedicinePlanDTO] {
        plans.enumerated()
            .filter { statusFilter.matches($0.element.planStatus) }
            .sorted { lhs, rhs in
                let lhsRank = lhs.element.planStatus.sortRank
                let rhsRank = rhs.element.planStatus.sortRank
                return lhsRank == rhsRank ? lhs.offset < rhs.offset : lhsRank < rhsRank
            }
            .map(\.element)
    }

    // MARK: - 空状态视图
    private var emptyStateView: some View {
        let isSearching = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return VStack(spacing: 16) {
            Image(systemName: isSearching ? "magnifyingglass" : "list.clipboard")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.theme(.primary).opacity(0.3), Color.theme(.secondary).opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(isSearching ? "未找到匹配的用药计划" : statusFilter.emptyTitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color("text_primary"))

            Text(isSearching ? "请尝试其他药品名称" : statusFilter.emptyHint)
                .font(.system(size: 13))
                .foregroundStyle(Color("text_secondary"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - 加载计划详情并进入编辑
    private func loadPlanDetail(id: String) {
        guard !isLoadingPlanDetail else { return }
        isLoadingPlanDetail = true

        BgResultNetWork<MedicinePlanDetailParam, UsersMedicinePlanDTO>.post(
            apiUrl(MEDICINE_PLAN_DETAIL),
            params: MedicinePlanDetailParam(id: id)
        )
        .complicationHand { (data: UsersMedicinePlanDTO?) in
            isLoadingPlanDetail = false
            if let data {
                editingPlan = data
            }
        }
        .errorHandle { _, _ in
            isLoadingPlanDetail = false
        }
        .responseDecodable()
    }

    // MARK: - 加载计划列表
    private func loadPlans() {
        guard !isLoadingPlans else { return }
        isLoadingPlans = true

        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let params = MedicinePlanListParam(medicineName: keyword)
        BgResultNetWork<MedicinePlanListParam, [UsersMedicinePlanDTO]>.post(
            apiUrl(MEDICINE_PLAN_LIST),
            params: params
        )
        .complicationHand { (data: [UsersMedicinePlanDTO]?) in
            plans = data ?? []
            isLoadingPlans = false
        }
        .errorHandle { _, _ in
            isLoadingPlans = false
        }
        .responseDecodable()
    }

    // MARK: - 加载值域数据
    private func loadValueScopes() {
        guard valueScopes.isEmpty else { return }
        let params = ValueScopeGetParamDTO(codes: [
            "medicineForm",
            "medicineSpecificationUnit",
            "medicineFrequencyType",
            "medicinePlanSourceType"
        ])
        BgResultNetWork<ValueScopeGetParamDTO, [String: ValueScopeInfo]>.post(apiUrl(VALUE_SCOPE_LIST), params: params)
            .complicationHand { (data: [String: ValueScopeInfo]?) in
                if let data = data {
                    valueScopes = data
                }
            }
            .responseDecodable()
    }

    // MARK: - 加载剂型默认剂量单位
    private func loadMedicineFormUnits() {
        guard medicineFormUnits.isEmpty else { return }
        BgResultNetWork<Empty?, [String: [String]]>.post(
            apiUrl(MEDICINE_PLAN_FORM_UNITS),
            params: nil
        )
        .complicationHand { (data: [String: [String]]?) in
            if let data = data {
                medicineFormUnits = data
            }
        }
        .responseDecodable()
    }
}

// MARK: - 计划状态筛选
private enum PlanStatusFilter: CaseIterable {
    case all
    case valid
    case expired

    var title: String {
        switch self {
        case .all: return "全部"
        case .valid: return "有效"
        case .expired: return "已失效"
        }
    }

    /// 「有效」包含使用中与未开始的计划，仅已失效计划归入「已失效」
    func matches(_ status: MedicinePlanStatus) -> Bool {
        switch self {
        case .all: return true
        case .valid: return status != .expired
        case .expired: return status == .expired
        }
    }

    var emptyTitle: String {
        switch self {
        case .all: return "暂无用药计划"
        case .valid: return "暂无有效用药计划"
        case .expired: return "暂无已失效的用药计划"
        }
    }

    var emptyHint: String {
        switch self {
        case .all: return "点击右上角 + 号添加，或点击左上角识别处方"
        case .valid: return "使用中的计划会显示在这里，点击右上角 + 号添加"
        case .expired: return "结束日期早于今天的计划会归入这里"
        }
    }
}

#Preview {
    MedicinePlanTabView(showAddPlanRecord: .constant(false), showOcrPlan: .constant(false))
}
