//
//  高血压健康指标详情页面
//  BloodPressureIndicatorDetail.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/12/5.
//

import SwiftUI

struct BloodPressureIndicatorDetail: View {
    var code : String
    var indicatorName : String
    var lastedValue : String
    var unit: String?
    var resultType: Int32?
    @ObservedObject var config:UsersHealthIndicatorConfigurationInfo;
    // 点数据 - 收缩压
    @State private var systolicPointDatas:[ScrollChartDataPoint] = []
    // 点数据 - 舒张压
    @State private var diastolicPointDatas:[ScrollChartDataPoint] = []
    // 记录数据
    @State private var records: [UsersHealthIndicatorDTO] = []
    // 开始时间
    @State private var startDate:Date = Date();
    // 结束时间
    @State private var endDate:Date = Date();
    // 值域名
    @State private var valueScope:[String: ValueScopeInfo] = [:]
    // 显示添加页面
    @State private var showAddSheet = false;
    // 分页相关
    @State private var currentPage: Int16 = 1
    @State private var pageSize: Int16 = 20
    @State private var total: Int64 = 0
    @State private var isLoadingMore: Bool = false
    @State private var hasMoreData: Bool = true
    
    
    init(code: String, indicatorName: String, lastedValue:String, unit: String? = nil, resultType: Int32? = nil, config: UsersHealthIndicatorConfigurationInfo) {
        self.code = code
        self.indicatorName = indicatorName
        self.lastedValue = lastedValue
        self.unit = unit
        self.resultType = resultType
        self.config = config
    }
    
    var multiChartStyle: MultiScrollChartStyle {
        var style = MultiScrollChartStyle()
        style.showXAxis = false
        style.xAxisMinSpace = 0
        style.maxValue = config.maxValue
        style.minValue = config.minValue
        return style
    }
    
    var body: some View {
        VStack(spacing: 15) {
            HStack(alignment: .top) {
                // Header Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: getHealthIndicatorIcon(code).iconName)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color.theme(.primary))
                            .frame(width: 28, height: 28)
                            .appGlass(.clear.tint(Color.theme(.primary).opacity(0.15)),
                                      in: RoundedRectangle(cornerRadius: 8, style: .continuous)) {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.theme(.primary).opacity(0.1))
                            }

                        Text("血压")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color.theme(.primary))
                    }
                    if let unitStr = unit {
                        Text("单位: \(unitStr)")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Add Button
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.theme(.primary))
                        .frame(width: 32, height: 32)
                }
                .appGlass(.regular.interactive(), in: Circle()) {
                    Circle().fill(AppColor.content.opacity(0.6))
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

            }
            VStack {
                // Date Range Selector
                DateRangeSelect(showDateUnit: true, startDate: $startDate, endDate: $endDate, unitCode: $config.dateUnit, color: Color.theme(.primary))
                    .padding(.horizontal, 20)
            }
          
        
            VStack(spacing: 20) {
                // Combined Blood Pressure Chart Section
                VStack(alignment: .leading, spacing: 8) {
                    VStack {
                        MultiScrollChartLine(data: getMultiChartData(), style: multiChartStyle)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                        .fill(AppColor.content)
                )
                .appShadow(AppShadow.card)
                .padding(.horizontal, 20)

                // Records Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("测量记录")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.theme(.primary))

                        Spacer()

                        Text("\(total) 条")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)

                    if records.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.bar")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)

                            Text("暂无记录")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                                .fill(AppColor.content)
                        )
                        .appShadow(AppShadow.card)
                        .padding(.horizontal, 20)
                    } else {
                        VStack(spacing: 8) {
                            List {
                                ForEach(Array(records.enumerated()), id:\.element.id) { index, record in
                                    BloodPressureRecord(
                                        healthIndicator: record,
                                        unit: self.unit,
                                        indicatorDataLabelValueScope: valueScope["indicatorDataLabel"]
                                    )
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button("删除") {
                                            deleteRecord(record)
                                        }.tint(.red)
                                    }
                                    .onAppear {
                                        // 当最后一条记录出现时，触发加载更多
                                        if index == records.count - 1 && hasMoreData && !isLoadingMore {
                                            loadMoreData()
                                        }
                                    }
                                }

                                // 加载中指示器
                                if isLoadingMore {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .tint(Color.theme(.primary))
                                        Spacer()
                                    }
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
                                }
                            }
                            .scrollIndicators(.hidden)
                           .listStyle(PlainListStyle())
                           .refreshable {
                               loadData()
                           }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                                .fill(AppColor.content)
                        )
                        .appShadow(AppShadow.card)
                        .padding(.horizontal, 20)
                    }
                }

                Spacer()

            }
        }
        .sheet(isPresented: $showAddSheet) {
            // 解析最后一次的血压值作为默认值
            let defaultValues = parseDefaultValues()
            BloodPressureAddView(
                systolicDefaultValue: defaultValues.systolic,
                diastolicDefaultValue: defaultValues.diastolic,
                systolicConfig: config,
                diastolicConfig: config,
                systolicStep: config.step,
                diastolicStep: config.step
            ) { _, _ in
                loadData()
            }
        }
        .onAppear {
            initData()
        }
        .onDisappear() {
            resetData()
        }
        .onChange(of: config.dateUnit) { oldValue, newValue in
            initData()
        }
        .onChange(of: startDate) { oldValue, newValue in
            loadData()
        }
    }
    // MARK: - 辅助方法
    
    func resetData() {
        self.records = [];
        self.systolicPointDatas = []
        self.diastolicPointDatas = []
        self.currentPage = 1
        self.hasMoreData = true
        self.isLoadingMore = false
    }
    // 初始化数据
    func initData() {
        let range = DateRangeSelect.calculateRange(for: config.dateUnit, direction: nil, from: Date())
        self.startDate = range?.start ?? self.startDate
        self.endDate = range?.end ?? self.endDate
        DispatchQueue.global(qos: .userInitiated).async {
            let scopes = getValueScopes(codes: ["indicatorDataLabel"])
            DispatchQueue.main.async {
                self.valueScope = scopes
                self.loadData()
            }
        }
    }
    // 加载数据 - 重置分页并加载第一页
    func loadData() {
        self.currentPage = 1
        self.hasMoreData = true
        self.records = []
        self.systolicPointDatas = []
        self.diastolicPointDatas = []
        loadPageData(pageNumber: 1)
    }
    
    // 加载更多数据
    func loadMoreData() {
        guard !isLoadingMore && hasMoreData else { return }
        self.isLoadingMore = true
        loadPageData(pageNumber: currentPage + 1)
    }
    
    // 加载指定页的数据
    func loadPageData(pageNumber: Int16) {
        let startDateStr = DateUtils.formatDate(self.startDate, format: DateUtils.DateFormat.ymdhms)
        let endDateStr = DateUtils.formatDate(self.endDate, format: DateUtils.DateFormat.ymdhms)
        
        // 分别请求收缩压和舒张压数据
        let systolicParams = UsersHealthIndicatorPageParam(
            pageNumber: pageNumber,
            pageSize: pageSize,
            indicatorCode: "systolic",
            startDate: startDateStr,
            endDate: endDateStr
        )
        
        let diastolicParams = UsersHealthIndicatorPageParam(
            pageNumber: pageNumber,
            pageSize: pageSize,
            indicatorCode: "diastolic",
            startDate: startDateStr,
            endDate: endDateStr
        )
        
        // 并行请求两个指标数据
        var systolicData: [UsersHealthIndicatorDTO] = []
        var diastolicData: [UsersHealthIndicatorDTO] = []
        var systolicTotal:Int64 = 0;
        var diastolicTotal:Int64 = 0;
        var systolicHasMore = false
        var diastolicHasMore = false
        var completedRequests = 0
        
        // 请求收缩压数据
        BgResultNetWork<UsersHealthIndicatorPageParam, Page<UsersHealthIndicatorDTO>>.post(apiUrl(HEALTH_INDICATOR_PAGE), params: systolicParams)
        .complicationHand { (pageInfo:Page<UsersHealthIndicatorDTO>?) in
            systolicData = pageInfo?.datas ?? []
            // 判断收缩压是否有更多数据
            systolicHasMore = (pageInfo?.datas.count ?? 0) >= self.pageSize
            completedRequests += 1
            systolicTotal = pageInfo?.total ?? 0;
            if completedRequests == 2 {
                self.processBloodPressureData(systolicData: systolicData, diastolicData: diastolicData, pageNumber: pageNumber, systolicHasMore: systolicHasMore, diastolicHasMore: diastolicHasMore, systolicTotal:systolicTotal, diastolicTotal:diastolicTotal)
            }
        }.responseDecodable()
        
        // 请求舒张压数据
        BgResultNetWork<UsersHealthIndicatorPageParam, Page<UsersHealthIndicatorDTO>>.post(apiUrl(HEALTH_INDICATOR_PAGE), params: diastolicParams)
        .complicationHand { (pageInfo:Page<UsersHealthIndicatorDTO>?) in
            diastolicData = pageInfo?.datas ?? []
            // 判断舒张压是否有更多数据
            diastolicHasMore = (pageInfo?.datas.count ?? 0) >= self.pageSize
            completedRequests += 1
            diastolicTotal = pageInfo?.total ?? 0;
            if completedRequests == 2 {
                self.processBloodPressureData(systolicData: systolicData, diastolicData: diastolicData, pageNumber: pageNumber, systolicHasMore: systolicHasMore, diastolicHasMore: diastolicHasMore, systolicTotal:systolicTotal, diastolicTotal:diastolicTotal)
            }
        }.responseDecodable()
    }
    
    // 处理血压数据 - 匹配和组装
    func processBloodPressureData(systolicData: [UsersHealthIndicatorDTO], diastolicData: [UsersHealthIndicatorDTO], pageNumber: Int16, systolicHasMore: Bool, diastolicHasMore: Bool,systolicTotal:Int64, diastolicTotal:Int64) {
        DispatchQueue.main.async {
            var systolicPointDatasTemp: [ScrollChartDataPoint] = []
            var diastolicPointDatasTemp: [ScrollChartDataPoint] = []
            var recordsTemp: [UsersHealthIndicatorDTO] = []
            
            // 创建一个字典用于快速查找舒张压数据
            // key: "dataSource|measureTime|label|otherLabel"
            var diastolicMap: [String: UsersHealthIndicatorDTO] = [:]
            for diastolic in diastolicData {
                let key = self.createMatchKey(data: diastolic)
                diastolicMap[key] = diastolic
            }
            
            // 遍历收缩压数据，匹配对应的舒张压
            for systolic in systolicData {
                let key = self.createMatchKey(data: systolic)
                
                if let matchedDiastolic = diastolicMap[key] {
                    // 找到匹配的舒张压数据
                    if let systolicValue = systolic.indicatorValue,
                       let diastolicValue = matchedDiastolic.indicatorValue {
                        
                        let systolicDouble = StringUtils.trans2Double(systolicValue) ?? 0
                        let diastolicDouble = StringUtils.trans2Double(diastolicValue) ?? 0
                        
                        let label = self.getLabelByDate(date: systolic.measureTime)
                        systolicPointDatasTemp.insert(ScrollChartDataPoint(label: label, value: systolicDouble), at: 0)
                        diastolicPointDatasTemp.insert(ScrollChartDataPoint(label: label, value: diastolicDouble), at: 0)
                        
                        // 创建组合的血压记录 (格式: "systolic/diastolic")
                        let combinedRecord = systolic
                        combinedRecord.indicatorValue = "\(systolicValue)/\(diastolicValue)"
                        recordsTemp.append(combinedRecord)
                    }
                }
            }
            
            // 如果是第一页，替换数据；否则追加数据
            if pageNumber == 1 {
                self.systolicPointDatas = systolicPointDatasTemp
                self.diastolicPointDatas = diastolicPointDatasTemp
                self.records = recordsTemp
            } else {
                // 追加新数据到图表（图表数据需要按时间顺序）
                self.systolicPointDatas.append(contentsOf: systolicPointDatasTemp)
                self.diastolicPointDatas.append(contentsOf: diastolicPointDatasTemp)
                // 追加记录到列表
                self.records.append(contentsOf: recordsTemp)
            }
            
            // 更新分页状态
            self.currentPage = pageNumber
            self.total = systolicTotal > diastolicTotal ? systolicTotal : diastolicTotal;
            self.hasMoreData = systolicHasMore || diastolicHasMore
            self.isLoadingMore = false
        }
    }
    
    // 创建匹配键 - 用于匹配一组血压数据
    func createMatchKey(data: UsersHealthIndicatorDTO) -> String {
        let dataSource = data.dataSource ?? ""
        let measureTime = data.measureTime.map { DateUtils.formatDate($0, format: DateUtils.DateFormat.ymdhms) } ?? ""
        let label = data.label ?? 0
        let otherLabel = data.otherLabel ?? 0
        
        return "\(dataSource)|\(measureTime)|\(label)|\(otherLabel)"
    }
    // 获取label
    public func getLabelByDate(date:Date?) -> String {
        guard let date_value = date else {
            return ""
        }
        let unitCode = self.config.dateUnit;
        if unitCode == 5 {
            return DateUtils.formatDate(date_value, format: DateUtils.DateFormat.hms);
        } else {
            return DateUtils.formatDate(date_value, format: DateUtils.DateFormat.mmdd);
        }
    }
    // 获取默认值
    public func getDefaultValue() -> String? {
        if lastedValue == "" {
            return nil
        }
        return lastedValue
    }
    
    // 解析默认的血压值
    public func parseDefaultValues() -> (systolic: Double?, diastolic: Double?) {
        if lastedValue.isEmpty {
            return (nil, nil)
        }
        
        let values = lastedValue.split(separator: "/").map(String.init)
        if values.count >= 2 {
            let systolic = Double(values[0])
            let diastolic = Double(values[1])
            return (systolic, diastolic)
        }
        
        return (nil, nil)
    }
    // 获取多线图表数据
    func getMultiChartData() -> MultiScrollChartLineData {
        var points: [MultiScrollChartDataPoint] = []
        
        // 将 systolicPointDatas 和 diastolicPointDatas 转换为 MultiScrollChartDataPoint
        for i in 0..<max(systolicPointDatas.count, diastolicPointDatas.count) {
            let systolicValue = i < systolicPointDatas.count ? systolicPointDatas[i].value : nil
            let diastolicValue = i < diastolicPointDatas.count ? diastolicPointDatas[i].value : nil
            let label = i < systolicPointDatas.count ? systolicPointDatas[i].label : (i < diastolicPointDatas.count ? diastolicPointDatas[i].label : "")
            
            let point = MultiScrollChartDataPoint(label: label, values: [systolicValue, diastolicValue])
            points.append(point)
        }
        
        // 创建两条线的样式
        let systolicLineStyle = MultiScrollChartLineStyle(
            name: "收缩压",
            lineColor: [Color.theme(.primary), .purple],
            lineWidth: 3,
            gradientColors: [Color.theme(.primary).opacity(0.2), Color.theme(.primary).opacity(0.02)],
            pointColor: Color.theme(.primary),
            pointBackgroundColor: .white,
            showPointCircle: false,
            showAverageLine: true
        )
        
        let diastolicLineStyle = MultiScrollChartLineStyle(
            name: "舒张压",
            lineColor: [.blue, .green],
            lineWidth: 3,
            gradientColors: [.blue.opacity(0.2), .blue.opacity(0.02)],
            pointColor: Color.theme(.primary).opacity(0.6),
            pointBackgroundColor: .white,
            showPointCircle: false,
            showAverageLine: true
        )
        
        return MultiScrollChartLineData(points: points, lineStyle: [systolicLineStyle, diastolicLineStyle])
    }
    
    // 删除记录
    func deleteRecord(_ record: UsersHealthIndicatorDTO) {
        guard let recordId = record.id else { return }
        
        BgResultNetWork<[String:String], Int32>.post(apiUrl(HEALTH_INDICATOR_DELETE), params: ["id": recordId])
            .complicationHand { (i:Int32?) in
                DispatchQueue.main.async {
                    self.loadData()
                }
            }.responseDecodable()
        
    }
}

// MARK: - 血压记录卡片
struct BloodPressureRecord : View {
    var healthIndicator:UsersHealthIndicatorDTO
    var unit:String?
    var indicatorDataLabelValueScope:ValueScopeInfo?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                // Left Section - Label and Date
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color.theme(.primary))
                        
                        Text("\(getLabel(healthIndicator.label))")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.theme(.primary))
                    }
                    
                    Text("\(DateUtils.formatDate(healthIndicator.measureTime!, format: DateUtils.DateFormat.ymdhms))")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Right Section - Blood Pressure Values
                VStack(alignment: .trailing, spacing: 4) {
                    // 解析血压值
                    let values = healthIndicator.indicatorValue?.split(separator: "/").map(String.init) ?? []
                    // 测量时间标签
                    if let timeLabel = getDataTimeLabelTemp(healthIndicator.otherLabel) {
                        Text(timeLabel)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .glassPillColor(.clear.interactive(), Color.theme(.primary).opacity(0.18))
                    }
                    HStack(spacing: 6) {
                        HealthIndicatorStatusBadge(indicatorStatus: healthIndicator.indicatorStatus)
                        if values.count >= 2 {
                            // 收缩压
                            HStack(spacing: 2) {
                                Text(values[0])
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Color.theme(.primary))
                                
                                Text("/")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.secondary)
                                
                                // 舒张压
                                Text(values[1])
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Color.theme(.primary))
                            }
                        } else {
                            Text(healthIndicator.indicatorValue ?? "")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color.theme(.primary))
                        }
                        
                        if let unit_str = unit {
                            Text(unit_str)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
        }
        .glassContainer(.clear.interactive(), cornerRadius: AppRadius.medium)
    }
    
    func getLabel(_ label: Int16?) -> String {
        let defaultValue = "来源未知"
        guard let labelReal = label else {
            return defaultValue
        }
        if let valueScopeReal = indicatorDataLabelValueScope {
            // 从有序数组中查找对应的描述
            let labelStr = "\(labelReal)"
            if let item = valueScopeReal.valueScope.first(where: { $0.value == labelStr }) {
                return item.desc
            }
        }
        return defaultValue
    }
    
    func getDataTimeLabelTemp(_ otherLabel: Int16?) -> String? {
        guard let timeLabelValue = otherLabel else {
            return nil
        }
        let a = Int(timeLabelValue)
        return getDataTimeLabel(a)
    }
}

#Preview {
    @Previewable @State var code:String = "bloodPressure";
    @Previewable @State var indicatorName:String = "血压";
    @Previewable @State var unit:String = "mmHg";
    @Previewable @State var resultType:Int32 = 1;
    @Previewable @State var lastedValue:String = "120/80";
    @Previewable @State var config:UsersHealthIndicatorConfigurationInfo = UsersHealthIndicatorConfigurationInfo();
    BloodPressureIndicatorDetail(code: code, indicatorName: indicatorName, lastedValue: lastedValue, unit: unit, resultType: resultType, config: config);
}
