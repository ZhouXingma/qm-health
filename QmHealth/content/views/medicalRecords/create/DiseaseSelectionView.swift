import SwiftUI

// MARK: - 疾病选择数据模型
struct SelectedDisease: Identifiable, Codable {
    let id: String
    let diseaseId: String
    let name: String
    let severity: Int64?
    let status: Int64?
    
    enum CodingKeys: String, CodingKey {
        case diseaseId, name, severity, status
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.diseaseId = try container.decode(String.self, forKey: .diseaseId)
        self.name = try container.decode(String.self, forKey: .name)
        self.severity = try container.decodeIfPresent(Int64.self, forKey: .severity)
        self.status = try container.decodeIfPresent(Int64.self, forKey: .status)
        self.id = UUID().uuidString
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(diseaseId, forKey: .diseaseId)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(severity, forKey: .severity)
        try container.encodeIfPresent(status, forKey: .status)
    }
    
    init(diseaseId: String, name: String, severity: Int64?, status: Int64?) {
        self.id = UUID().uuidString
        self.diseaseId = diseaseId
        self.name = name
        self.severity = severity
        self.status = status
    }
}

// MARK: - 疾病选择视图
struct DiseaseSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @State private var diseaseList: [DiseaseInfo] = []
    @State private var selectedDiseases: [SelectedDisease] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var showAddDisease: Bool = false
    
    var onConfirm: ([SelectedDisease]) -> Void
    var initialSelectedDiseases: [SelectedDisease] = []
    
    var filteredDiseases: [DiseaseInfo] {
        if searchText.isEmpty {
            return diseaseList
        }
        return diseaseList.filter { disease in
            disease.name?.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("background").ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 搜索栏
                    DiseaseSearchBar(text: $searchText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    
                    // 已选择计数
                    if !selectedDiseases.isEmpty {
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.theme(.primary))
                                Text("已选择 \(selectedDiseases.count) 项")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.theme(.primary))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.theme(.primary).opacity(0.08))
                    }
                    
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(Color.theme(.primary))
                            Text("加载疾病列表中...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color("text_secondary"))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if diseaseList.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "heart.circle")
                                .font(.system(size: 48))
                                .foregroundStyle(Color("text_secondary").opacity(0.3))
                            Text("暂无未康复疾病")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color("text_primary"))
                            Text("请先在疾病信息中添加疾病")
                                .font(.system(size: 13))
                                .foregroundStyle(Color("text_secondary"))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredDiseases.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundStyle(Color("text_secondary").opacity(0.3))
                            Text("未找到匹配的疾病")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color("text_primary"))
                            Text("请尝试其他搜索词")
                                .font(.system(size: 13))
                                .foregroundStyle(Color("text_secondary"))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 10) {
                                ForEach(filteredDiseases, id: \.id) { disease in
                                    DiseaseSelectionRow(
                                        disease: disease,
                                        isSelected: selectedDiseases.contains { $0.diseaseId == disease.id },
                                        onToggle: { isSelected in
                                            toggleDisease(disease, isSelected: isSelected)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                }
            }
            .navigationTitle("选择关联疾病")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundStyle(Color("text_secondary"))
                }

                ToolbarItem(placement: .confirmationAction) {
                    // 未选任何疾病时：右上角只显示「新增疾病」
                    // 已选疾病时：右上角同时显示「新增」「确定」两个按钮
                    if selectedDiseases.isEmpty {
                        Button("新增疾病") {
                            showAddDisease = true
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.theme(.primary))
                    } else {
                        HStack(spacing: 14) {
                            Button("新增") {
                                showAddDisease = true
                            }
                            .foregroundStyle(Color.theme(.primary))

                            Button("确定") {
                                onConfirm(selectedDiseases)
                                dismiss()
                            }
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.theme(.primary))
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddDisease) {
                // 用 @State 绑定一个可选的 DiseaseInfo，传入 nil 表示新增模式
                DiseaseDetailEditView(
                    diseaseInfo: .constant(nil),
                    onUpdate: {
                        // 新增疾病保存成功后，刷新疾病列表
                        loadDiseases()
                    }
                )
            }
        }
        .onAppear {
            loadDiseases()
            selectedDiseases = initialSelectedDiseases
        }
    }
    
    private func loadDiseases() {
        isLoading = true
        BgResultNetWork<Empty, [DiseaseInfo]>.post(apiUrl(DISEASE_LIST_NOT_RECOVERED), params: nil)
            .complicationHand { (diseaseInfosOptions: [DiseaseInfo]?) in
                DispatchQueue.main.async {
                    if let infos = diseaseInfosOptions {
                        self.diseaseList = infos
                    } else {
                        self.diseaseList = []
                    }
                    self.isLoading = false
                }
            }
            .errorHandle { (result, error) in
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
            .responseDecodable()
    }
    
    private func toggleDisease(_ disease: DiseaseInfo, isSelected: Bool) {
        if isSelected {
            let selectedDisease = SelectedDisease(
                diseaseId: disease.id ?? "",
                name: disease.name ?? "",
                severity: disease.severity,
                status: disease.status
            )
            selectedDiseases.append(selectedDisease)
        } else {
            selectedDiseases.removeAll { $0.diseaseId == disease.id }
        }
    }
}

// MARK: - 疾病选择行
struct DiseaseSelectionRow: View {
    let disease: DiseaseInfo
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var diseaseSeverity: DiseaseSeverity {
        if let severity = disease.severity {
            return DiseaseSeverity.getByCode(code: severity) ?? DiseaseSeverity.mild
        }
        return DiseaseSeverity.mild
    }
    
    var diseaseStatus: DiseaseStatus {
        if let status = disease.status {
            return DiseaseStatus.getByCode(code: status) ?? DiseaseStatus.stable
        }
        return DiseaseStatus.stable
    }
    
    var body: some View {
        Button(action: { onToggle(!isSelected) }) {
            HStack(spacing: 12) {
                // 复选框 - 选中态玻璃
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.clear)
                            .glassPillColor(.regular.interactive(), Color.theme(.primary).opacity(0.8))
                            .overlay(
                                Circle().fill(Color.theme(.primary).opacity(0.15))
                            )
                            .transition(.scale)
                    } else {
                        Circle()
                            .fill(Color.clear)
                            .stroke(Color("text_secondary").opacity(0.3), lineWidth: 2)
                    }

                    Image(systemName: isSelected ? "checkmark" : "")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 24, height: 24)

                // 疾病信息
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(disease.name ?? "")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color("text_primary"))
                            .lineLimit(1)

                        // 严重程度标签 - 玻璃药丸
                        HStack(spacing: 3) {
                            Image(systemName: diseaseSeverity.icon)
                                .font(.system(size: 9, weight: .semibold))
                            Text(diseaseSeverity.displayName)
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .glassPillColor(.regular.interactive(), Color(diseaseSeverity.color).opacity(0.7))

                        Spacer()
                    }

                    // 状态指示器
                    HStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(diseaseStatus.color))
                                .frame(width: 5, height: 5)

                            Text(diseaseStatus.displayName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color("text_secondary"))
                        }

                        Spacer()
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.theme(.primary).opacity(0.06) : Color("content_bg"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                isSelected ? Color.theme(.primary).opacity(0.4) : Color("divider").opacity(0.5),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 搜索栏
struct DiseaseSearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color("text_secondary").opacity(0.6))
            
            TextField("搜索疾病名称", text: $text)
                .font(.system(size: 15, weight: .regular))
                .textFieldStyle(.plain)
                .foregroundStyle(Color("text_primary"))
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color("text_secondary").opacity(0.5))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color("input_bg"))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color("divider").opacity(0.3), lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
    }
}

#Preview {
    DiseaseSelectionView { diseases in
        print("Selected diseases: \(diseases)")
    }
}
