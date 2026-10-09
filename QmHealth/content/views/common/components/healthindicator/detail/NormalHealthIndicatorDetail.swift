//
//  定量-常规的健康指标添加页面
//  NormalHealthIndicatorDetail.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/11/9.
//

import SwiftUI

struct NormalHealthIndicatorDetail: View {
    var code : String
    var indicatorName : String
    var lastedValue : String
    var unit: String?
    var resultType: Int32?
    @ObservedObject var config:UsersHealthIndicatorConfigurationInfo;
    // 点数据
    @State private var pointDatas:[ScrollChartDataPoint] = []
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
    
    var showScrollChartStyle: ScrollChartStyle {
        var style = ScrollChartStyle()
        style.lineColor = [.purple, Color.theme(.primary)]
        style.gradientColors = [Color.theme(.primary).opacity(0.3), Color.theme(.primary).opacity(0.05)]
        style.pointColor = Color.theme(.primary)
        style.lineWidth = 4
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

                        Text(indicatorName)
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
                // Chart Section
                VStack {
                    ScrollChartLine(data: $pointDatas, style: showScrollChartStyle)
                        .frame(height: 240)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
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
                                    HealthIndicatorRecord(
                                        healthIndicator: record,
                                        unit: self.unit,
                                        indicatorDataLabelValueScope: valueScope["indicatorDataLabel"]
                                    )
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0)) // 减少行间距
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
            buildAddView()
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
    
    @ViewBuilder
    private func buildAddView() -> some View {
        if code == "blood_sugar" {
            // 血糖特殊处理
            BloodSugarAddView(
                bloodSugarDefaultValue: getDefaultValue(),
                bloodSugarConfig: config,
                step: config.step
            ) { _ in
                loadData()
            }
        } else {
            // 常规定量指标
            NormalHealthIndicatorAddView(
                indicatorCode: code,
                indicatorName: self.indicatorName,
                unit: self.unit ?? "",
                minValue: config.minValue,
                maxValue: config.maxValue,
                step: config.step,
                defaultValue: getDefaultValue(),
                valueFormate: config.valueFormate
            ) { _ in
                loadData()
            }
        }
    }
    
    func resetData() {
        self.records = [];
        self.pointDatas = []
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
        self.isLoadingMore = false
        self.records = []
        self.pointDatas = []
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
        let params:UsersHealthIndicatorPageParam = UsersHealthIndicatorPageParam (
            pageNumber: pageNumber,
            pageSize: pageSize,
            indicatorCode: self.code,
            startDate: DateUtils.formatDate(self.startDate, format: DateUtils.DateFormat.ymdhms) ,
            endDate: DateUtils.formatDate(self.endDate, format: DateUtils.DateFormat.ymdhms)
        );
        
        BgResultNetWork<UsersHealthIndicatorPageParam, Page<UsersHealthIndicatorDTO>>.post(apiUrl(HEALTH_INDICATOR_PAGE), params: params)
        .complicationHand { (pageInfo:Page<UsersHealthIndicatorDTO>?) in
            DispatchQueue.main.async {
                guard let page = pageInfo else {
                    self.isLoadingMore = false
                    return;
                }
                
                var pointDatasTemp:[ScrollChartDataPoint] = []
                var recordsTemp: [UsersHealthIndicatorDTO] = []
                
                for data in page.datas {
                    if data.indicatorValue != nil {
                        let point = ScrollChartDataPoint(label: getLabelByDate(date: data.measureTime), value: StringUtils.trans2Double(data.indicatorValue) ?? 0)
                        pointDatasTemp.insert(point, at: 0)
                    }
                    recordsTemp.append(data)
                }
                
                // 判断是否有更多数据
                let hasMore = (page.datas.count >= Int(self.pageSize))
                
                // 如果是第一页，替换数据；否则追加数据
                if pageNumber == 1 {
                    self.pointDatas = pointDatasTemp
                    self.records = recordsTemp
                } else {
                    // 追加新数据到图表（图表数据需要按时间顺序）
                    self.pointDatas.append(contentsOf: pointDatasTemp)
                    // 追加记录到列表
                    self.records.append(contentsOf: recordsTemp)
                }
                
                // 更新分页状态
                self.currentPage = pageNumber
                self.hasMoreData = hasMore
                self.total = page.total
                self.isLoadingMore = false
            }
        }.responseDecodable()
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
    public func getDefaultValue() -> Double? {
        if lastedValue == "" {
            return nil
        }
        return Double(lastedValue);
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

struct HealthIndicatorRecord : View {
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
                
                // Right Section - Value
                VStack(alignment: .trailing, spacing: 4) {
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
                        Text("\(healthIndicator.indicatorValue ?? "")")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color.theme(.primary))
                        
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
    @Previewable @State var code:String = "height";
    @Previewable @State var indicatorName:String = "身高";
    @Previewable @State var unit:String = "cm";
    @Previewable @State var resultType:Int32 = 1;
    @Previewable @State var lastedValue:String = "";
    @Previewable @State var config:UsersHealthIndicatorConfigurationInfo = UsersHealthIndicatorConfigurationInfo();
    NormalHealthIndicatorDetail(code: code, indicatorName: indicatorName,lastedValue:lastedValue, unit: unit, resultType: resultType, config: config);
}
