import SwiftUI

// 指标选择器的模式：详情查看或添加数据
enum HealthIndicatorPickerMode {
    case detail      // 查看详情
    case add         // 添加数据
}

struct HealthIndicatorPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var indicatorGroups: [HealthIndicatorMetaGroup] = []
    @State private var loadError: String? = nil
    @FocusState private var isSearchFocused: Bool
    
    // 模式标记：区分是详情查看还是添加数据
    let mode: HealthIndicatorPickerMode
    
    // 添加指标相关状态
    @State private var showAddSheet: Bool = false
    @State private var showDetailSheet: Bool = false
    @State private var selectedIndicator: HealthIndicatorMetaItem?
    @State private var selectedIndicatorCode: String = ""
    @State private var selectedIndicatorValue: String = ""
    @StateObject private var indicatorConfig = UsersHealthIndicatorConfigurationInfo()
    @StateObject private var systolicConfig = UsersHealthIndicatorConfigurationInfo()
    @StateObject private var diastolicConfig = UsersHealthIndicatorConfigurationInfo()
    @StateObject private var bloodSugarConfig = UsersHealthIndicatorConfigurationInfo()
    @State private var configLoading: Bool = false
    @State private var latestValue: String = ""
    @State private var systolicLatestValue: String = ""
    @State private var diastolicLatestValue: String = ""
    @State private var bloodSugarLatestValue: String = ""
    
    private var filteredGroups: [HealthIndicatorMetaGroup] {
        guard !searchText.isEmpty else { return indicatorGroups }
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if keyword.isEmpty { return indicatorGroups }
        return indicatorGroups.compactMap { group in
            let items = group.indicators.filter { item in
                (item.indicatorName?.localizedCaseInsensitiveContains(keyword) ?? false) ||
                (item.indicatorCode?.localizedCaseInsensitiveContains(keyword) ?? false) ||
                (item.description?.localizedCaseInsensitiveContains(keyword) ?? false)
            }
            return items.isEmpty ? nil : HealthIndicatorMetaGroup(categoryCode: group.categoryCode, categoryName: group.categoryName, indicators: items)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 头部
            SheetHeader(title: "健康指标")
                .padding(.bottom, 16)

            // 搜索框
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color("text_secondary"))

                TextField("搜索指标名称、代码或描述", text: $searchText)
                    .font(.system(size: 14))
                    .foregroundStyle(Color("text_primary"))
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .focused($isSearchFocused)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color("text_secondary"))
                    }
                }
            }
            .inputFieldStyle()
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(Color.theme(.primary))
                    Text("正在加载指标...")
                        .font(.system(size: 14))
                        .foregroundColor(Color("text_secondary"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = loadError {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundColor(Color("text_secondary").opacity(0.6))
                    Text("加载失败")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color("text_primary"))
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(Color("text_secondary"))
                    Button("重新加载") {
                        loadIndicators()
                    }
                    .buttonStyle(PrimaryActionButtonStyle(cornerRadius: 20, verticalPadding: 8))
                    .frame(width: 120)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredGroups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(Color("text_secondary").opacity(0.6))
                    Text("未找到相关指标")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color("text_primary"))
                    Text("尝试更换搜索关键词")
                        .font(.system(size: 13))
                        .foregroundColor(Color("text_secondary"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach(filteredGroups, id: \.categoryCode) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.stack.3d.up.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color.theme(.primary))
                                    Text(group.categoryName)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color("text_primary"))
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.top, 10)

                                VStack(spacing: 0) {
                                    ForEach(group.indicators, id: \.indicatorCode) { item in
                                        Button(action: {
                                            selectedIndicator = item
                                            // 根据模式决定走详情还是添加
                                            if mode == .detail {
                                                selectedIndicatorCode = item.indicatorCode ?? ""
                                                selectedIndicatorValue = ""
                                                showDetailSheet = true
                                            } else {
                                                loadIndicatorConfig(code: item.indicatorCode ?? "")
                                            }
                                        }) {
                                            HStack(alignment: .top, spacing: 10) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    HStack(spacing: 6) {
                                                        Text(item.indicatorName ?? "")
                                                            .font(.system(size: 16, weight: .medium))
                                                            .foregroundColor(Color("text_primary"))
                                                            .lineLimit(1)
                                                        if let unit = item.unit, !unit.isEmpty {
                                                            Text(unit)
                                                                .font(.system(size: 11))
                                                                .foregroundColor(Color("text_secondary"))
                                                        }
                                                    }

                                                    if let desc = item.description, !desc.isEmpty {
                                                        Text(desc)
                                                            .font(.system(size: 12))
                                                            .foregroundColor(Color("text_secondary"))
                                                            .lineLimit(2)
                                                    }

                                                    if let code = item.indicatorCode {
                                                        Text(code)
                                                            .font(.system(size: 11))
                                                            .foregroundColor(Color("text_secondary").opacity(0.8))
                                                    }
                                                }
                                                Spacer()

                                                // resultType 标签
                                                Chip(text: item.resultTypeText, color: item.resultTypeColor)
                                                    .font(.system(size: 12, weight: .medium))
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                        }

                                        if item.indicatorCode != group.indicators.last?.indicatorCode {
                                            Divider()
                                                .padding(.leading, 12)
                                        }
                                    }
                                }
                                .glassContainer(.regular.interactive(), cornerRadius: 14)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
            }
        }
        .sheetAppBackground()
        .sheet(isPresented: $showDetailSheet) {
            HealthIndicatorDetail(code: $selectedIndicatorCode, lastedValue: $selectedIndicatorValue)
        }
        .sheet(isPresented: $showAddSheet) {
            if let indicator = selectedIndicator {
                if indicator.resultType == 0 {
                    DescriptiveHealthIndicatorAddView(
                        indicatorCode: indicator.indicatorCode ?? "",
                        indicatorName: indicator.indicatorName ?? "",
                        defaultText: latestValue
                    ) { _ in
                        dismiss()
                    }
                } else if indicator.resultType == 1 {
                    QualitativeHealthIndicatorAddView(
                        indicatorCode: indicator.indicatorCode ?? "",
                        indicatorName: indicator.indicatorName ?? "",
                        valueScope: indicatorConfig.valueScope,
                        defaultValue: latestValue
                    ) { _ in
                        dismiss()
                    }
                } else if indicator.resultType == 2 {
                    // 血压特殊处理
                    if indicator.indicatorCode == "systolic" || indicator.indicatorCode == "diastolic" {
                        BloodPressureAddView(
                            systolicDefaultValue: Double(systolicLatestValue) ?? 120,
                            diastolicDefaultValue: Double(diastolicLatestValue) ?? 80,
                            systolicConfig: systolicConfig,
                            diastolicConfig: diastolicConfig,
                            systolicStep: systolicConfig.step,
                            diastolicStep: diastolicConfig.step
                        ) { _, _ in
                            dismiss()
                        }
                    } else if indicator.indicatorCode == "blood_sugar" {
                        // 血糖特殊处理
                        BloodSugarAddView(
                            bloodSugarDefaultValue: Double(bloodSugarLatestValue) ?? 100,
                            bloodSugarConfig: bloodSugarConfig,
                            step: bloodSugarConfig.step
                        ) { _ in
                            dismiss()
                        }
                    } else if indicatorConfig.addModel == "normal" {
                        // 常规定量指标
                        NormalHealthIndicatorAddView(
                            indicatorCode: indicator.indicatorCode ?? "",
                            indicatorName: indicator.indicatorName ?? "",
                            unit: indicator.unit ?? "",
                            minValue: indicatorConfig.minValue,
                            maxValue: indicatorConfig.maxValue,
                            step: indicatorConfig.step,
                            defaultValue: Double(latestValue) ?? indicatorConfig.minValue,
                            valueFormate: indicatorConfig.valueFormate
                        ) { _ in
                            dismiss()
                        }
                    }
                }
            }
        }
        .onAppear {
            if indicatorGroups.isEmpty {
                loadIndicators()
            }
            // 延迟聚焦搜索框，确保视图已完全加载
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isSearchFocused = true
            }
        }
    }
    
    @ViewBuilder
    private func buildDetailView(for indicator: HealthIndicatorMetaItem) -> some View {
        // 根据指标类型返回相应的详情页面
        // resultType: 0=描述性, 1=定性, 2=定量
        if indicator.resultType == 0 {
            // 描述性指标详情页
            Text("描述性指标详情: \(indicator.indicatorName ?? "")")
        } else if indicator.resultType == 1 {
            // 定性指标详情页
            Text("定性指标详情: \(indicator.indicatorName ?? "")")
        } else if indicator.resultType == 2 {
            // 定量指标详情页
            Text("定量指标详情: \(indicator.indicatorName ?? "")")
        }
    }
    
    private func loadIndicators() {
        isLoading = true
        loadError = nil
        
        let url = apiUrl(HEALTH_INDICATOR_META_LIST)
        BgResultNetWork<Empty?, [HealthIndicatorMetaGroup]>.post(url)
            .complicationHand { data in
                indicatorGroups = data ?? []
            }
            .errorHandle { _, error in
                switch error {
                case .timeout(_, let message),
                     .network(_, let message),
                     .parameter(_, let message),
                     .parsing(_, let message),
                     .http(_, let message),
                     .validation(_, let message),
                     .requestError(_, let message),
                     .unknown(_, let message):
                    loadError = message
                }
            }
            .finalHandleFunc { _ in
                isLoading = false
            }
            .responseDecodable()
    }
    
    private func loadIndicatorConfig(code: String) {
        configLoading = true
        
        // 血压特殊处理：同时加载收缩压和舒张压的配置
        if code == "systolic" || code == "diastolic" {
            loadBloodPressureConfig()
        } else if code == "blood_sugar" {
            // 血糖特殊处理
            loadBloodSugarConfig()
        } else {
            let params = ["indicatorCode": code]
            
            BgResultNetWork<[String: String], UsersHealthIndicatorConfigurationDTO>.post(apiUrl(HEALTH_INFICATOR_CONFIG), params: params)
                .complicationHand { (configOption: UsersHealthIndicatorConfigurationDTO?) in
                    DispatchQueue.main.async {
                        if let configInfo = configOption, let config = configInfo.config {
                            indicatorConfig.from(dto: config)
                        }
                        configLoading = false
                    }
                }
                .errorHandle { _, error in
                    configLoading = false
                }
                .responseDecodable()
        }
        
        // 获取最新的指标数值
        loadLatestIndicatorValue(code: code)
    }
    
    private func loadBloodPressureConfig() {
        // 加载收缩压配置
        let systolicParams = ["indicatorCode": "systolic"]
        BgResultNetWork<[String: String], UsersHealthIndicatorConfigurationDTO>.post(apiUrl(HEALTH_INFICATOR_CONFIG), params: systolicParams)
            .complicationHand { (configOption: UsersHealthIndicatorConfigurationDTO?) in
                DispatchQueue.main.async {
                    if let configInfo = configOption, let config = configInfo.config {
                        systolicConfig.from(dto: config)
                    }
                }
            }
            .responseDecodable()
        
        // 加载舒张压配置
        let diastolicParams = ["indicatorCode": "diastolic"]
        BgResultNetWork<[String: String], UsersHealthIndicatorConfigurationDTO>.post(apiUrl(HEALTH_INFICATOR_CONFIG), params: diastolicParams)
            .complicationHand { (configOption: UsersHealthIndicatorConfigurationDTO?) in
                DispatchQueue.main.async {
                    if let configInfo = configOption, let config = configInfo.config {
                        diastolicConfig.from(dto: config)
                    }
                    configLoading = false
                }
            }
            .responseDecodable()
    }
    
    private func loadBloodSugarConfig() {
        // 加载血糖配置
        let bloodSugarParams = ["indicatorCode": "blood_sugar"]
        BgResultNetWork<[String: String], UsersHealthIndicatorConfigurationDTO>.post(apiUrl(HEALTH_INFICATOR_CONFIG), params: bloodSugarParams)
            .complicationHand { (configOption: UsersHealthIndicatorConfigurationDTO?) in
                DispatchQueue.main.async {
                    if let configInfo = configOption, let config = configInfo.config {
                        bloodSugarConfig.from(dto: config)
                    }
                    configLoading = false
                }
            }
            .responseDecodable()
    }
    
    private func loadLatestIndicatorValue(code: String) {
        // 血压特殊处理：同时获取收缩压和舒张压
        if code == "systolic" || code == "diastolic" {
            let params = UsersHealthIndicatorLastParam(indicatorCodes: ["systolic", "diastolic"])
            
            BgResultNetWork<UsersHealthIndicatorLastParam, [String: HealthIndicatorInfoDTO]>.post(apiUrl(HEALTH_INDICATOR_LAST), params: params)
                .complicationHand { (data: [String: HealthIndicatorInfoDTO]?) in
                    DispatchQueue.main.async {
                        if let indicators = data {
                            systolicLatestValue = indicators["systolic"]?.indicatorValue ?? ""
                            diastolicLatestValue = indicators["diastolic"]?.indicatorValue ?? ""
                        }
                        showAddSheet = true
                    }
                }
                .errorHandle { _, error in
                    DispatchQueue.main.async {
                        showAddSheet = true
                    }
                }
                .responseDecodable()
        } else if code == "blood_sugar" {
            // 血糖特殊处理
            let params = UsersHealthIndicatorLastParam(indicatorCodes: ["blood_sugar"])
            
            BgResultNetWork<UsersHealthIndicatorLastParam, [String: HealthIndicatorInfoDTO]>.post(apiUrl(HEALTH_INDICATOR_LAST), params: params)
                .complicationHand { (data: [String: HealthIndicatorInfoDTO]?) in
                    DispatchQueue.main.async {
                        if let indicators = data, let indicator = indicators["blood_sugar"] {
                            bloodSugarLatestValue = indicator.indicatorValue ?? ""
                        } else {
                            bloodSugarLatestValue = ""
                        }
                        showAddSheet = true
                    }
                }
                .errorHandle { _, error in
                    DispatchQueue.main.async {
                        showAddSheet = true
                    }
                }
                .responseDecodable()
        } else {
            // 常规指标
            let params = UsersHealthIndicatorLastParam(indicatorCodes: [code])
            
            BgResultNetWork<UsersHealthIndicatorLastParam, [String: HealthIndicatorInfoDTO]>.post(apiUrl(HEALTH_INDICATOR_LAST), params: params)
                .complicationHand { (data: [String: HealthIndicatorInfoDTO]?) in
                    DispatchQueue.main.async {
                        if let indicators = data, let indicator = indicators[code] {
                            latestValue = indicator.indicatorValue ?? ""
                        } else {
                            latestValue = ""
                        }
                        showAddSheet = true
                    }
                }
                .errorHandle { _, error in
                    DispatchQueue.main.async {
                        showAddSheet = true
                    }
                }
                .responseDecodable()
        }
    }
}


#Preview {
    HealthIndicatorPickerView(mode: .add)
}
