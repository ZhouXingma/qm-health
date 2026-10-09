//
//  DiseaseListView.swift
//  QmHealth
//  疾病列表管理页面
//
//  Created by 周荥马 on 2025/10/2.
//

import SwiftUI

struct DiseaseListView: View {
    @Binding var showingDiseaseDetail:Bool
    @State private var selectedDisease: DiseaseInfo?
    @State private var searchText = ""
    @State private var selectedSeverities: Set<Int64> = []
    @State private var selectedStatuses: Set<Int64> = []
    @State private var showingFilters = false
    @State private var diseaseInfos:[DiseaseInfo] = []
    
    // 分页相关
    @State private var currentPage: Int = 1
    @State private var pageSize: Int = 20
    @State private var total: Int64 = 0
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasMore = true
    

    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索和过滤栏
            VStack(spacing: 12) {
                searchContentOfBar
                
                searchContentOfFilter
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color("background"))
            // 疾病列表
            if diseaseInfos.isEmpty && !isLoading {
                emptyStateView
            } else {
                diseaseListSection
            }
        }.onAppear() {
            initData()
        }
        .onChange(of: showingDiseaseDetail, { oldValue, newValue in
            if newValue == false {
                self.selectedDisease = nil
            }
        })
        .onChange(of: searchText) { oldValue, newValue in
            resetAndLoadDiseases()
        }
        .onChange(of: selectedStatuses) { oldValue, newValue in
            resetAndLoadDiseases()
        }
        .onChange(of: selectedSeverities) { oldValue, newValue in
            resetAndLoadDiseases()
        }
        .sheet(isPresented: $showingDiseaseDetail) {
            DiseaseDetailEditView(
                diseaseInfo: $selectedDisease,
                onUpdate: {
                    resetAndLoadDiseases()
                }
            )
        }
        .sheet(isPresented: $showingFilters) {
            FilterView(
                selectedSeverities: $selectedSeverities,
                selectedStatuses: $selectedStatuses,
                onApply: {
                    resetAndLoadDiseases()
                }
            )
        }
    }
    
    // MARK: - 搜索和过滤区域
    private var searchContentOfBar: some View {
        // 搜索框
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color("text_secondary"))
            
            TextField("搜索疾病、医生或医院", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color("text_secondary"))
                }
            }
        }
        .inputFieldStyle()
    }
    
    private var filterCount: Int {
        selectedSeverities.count + selectedStatuses.count
    }

    private var searchContentOfFilter : some View {
        // 过滤按钮
        HStack {
            Button(action: {
                showingFilters = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text("筛选")
                    if filterCount > 0 {
                        Text("\(filterCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Circle().fill(Color("error")))
                    }
                }
                .font(.system(size: 14))
                .foregroundStyle(filterCount > 0 ? .white : Color("text_primary"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassPillColor(.regular.interactive(), filterCount > 0 ? Color.theme(.primary) : nil)
            }
            
            Spacer()
            
            // 快速过滤标签 - 显示状态
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DiseaseStatus.allCases, id: \.self) { status in
                        FilterTag(
                            title: status.displayName,
                            isSelected: selectedStatuses.contains(status.rawValue),
                            color: Color(status.color)
                        ) {
                            if selectedStatuses.contains(status.rawValue) {
                                selectedStatuses.remove(status.rawValue)
                            } else {
                                selectedStatuses.insert(status.rawValue)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    

    // MARK: - 辅助视图
    // 疾病列表区域
    private var diseaseListSection: some View {
        ZStack {
            List {
                ForEach(diseaseInfos, id:\.self.id) { disease in
                    DiseaseListRow(
                        disease: disease,
                        onTap: {
                            selectedDisease = disease
                            showingDiseaseDetail = true
                        }
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .onAppear {
                        // 当接近列表底部时加载更多
                        if disease.id == diseaseInfos.last?.id && hasMore && !isLoadingMore {
                            loadMoreDiseases()
                        }
                    }
                }
                
                // 加载更多指示器
                if isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(PlainListStyle())
            .refreshable {
                resetAndLoadDiseases()
            }
            
            if isLoading && diseaseInfos.isEmpty {
                ProgressView()
            }
        }
    }
    
    // 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color("text_secondary"))
            
            Text(!searchText.isEmpty || !selectedSeverities.isEmpty || !selectedStatuses.isEmpty ? "未找到相关疾病" : "暂无疾病记录")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color("text_primary"))
            
            Text(!searchText.isEmpty || !selectedSeverities.isEmpty || !selectedStatuses.isEmpty ? "尝试调整搜索条件" : "点击右上角 + 号添加疾病信息")
                .font(.system(size: 14))
                .foregroundStyle(Color("text_secondary"))
                .multilineTextAlignment(.center)
            
            if searchText.isEmpty && selectedSeverities.isEmpty && selectedStatuses.isEmpty {
                Button("添加疾病") {
                    selectedDisease = nil
                    showingDiseaseDetail = true
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.theme(.primary))
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
    
    // MARK: - 辅助方法
    // 初始化信息
    private func initData() {
        resetAndLoadDiseases()
    }
    
    // 重置分页并加载数据
    private func resetAndLoadDiseases() {
        currentPage = 1
        diseaseInfos = []
        hasMore = true
        loadDiseases()
    }
    
    // 加载疾病信息
    private func loadDiseases() {
        isLoading = true
        let severityArray = selectedSeverities.isEmpty ? nil : Array(selectedSeverities)
        let statusArray = selectedStatuses.isEmpty ? nil : Array(selectedStatuses)
        let params = DiseasePageParam(
            pageNumber: currentPage,
            pageSize: pageSize,
            severities: severityArray,
            statuses: statusArray,
            name: searchText.isEmpty ? nil : searchText
        )
        
        // Debug: Print JSON representation
        if let jsonData = try? JSONEncoder().encode(params),
           let jsonString = String(data: jsonData, encoding: .utf8) {
        }
        
        BgResultNetWork<DiseasePageParam, Page<DiseaseInfo>>.post(apiUrl(DISEASE_PAGE), params: params)
            .complicationHand { (pageInfo:Page<DiseaseInfo>?) in
                isLoading = false
                if let page = pageInfo {
                    if currentPage == 1 {
                        self.diseaseInfos = page.datas
                    } else {
                        self.diseaseInfos.append(contentsOf: page.datas)
                    }
                    self.total = page.total
                    self.hasMore = Int64(self.currentPage * self.pageSize) < page.total
                    print("✅ Loaded \(page.datas.count) diseases, total: \(page.total)")
                } else {
                    if currentPage == 1 {
                        self.diseaseInfos = []
                    }
                    self.hasMore = false
                    print("❌ Failed to load diseases")
                }
            }.responseDecodable()
    }
    
    // 加载更多数据
    private func loadMoreDiseases() {
        guard !isLoadingMore && hasMore else { return }
        isLoadingMore = true
        currentPage += 1
        
        let severityArray = selectedSeverities.isEmpty ? nil : Array(selectedSeverities)
        let statusArray = selectedStatuses.isEmpty ? nil : Array(selectedStatuses)
        let params = DiseasePageParam(
            pageNumber: currentPage,
            pageSize: pageSize,
            severities: severityArray,
            statuses: statusArray,
            name: searchText.isEmpty ? nil : searchText
        )
        
        BgResultNetWork<DiseasePageParam, Page<DiseaseInfo>>.post(apiUrl(DISEASE_PAGE), params: params)
            .complicationHand { (pageInfo:Page<DiseaseInfo>?) in
                isLoadingMore = false
                if let page = pageInfo {
                    self.diseaseInfos.append(contentsOf: page.datas)
                    self.total = page.total
                    self.hasMore = Int64(self.currentPage * self.pageSize) < page.total
                } else {
                    self.hasMore = false
                }
            }.responseDecodable()
    }
    
}

// MARK: - 子组件
struct DiseaseListRow: View {
    let disease: DiseaseInfo
    let onTap: () -> Void
    
    var body: some View {
        let diseaseSeverity = DiseaseSeverity.getByCode(code: disease.severity ?? 1) ?? DiseaseSeverity.mild;
        let diseaseStatus = DiseaseStatus.getByCode(code: disease.status ?? 1) ?? DiseaseStatus.stable;
        
        Button {
            onTap()
        } label: {
            VStack(spacing: 12) {
                // 头部信息
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(disease.name ?? "")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color("text_primary"))
                        
                        if let firstVisitTime = disease.firstVisitTime {
                            Text("首诊：\(firstVisitTime)")
                                .font(.system(size: 12))
                                .foregroundStyle(Color("text_secondary"))
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        // 严重程度标签
                        HStack(spacing: 4) {
                            Image(systemName: diseaseSeverity.icon)
                                .font(.system(size: 12))
                            Text(diseaseSeverity.displayName)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .glassPill(.regular.interactive().tint(Color(diseaseSeverity.color)))
                        
                        // 状态标签
                        HStack(spacing: 2) {
                            Image(systemName: diseaseStatus.icon)
                                .font(.system(size: 12))
                            Text(diseaseStatus.displayName)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .glassPill(.regular.interactive().tint(Color(diseaseStatus.color)))
                    }
                }
                
                // 详细信息
                VStack(spacing: 8) {
                    if !(disease.doctor ?? "").isEmpty || !(disease.hospital ?? "").isEmpty {
                        HStack {
                            if let hospital = disease.hospital  {
                                LabelTag(icon: "building.2.fill", text: hospital)
                            }
                            if let doctor = disease.doctor  {
                                LabelTag(icon: "person.fill.badge.plus", text: doctor)
                            }
                            Spacer()
                        }
                    }
       
                    if let followUp = disease.followupVisitTime, let followUpDate = DateUtils.stringToDate(followUp + " 23:59:59", format: DateUtils.DateFormat.ymdhms), followUpDate > Date() {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 12))
                                .foregroundStyle(Color("warning"))
                            
                            Text("复诊：\(followUp)")
                                .font(.system(size: 12))
                                .foregroundStyle(Color("warning"))
                            
                            Spacer()
                        }
                    }
                }
            }.cardStyle()
        }.buttonStyle(PlainButtonStyle())
    }
}


struct LabelTag: View {
    let icon: String
    let text: String
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(text)
                .font(.system(size: 12))
        }.foregroundStyle(Color("text_secondary"))
    }
}

struct FilterTag: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? .white : Color("text_primary"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }.glassPillColor(.regular.interactive(), isSelected ? color : Color("content_bg").opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))

    }
}

struct FilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSeverities: Set<Int64>
    @Binding var selectedStatuses: Set<Int64>
    var onApply: (() -> Void)? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 严重程度过滤
                VStack(alignment: .leading, spacing: 12) {
                    Text("疾病严重程度")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color("text_primary"))
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(DiseaseSeverity.allCases, id: \.self) { severity in
                            FilterOptionRow(
                                title: severity.displayName,
                                icon: severity.icon,
                                color: Color(severity.color),
                                isSelected: selectedSeverities.contains(severity.rawValue)
                            ) {
                                if selectedSeverities.contains(severity.rawValue) {
                                    selectedSeverities.remove(severity.rawValue)
                                } else {
                                    selectedSeverities.insert(severity.rawValue)
                                }
                            }
                        }
                    }
                }
                
                // 疾病状态过滤
                VStack(alignment: .leading, spacing: 12) {
                    Text("疾病状态")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color("text_primary"))
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(DiseaseStatus.allCases, id: \.self) { status in
                            FilterOptionRow(
                                title: status.displayName,
                                icon: status.icon,
                                color: Color(status.color),
                                isSelected: selectedStatuses.contains(status.rawValue)
                            ) {
                                if selectedStatuses.contains(status.rawValue) {
                                    selectedStatuses.remove(status.rawValue)
                                } else {
                                    selectedStatuses.insert(status.rawValue)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                // 操作按钮
                HStack(spacing: 12) {
                    Button {
                        selectedSeverities.removeAll()
                        selectedStatuses.removeAll()
                    } label: {
                        Text("清除筛选")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    Button {
                        onApply?()
                        dismiss()
                    } label: {
                        Text("确定")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .navigationTitle("筛选条件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundStyle(Color("text_secondary"))
                }
            }
        }
        .sheetAppBackground()
    }
}

struct FilterOptionRow: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? .white : color)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? .white : Color("text_primary"))
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .glassContainer(isSelected ? Glass.regular.interactive().tint(color) : Glass.regular.interactive(), cornerRadius: 10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DiseaseListView_Previews: PreviewProvider {
    
    static var previews: some View {
        let globalModel = GlobalModel.shared;
        // 设置当前用户
        globalModel.currentUser = UserDTO(
            id: "01K1B6DDV396NMC01NM3MZ35KS",
            name: "周荥马",
            nickname: "U1753796228",
            gender: 1,
            birthday: "1994-02-16",
            status: 0,
            certification: 1,
            headerImg: "person.circle.fill",
            job: "软件工程师",
            city: "北京市",
            blood: 1, // A型血
            bloodRh: 1, // RH+
            nationality: 1,
            maritalStatus: 1
        );
        @State var showingDiseaseDetail = false;
        return DiseaseListView(showingDiseaseDetail: $showingDiseaseDetail).environmentObject(globalModel)
    }
}

