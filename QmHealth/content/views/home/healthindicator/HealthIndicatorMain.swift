//
//  HealthIndicatorMain.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/11/27.
//

import SwiftUI

struct HealthIndicatorMain: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: String = ""
    @State private var searchText: String = ""
    @State private var isLoading = true
    @State private var indicators: [HealthIndicatorInfoDTO] = []
    @State private var selectedIndicatorCode: String = ""
    @State private var selectedIndicatorValue: String = ""
    @State private var showDetailSheet = false
    @State private var showAddSheet = false
    @State private var showSearchPickerSheet = false
    @State private var showCategoryGrid = false
    @State private var showOcrSheet = false
    @State private var categories: [(code: String, name: String)] = []
    @State private var errorMessage: String? = nil
    @State private var bloodPressureData: (systolic: HealthIndicatorInfoDTO?, diastolic: HealthIndicatorInfoDTO?) = (nil, nil)
    
    var body: some View {
        VStack(spacing: 0) {
            // 页面头部
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.theme(.primary))
                        .frame(width: 32, height: 32)
                }
                .appGlass(.regular.interactive(), in: Circle()) {
                    Circle().fill(AppColor.content.opacity(0.6))
                }

                Spacer()

                VStack(spacing: 4) {
                    Text("健康指标")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color("text_primary"))
                }

                Spacer()

                HStack(spacing: 10) {
                    Button(action: {
                        showOcrSheet = true
                    }) {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.theme(.primary))
                            .frame(width: 32, height: 32)
                    }
                    .appGlass(.regular.interactive(), in: Circle()) {
                        Circle().fill(AppColor.content.opacity(0.6))
                    }

                    Button(action: {
                        showAddSheet = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.theme(.primary))
                            .frame(width: 32, height: 32)
                    }
                    .appGlass(.regular.interactive(), in: Circle()) {
                        Circle().fill(AppColor.content.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 16)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // 搜索框 - 点击打开选择
                    Button(action: {
                        showSearchPickerSheet = true
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color("text_secondary"))

                            Text("搜索指标名称或代码")
                                .font(.system(size: 14))
                                .foregroundStyle(Color("text_secondary"))

                            Spacer()
                        }
                    }
                    .inputFieldStyle()
                    .padding(.horizontal, 20)

                    // 分类选择器 - 左侧弹出菜单 + 横向滚动分类
                    HStack(spacing: 10) {
                        Button(action: { showCategoryGrid = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.grid.2x2")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("分类")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(Color.theme(.primary))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                        }
                        .glassPill(.clear.interactive())

                        ScrollViewReader { proxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(categories, id: \.code) { category in
                                        CategoryTab(
                                            name: category.name,
                                            isSelected: selectedCategory == category.code,
                                            action: {
                                                selectedCategory = category.code
                                                loadIndicatorsForCategory(category.code)
                                            }
                                        )
                                        .id(category.code)
                                    }
                                }
                            }
                            .onChange(of: selectedCategory) { _, newCode in
                                withAnimation {
                                    proxy.scrollTo(newCode, anchor: .center)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // 内容区域
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(Color.theme(.primary))
                            Text("加载中...")
                                .font(.system(size: 14))
                                .foregroundStyle(Color("text_secondary"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else if indicators.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundStyle(Color("text_secondary").opacity(0.5))
                            Text("暂无数据")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color("text_primary"))
                            Text("尝试调整搜索条件或分类")
                                .font(.system(size: 12))
                                .foregroundStyle(Color("text_secondary"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {

                        // 指标网格列表 - 2列布局
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                            if selectedCategory == "Anthropometry" {
                                if bloodPressureData.systolic != nil || bloodPressureData.diastolic != nil {
                                    Button(action: {
                                        selectedIndicatorCode = "bloodPressure"
                                        selectedIndicatorValue = ""
                                        showDetailSheet = true
                                    }) {
                                        HealthIndicatorCardBloodPressure (
                                            icon: "heart.fill",
                                            title: "血压",
                                            systolic: bloodPressureData.systolic?.indicatorValue ?? "-",
                                            diastolic: bloodPressureData.diastolic?.indicatorValue ?? "-",
                                            unit: "mmHg",
                                            systolicStatus: HealthStatus.getHealthStatus(indicatorStatus: bloodPressureData.systolic?.indicatorStatus),
                                            diastolicStatus: HealthStatus.getHealthStatus(indicatorStatus: bloodPressureData.diastolic?.indicatorStatus),
                                            color: Color.red,
                                            otherLabel: getDataTimeLabel(bloodPressureData.systolic?.otherLabel),
                                            measureTime: bloodPressureData.systolic?.measureTime,
                                            systolicReferenceRange: bloodPressureData.systolic?.referenceRange,
                                            diastolicReferenceRange: bloodPressureData.diastolic?.referenceRange
                                        )
                                    }
                                    .buttonStyle(CardPressButtonStyle())
                                }
                            }
                            ForEach(indicators, id: \.indicatorCode) { indicator in
                                Button(action: {
                                    selectedIndicatorCode = indicator.indicatorCode ?? ""
                                    selectedIndicatorValue = indicator.indicatorValue ?? ""
                                    showDetailSheet = true
                                }) {
                                    let iconInfo = getHealthIndicatorIcon(indicator.indicatorCode ?? "")
                                    let status = HealthStatus.getHealthStatus(indicatorStatus: indicator.indicatorStatus)
                                    HealthIndicatorCard(
                                        icon: iconInfo.iconName,
                                        title: indicator.indicatorName ?? "",
                                        value: indicator.indicatorValue ?? "-",
                                        unit: indicator.unit ?? "",
                                        status: status,
                                        color: iconInfo.color,
                                        otherLabel: getDataTimeLabel(indicator.otherLabel),
                                        measureTime: indicator.measureTime,
                                        referenceRange: indicator.referenceRange
                                    )
                                }
                                .buttonStyle(CardPressButtonStyle())
                            }

                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .pageBackground()
        .toolbar(.hidden)
        .sheet(isPresented: $showDetailSheet) {
            HealthIndicatorDetail(code: $selectedIndicatorCode, lastedValue: $selectedIndicatorValue)
        }
        .sheet(isPresented: $showAddSheet) {
            HealthIndicatorPickerView(mode: .add)
        }
        .sheet(isPresented: $showSearchPickerSheet) {
            HealthIndicatorPickerView(mode: .detail)
        }
        .sheet(isPresented: $showCategoryGrid) {
            CategoryGridPickerView(
                categories: categories,
                selectedCategory: selectedCategory,
                onSelect: { code in
                    selectedCategory = code
                    loadIndicatorsForCategory(code)
                }
            )
        }
        .sheet(isPresented: $showOcrSheet) {
            OcrRecognizeView()
        }
        .onAppear {
            loadCategories()
        }
    }
    
    private func loadCategories() {
        isLoading = true
        errorMessage = nil
        
        // 请求分类列表
        let param = ValueScopeGetParamDTO(codes: ["indicatorCategory"])
        
        BgResultNetWork<ValueScopeGetParamDTO, [String: ValueScopeInfo]>.post(apiUrl(VALUE_SCOPE_LIST), params: param)
            .complicationHand { (data: [String: ValueScopeInfo]?) in
                if let scopeData = data?["indicatorCategory"] {
                    // 直接使用有序数组，转换为分类数组
                    let categoryArray = scopeData.valueScope.map { item in
                        (code: item.value, name: item.desc)
                    }
                    
                    DispatchQueue.main.async {
                        self.categories = categoryArray
                        // 设置默认选中第一个分类
                        if !categoryArray.isEmpty {
                            self.selectedCategory = categoryArray[0].code
                            self.loadIndicatorsForCategory(categoryArray[0].code)
                        } else {
                            self.isLoading = false
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "获取分类失败"
                    }
                }
            }
            .errorHandle({ _, _ in
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "获取分类失败"
                }
            })
            .finalHandleFunc({ _ in
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            })
            .responseDecodable()
    }
    
    private func loadIndicatorsForCategory(_ categoryCode: String) {
        isLoading = true
        errorMessage = nil
        
        let param = UsersHealthIndicatorLastParam(
            indicatorCodes: [],
            indicatorCategory: categoryCode
        )
        
        BgResultNetWork<UsersHealthIndicatorLastParam, [String: HealthIndicatorInfoDTO]>.post(
            apiUrl(HEALTH_INDICATOR_LAST),
            params: param
        )
        .complicationHand { (data: [String: HealthIndicatorInfoDTO]?) in
            var indicatorsTemp:[HealthIndicatorInfoDTO] = []
            if let indicatorList = data {
                // 转换字典为数组并按指标名称排序，确保顺序一致
                for (_,item) in indicatorList {
                    if item.indicatorCode == "systolic" {
                        bloodPressureData.systolic = item
                        continue
                    }
                    if item.indicatorCode == "diastolic" {
                        bloodPressureData.diastolic = item
                        continue
                    }
                    indicatorsTemp.append(item)
                }
            }
            
            DispatchQueue.main.async {
                self.indicators = indicatorsTemp.sorted { $0.indicatorName ?? "" < $1.indicatorName ?? "" }
            }
        }
        .errorHandle { _, error in
            DispatchQueue.main.async {
                errorMessage = "加载指标数据出错"
            }
        }
        .finalHandleFunc{ _ in
            isLoading = false
        }
        .responseDecodable()
    }
    
    }

// MARK: - 分类选项卡组件
struct CategoryTab: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : Color("text_secondary"))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
        }
        .glassPillColor(.clear.interactive(), isSelected ? Color.theme(.primary) : nil)
    }
}

// MARK: - 分类网格选择器
struct CategoryGridPickerView: View {
    let categories: [(code: String, name: String)]
    let selectedCategory: String
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "选择分类")
                .padding(.bottom, 16)

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(categories, id: \.code) { category in
                        Button(action: {
                            onSelect(category.code)
                            dismiss()
                        }) {
                            Text(category.name)
                                .font(.system(size: 13, weight: selectedCategory == category.code ? .semibold : .regular))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GlassSelectButtonStyle(
                            isSelected: selectedCategory == category.code,
                            tint: Color.theme(.primary),
                            verticalPadding: 10,
                            cornerRadius: 18
                        ))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .sheetAppBackground()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}

#Preview {
    HealthIndicatorMain()
}
