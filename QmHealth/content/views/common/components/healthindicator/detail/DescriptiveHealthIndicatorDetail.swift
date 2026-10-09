//
//  描述性类型的健康指标详情页面
//  DescriptiveHealthIndicatorDetail.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/12/7.
//

import SwiftUI

struct DescriptiveHealthIndicatorDetail: View {
    var code : String
    var indicatorName : String
    var lastedValue : String
    var unit: String?
    var resultType: Int32?
    @ObservedObject var config:UsersHealthIndicatorConfigurationInfo;
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
                // Records Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("检测记录")
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
                            Image(systemName: "doc.text")
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
                        VStack(spacing: 12) {
                            ForEach(Array(records.enumerated()), id:\.element.id) { index, record in
                                DescriptiveHealthIndicatorRecord(
                                    healthIndicator: record,
                                    indicatorDataLabelValueScope: valueScope["indicatorDataLabel"]
                                )
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
                                .padding(.vertical, 16)
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
            DescriptiveHealthIndicatorAddView(
                indicatorCode: code,
                indicatorName: self.indicatorName,
                defaultText: lastedValue
            ) { _ in
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
        
        let params = UsersHealthIndicatorPageParam(
            pageNumber: pageNumber,
            pageSize: pageSize,
            indicatorCode: code,
            startDate: startDateStr,
            endDate: endDateStr
        )
        
        BgResultNetWork<UsersHealthIndicatorPageParam, Page<UsersHealthIndicatorDTO>>.post(apiUrl(HEALTH_INDICATOR_PAGE), params: params)
        .complicationHand { (pageInfo:Page<UsersHealthIndicatorDTO>?) in
            DispatchQueue.main.async {
                let recordsTemp = pageInfo?.datas ?? []
                let hasMore = (pageInfo?.datas.count ?? 0) >= self.pageSize
                let totalCount = pageInfo?.total ?? 0
                
                // 如果是第一页，替换数据；否则追加数据
                if pageNumber == 1 {
                    self.records = recordsTemp
                } else {
                    self.records.append(contentsOf: recordsTemp)
                }
                
                // 更新分页状态
                self.currentPage = pageNumber
                self.total = totalCount
                self.hasMoreData = hasMore
                self.isLoadingMore = false
            }
        }.responseDecodable()
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

// MARK: - 描述性指标记录卡片
struct DescriptiveHealthIndicatorRecord : View {
    var healthIndicator:UsersHealthIndicatorDTO
    var indicatorDataLabelValueScope:ValueScopeInfo?
    
    @State private var showDeleteConfirm = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header - Label and Date
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color.theme(.primary))
                        
                        Text("\(getLabel(healthIndicator.label))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.theme(.primary))

                        HealthIndicatorStatusBadge(indicatorStatus: healthIndicator.indicatorStatus)
                    }

                    Text("\(DateUtils.formatDate(healthIndicator.measureTime!, format: DateUtils.DateFormat.ymdhms))")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Delete Button
                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            
            // Content - Description Text
            VStack(alignment: .leading, spacing: 0) {
                Text(healthIndicator.indicatorValue ?? "")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color("text_primary"))
                    .lineLimit(nil)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appGlass(.clear.interactive(),
                      in: RoundedRectangle(cornerRadius: 10, style: .continuous)) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColor.content.opacity(0.5))
            }
        }
        .padding(14)
        .glassContainer(.clear.interactive(), cornerRadius: AppRadius.medium)
        .confirmationDialog("删除记录", isPresented: $showDeleteConfirm, actions: {
            Button("删除", role: .destructive) {
                // 删除操作由父视图处理
            }
        }, message: {
            Text("确定要删除这条记录吗？")
        })
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
}

#Preview {
    @Previewable @State var code:String = "diagnosis";
    @Previewable @State var indicatorName:String = "诊断记录";
    @Previewable @State var unit:String? = nil;
    @Previewable @State var resultType:Int32 = 3;
    @Previewable @State var lastedValue:String = "这是一条诊断记录的描述";
    @Previewable @State var config:UsersHealthIndicatorConfigurationInfo = UsersHealthIndicatorConfigurationInfo();
    DescriptiveHealthIndicatorDetail(code: code, indicatorName: indicatorName, lastedValue: lastedValue, unit: unit, resultType: resultType, config: config);
}
