import SwiftUI

// 患者过敏源列表页面
struct AllegyInfoListView: View {
    @Binding var showingAllegyInfoDetail: Bool
    
    // 示例数据，可后续替换为实际数据源（如 EnvironmentObject / 数据库）
    @State private var allergies: [UserAllergy] = []
    
    // 搜索与筛选
    @State private var searchText: String = ""
    @State private var selectedSeverity: Int64? = nil
    // 编辑态
    @State private var selectedAllergy: UserAllergy? = nil
    
    var filteredAllergyInfo: [UserAllergy] {
        var allergyList = allergies;
        // 搜索过滤
        if !searchText.isEmpty {
            allergyList = allergyList.filter { allergyInfo in
                let allergyName = allergyInfo.name ?? "";
                return allergyName.localizedCaseInsensitiveContains(searchText);
            }
        }
        
        // 严重程度过滤
        if let severity = selectedSeverity {
            allergyList = allergyList.filter { allergyInfo in
                guard let a = allergyInfo.severity else {
                    return false;
                }
                return a == severity;
            }
        }
        
        return allergyList.sorted { allergyInfo1, allergyInfo2 in
            let aGmtModfied = allergyInfo1.gmtModified ?? "";
            let bGmtModfied = allergyInfo2.gmtModified ?? "";
            return aGmtModfied.compare(bGmtModfied).rawValue > 0;
        }
    }
    
    
    
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索和过滤栏
            VStack(spacing: 12) {
                searchContentOfBar
                searchContentOfFilter
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            if filteredAllergyInfo.isEmpty {
                emptyState
            } else {
                listContent
            }
        }
        .onAppear() {
            initData()
        }
        .onChange(of: showingAllegyInfoDetail, { oldValue, newValue in
            if newValue == false {
                self.selectedAllergy = nil
            }
        })
        // 通过外部“+”按钮打开新增弹窗
        .sheet(isPresented: $showingAllegyInfoDetail) {
            AllergyInfoEditSheet(
                userAllergy: $selectedAllergy,
                onUpdate: {
                    loadUserAllegyInfo()
                }
            )
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color("warning"))
            Text("过敏源")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color("text_primary"))
            Spacer()
            // 本页也提供一个添加入口（与顶部“+”相同效果）
            Button {
                selectedAllergy = nil
                showingAllegyInfoDetail = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.theme(.primary))
            }
        }
    }
    
    // MARK: - 搜索和过滤区域
    private var searchContentOfBar: some View {
        // 搜索框
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color("text_secondary"))
            
            TextField("搜索过敏源名称", text: $searchText)
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
    
    private var searchContentOfFilter : some View {
        // 过滤按钮
        HStack {
            // 快速过滤标签
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AllergySeverity.allCases, id: \.self) { severity in
                        FilterTag(
                            title: severity.displayName,
                            isSelected: selectedSeverity == severity.rawValue,
                            color: Color(severity.color)
                        ) {
                            selectedSeverity = selectedSeverity == severity.rawValue ? nil : severity.rawValue;
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - 辅助视图
    private var listContent: some View {
        List {
            ForEach(filteredAllergyInfo, id:\.self.name) { userAllergy in
                AllergyListRow(
                    userAllergy: userAllergy,
                    onTap: {
                        selectedAllergy = userAllergy
                        showingAllegyInfoDetail = true
                    }
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            loadUserAllegyInfo()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Color("text_secondary"))
            
            Text(searchText.isEmpty ? "暂无过敏源记录" : "未找到相关过敏源")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color("text_primary"))
            
            Text(searchText.isEmpty ? "点击右上角 + 号添加过敏源信息" : "尝试调整搜索条件")
                .font(.system(size: 14))
                .foregroundStyle(Color("text_secondary"))
                .multilineTextAlignment(.center)
            
            if searchText.isEmpty {
                Button {
                    selectedAllergy = nil
                    showingAllegyInfoDetail = true
                } label: {
                    Text("添加过敏源")
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .padding(.horizontal, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
    
    
    
    // MARK: - 方法
    func initData() {
        loadUserAllegyInfo()
    }
    /// 加载用户过敏源
    func loadUserAllegyInfo() {
        BgResultNetWork<Empty,[UserAllergy]>.post(apiUrl(ALLERGY_LIST), params: nil)
            .complicationHand { (userAllergiesOptions:[UserAllergy]?) in
                if let infos = userAllergiesOptions {
                    self.allergies = infos
                } else {
                    self.allergies = []
                }
            }.responseDecodable()
    }
}

struct AllergyListRow : View {
    let userAllergy: UserAllergy
    let onTap: () -> Void
    
    var body: some View {
        let userAllergySeverity = AllergySeverity.getByCode(code: userAllergy.severity ?? 1) ?? AllergySeverity.mild;
        Button {
            onTap()
        } label: {
            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    VStack {
                        Text(userAllergy.name ?? "")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color("text_primary"))
                    }
                    Spacer()
                    // 严重程度标签
                    HStack(spacing: 4) {
                        Image(systemName: userAllergySeverity.icon)
                            .font(.system(size: 12))
                        Text(userAllergySeverity.displayName)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassPill(.regular.interactive().tint(Color(userAllergySeverity.color)))
                }
                if let treatment = userAllergy.treatment {
                    HStack(alignment: .top){
                        Image(systemName: "cross.case.fill")
                            .font(.system(size: 12))
                        Text(treatment)
                            .font(.system(size: 12))
                        Spacer()
                    }.foregroundStyle(Color("text_secondary"))
                    
                }
                
            }.cardStyle()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    @State var showingAllegyInfoDetail: Bool = false
    return AllegyInfoListView(showingAllegyInfoDetail: $showingAllegyInfoDetail)
}
