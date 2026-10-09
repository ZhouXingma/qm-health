//
//  ProfileInfoEditView.swift
//  QmHealth
//  档案信息编辑页面
//
//  Created by Kiro on 2025/1/30.
//

import SwiftUI

struct ProfileInfoEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var profileMetadata: ProfileMetadata?
    var onUpdate: () -> Void
    
    // 表单字段
    @State private var name: String = ""
    @State private var dataType: ProfileDataType = .single
    @State private var singleValue: String = ""
    @State private var multipleValues: [String] = []
    @State private var recordValues: [ProfileRecord] = []
    @State private var newMultiValue: String = ""
    @State private var showingAddRecord: Bool = false
    @State private var editingRecord: ProfileRecord?
    
    // 智能建议相关
    @State private var existingProfiles: [ProfileMetadata] = []
    @State private var isLoadingProfiles: Bool = false
    @State private var showingSuggestions: Bool = false
    @State private var isNameFieldFocused: Bool = false
    
    // 验证状态
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    
    // 计算匹配的建议
    var matchedSuggestions: [ProfileMetadata] {
        guard !name.isEmpty, !isEditing else { return [] }
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return [] }
        
        // 模糊匹配：名称包含输入内容
        let matched = existingProfiles.filter { profile in
            guard let profileName = profile.name else { return false }
            return profileName.localizedCaseInsensitiveContains(trimmedName)
        }
        
        // 按相似度排序，完全匹配的排在前面
        return matched.sorted { p1, p2 in
            let name1 = p1.name ?? ""
            let name2 = p2.name ?? ""
            
            // 完全匹配优先
            let exact1 = name1.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
            let exact2 = name2.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
            if exact1 != exact2 { return exact1 }
            
            // 前缀匹配优先
            let prefix1 = name1.localizedLowercase.hasPrefix(trimmedName.localizedLowercase)
            let prefix2 = name2.localizedLowercase.hasPrefix(trimmedName.localizedLowercase)
            if prefix1 != prefix2 { return prefix1 }
            
            // 按修改时间排序
            let time1 = p1.gmtModified ?? ""
            let time2 = p2.gmtModified ?? ""
            return time1.compare(time2).rawValue > 0
        }.prefix(5).map { $0 } // 最多显示5个建议
    }
    
    var isEditing: Bool {
        profileMetadata != nil
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("background").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 14) {
                        // 基本信息（带智能建议）
                        basicInfoSectionWithSuggestions
                        
                        // 数据类型选择
                        if !isEditing {
                            dataTypeSection
                        }
                        
                        // 数据内容
                        dataContentSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle(isEditing ? "编辑档案信息" : "添加档案信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("取消")
                            .font(.system(size: 16))
                            .foregroundStyle(Color("text_secondary"))
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveProfile()
                    } label: {
                        Text(isEditing ? "保存" : "添加")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.theme(.primary))
                    }
                }
            }
        }
        .sheetAppBackground()
        .onAppear {
            loadData()
            if !isEditing {
                loadExistingProfiles()
            }
        }
        .alert("提示", isPresented: $showingError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingAddRecord) {
            RecordEditSheet(
                record: $editingRecord,
                onSave: { record in
                    if let index = recordValues.firstIndex(where: { $0.id == record.id }) {
                        recordValues[index] = record
                    } else {
                        recordValues.append(record)
                    }
                    editingRecord = nil
                }
            )
        }
    }
    
    // MARK: - 基本信息区域（带智能建议）
    private var basicInfoSectionWithSuggestions: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题和字数统计
            HStack {
                Text("名称")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color("text_primary"))
                
                Spacer()
                
                if isLoadingProfiles {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("加载中...")
                            .font(.system(size: 11))
                            .foregroundStyle(Color("text_secondary"))
                    }
                } else {
                    Text("\(name.count)/20")
                        .font(.system(size: 12))
                        .foregroundStyle(name.count > 20 ? Color("error") : Color("text_secondary"))
                }
            }
            
            // 输入框
            VStack(alignment: .leading) {
                TextField("如：吸烟状态、饮食习惯等", text: $name)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 15))
                    .padding(.horizontal, 10)
                    .inputFieldStyle()
                    .padding(.vertical, 10)
                    .onChange(of: name) { oldValue, newValue in
                        // 输入时显示建议
                        if !newValue.isEmpty && !isEditing {
                            showingSuggestions = true
                        } else {
                            showingSuggestions = false
                        }
                    }
            }
           
            
            // 智能建议列表
            if showingSuggestions && !matchedSuggestions.isEmpty && !isEditing {
                VStack(spacing: 10) {
                    ForEach(Array(matchedSuggestions.enumerated()), id: \.element.id) { index, profile in
                        SuggestionRow(
                            profile: profile,
                            searchText: name,
                            isLast: index == matchedSuggestions.count - 1
                        ) {
                            loadFromExistingProfile(profile)
                            showingSuggestions = false
                        }
                    }
                }
            }
            
            // 提示文本
            if !showingSuggestions || matchedSuggestions.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color("warning"))
                    
                    Text(isEditing ? "档案名称" : "输入名称时会显示相关建议")
                        .font(.system(size: 11))
                        .foregroundStyle(Color("text_secondary"))
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 12)
            } else {
                Spacer()
                    .frame(height: 12)
            }
        }.cardStyle()
    }
    
    // MARK: - 基本信息区域（旧版，保留作为备用）
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("名称")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color("text_primary"))
                
                Spacer()
                
                Text("\(name.count)/20")
                    .font(.system(size: 12))
                    .foregroundStyle(name.count > 20 ? Color("error") : Color("text_secondary"))
            }
            
            TextField("如：吸烟状态、饮食习惯等", text: $name)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .appGlass(.regular.interactive(), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(12)
        .glassContainer(.regular.interactive(), cornerRadius: 12)
    }
    
    // MARK: - 数据类型选择区域
    private var dataTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("数据类型")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color("text_primary"))
            
            HStack(spacing: 8) {
                ForEach(ProfileDataType.allCases, id: \.self) { type in
                    DataTypeOptionCard(
                        dataType: type,
                        isSelected: dataType == type
                    ) {
                        dataType = type
                    }
                }
            }
        }.cardStyle()
    }
    
    // MARK: - 数据内容区域
    private var dataContentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("数据内容")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color("text_primary"))
                .padding(.horizontal, 12)
            
            switch dataType {
            case .single:
                singleValueInput
            case .multiple:
                multipleValueInput
            case .record:
                recordValueInput
            }
        }
    }
    
    // MARK: - 单值输入
    private var singleValueInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("请输入内容", text: $singleValue, axis: .vertical)
                .textFieldStyle(PlainTextFieldStyle())
                .lineLimit(3...8)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .appGlass(.regular.interactive().tint(AppColor.content.opacity(0.5)), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            Text("记录单一文本信息")
                .font(.system(size: 11))
                .foregroundStyle(Color("text_secondary"))
        }
        .cardStyle()
    }
    
    // MARK: - 多值输入
    private var multipleValueInput: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 添加新值
            HStack(spacing: 8) {
                TextField("输入后点击添加", text: $newMultiValue)
                    .textFieldStyle(PlainTextFieldStyle())
                    .inputFieldStyle()
                
                Button {
                    addMultipleValue()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20))
                        .foregroundStyle(AppColor.primary)
                        .padding(10)
                }
                .glassEffect(.regular.interactive())
                .disabled(newMultiValue.isEmpty)
            }
            
            // 已添加的值列表
            if !multipleValues.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("已添加 \(multipleValues.count) 项")
                        .font(.system(size: 11))
                        .foregroundStyle(Color("text_secondary"))
                    
                    HFlow(spacing: 6) {
                        ForEach(Array(multipleValues.enumerated()), id: \.offset) { index, value in
                            HStack(spacing: 4) {
                                Text(value)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color("text_primary"))
                                
                                Button {
                                    multipleValues.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color("text_secondary"))
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .appGlass(.regular.interactive(), in: Capsule())
                        }
                    }
                }
            }
            
            Text("记录多个独立的文本信息")
                .font(.system(size: 11))
                .foregroundStyle(Color("text_secondary"))
        }
        .cardStyle()
    }
    
    // MARK: - 记录值输入
    private var recordValueInput: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 添加记录按钮
            Button {
                editingRecord = nil
                showingAddRecord = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("添加记录")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(Color.theme(.primary))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .glassEffect(.regular.interactive(), in: Capsule())
            }
            
            // 记录列表
            if !recordValues.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("已添加 \(recordValues.count) 条记录")
                        .font(.system(size: 11))
                        .foregroundStyle(Color("text_secondary"))
                    
                    let sortedRecords = recordValues.sorted(by: { ($0.occurredAt ?? Date()) > ($1.occurredAt ?? Date()) })
                    ForEach(sortedRecords) { record in
                        RecordRow(record: record) {
                            editingRecord = record
                            showingAddRecord = true
                        } onDelete: {
                            recordValues.removeAll { $0.id == record.id }
                        }
                    }
                }
            }
            
            Text("每条记录包含时间和内容")
                .font(.system(size: 11))
                .foregroundStyle(Color("text_secondary"))
        }
        .cardStyle()
    }
    
    // MARK: - 辅助方法
    private func loadData() {
        guard let profile = profileMetadata else { return }
        
        name = profile.name ?? ""
        dataType = profile.dataType
        singleValue = profile.singleValue ?? ""
        multipleValues = profile.multipleValues ?? []
        recordValues = profile.recordValues ?? []
    }
    
    private func loadExistingProfiles() {
        isLoadingProfiles = true
        
        BgResultNetWork<Empty?, [ProfileMetadataResponse]>
            .post(apiUrl(METADATA_ALLLASTED))
            .complicationHand { (responses: [ProfileMetadataResponse]?) in
                DispatchQueue.main.async {
                    self.isLoadingProfiles = false
                    
                    guard let responses = responses else {
                        self.existingProfiles = []
                        return
                    }
                    
                    // 转换响应数据为 ProfileMetadata
                    self.existingProfiles = responses.compactMap { response in
                        self.parseProfileMetadata(from: response)
                    }
                    
                    // 按修改时间排序
                    self.existingProfiles.sort { p1, p2 in
                        let a = p1.gmtModified ?? ""
                        let b = p2.gmtModified ?? ""
                        return a.compare(b).rawValue > 0
                    }
                }
            }
            .responseDecodable()
    }
    
    private func parseProfileMetadata(from response: ProfileMetadataResponse) -> ProfileMetadata? {
        let metadata = ProfileMetadata()
        metadata.id = response.id
        metadata.userId = response.userId
        metadata.metadataCode = response.metadataCode
        metadata.name = response.metadataCode
        metadata.dataSource = response.dataSource
        metadata.bizLabel = response.bizLabel
        metadata.gmtCreated = response.gmtCreated
        metadata.gmtModified = response.gmtModified
        
        guard let metadataValue = response.metadataValue,
              let jsonData = metadataValue.data(using: .utf8) else {
            return nil
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let dataTypeStr = json["dataType"] as? String {
                
                switch dataTypeStr {
                case "1":
                    metadata.dataType = .single
                    if let data = json["data"] as? String {
                        metadata.singleValue = data
                    }
                    
                case "2":
                    metadata.dataType = .multiple
                    if let data = json["data"] as? [String] {
                        metadata.multipleValues = data
                    }
                    
                case "3":
                    metadata.dataType = .record
                    if let dataArray = json["data"] as? [[String: String]] {
                        metadata.recordValues = dataArray.compactMap { recordDict -> ProfileRecord? in
                            guard let content = recordDict["content"],
                                  let dateStr = recordDict["date"] else {
                                return nil
                            }
                            
                            let date = DateUtils.stringToDate(dateStr, format: DateUtils.DateFormat.ymdhms)
                            
                            return ProfileRecord(
                                id: ULIDUtils.generate(),
                                value: content,
                                occurredAt: date
                            )
                        }
                    }
                    
                default:
                    return nil
                }
                
                return metadata
            }
        } catch {
            print("解析 metadataValue 失败: \(error)")
            return nil
        }
        
        return nil
    }
    
    private func loadFromExistingProfile(_ profile: ProfileMetadata) {
        name = profile.name ?? ""
        dataType = profile.dataType
        singleValue = profile.singleValue ?? ""
        multipleValues = profile.multipleValues ?? []
        recordValues = profile.recordValues ?? []
    }
    
    private func addMultipleValue() {
        let trimmed = newMultiValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if !multipleValues.contains(trimmed) {
            multipleValues.append(trimmed)
            newMultiValue = ""
        }
    }
    
    private func validateForm() -> Bool {
        // 验证名称
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "请输入名称"
            showingError = true
            return false
        }
        
        if name.count > 20 {
            errorMessage = "名称不能超过20个字符"
            showingError = true
            return false
        }
        
        // 验证数据内容
        switch dataType {
        case .single:
            if singleValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errorMessage = "请输入内容"
                showingError = true
                return false
            }
        case .multiple:
            if multipleValues.isEmpty {
                errorMessage = "请至少添加一项内容"
                showingError = true
                return false
            }
        case .record:
            if recordValues.isEmpty {
                errorMessage = "请至少添加一条记录"
                showingError = true
                return false
            }
        }
        
        return true
    }
    
    private func saveProfile() {
        guard validateForm() else { return }
        
        // 构建请求参数
        do {
            let metadataValue = try buildMetadataValue()
            let params = ProfileMetadataAddOrUpdateRequest(
                metadataCode: name.trimmingCharacters(in: .whitespacesAndNewlines),
                metadataValue: metadataValue,
                bizLabel: 2
            )
            
            // 发送请求
            BgResultNetWork<ProfileMetadataAddOrUpdateRequest, String>
                .post(apiUrl(METADATA_ADD_UPDATE), params: params)
                .complicationHand { (v:String?) in
                    DispatchQueue.main.async {
                        onUpdate()
                        dismiss()
                    }
                }
                .responseDecodable()
            
        } catch {
            errorMessage = "数据格式化失败"
            showingError = true
        }
    }
    
    private func buildMetadataValue() throws -> String {
        let dataTypeCode: String
        let data: Any
        
        switch dataType {
        case .single:
            dataTypeCode = "1"
            data = singleValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
        case .multiple:
            dataTypeCode = "2"
            data = multipleValues
            
        case .record:
            dataTypeCode = "3"
            let recordData = recordValues.map { record -> [String: String] in
                let timeStr = record.occurredAt != nil 
                    ? DateUtils.formatDate(record.occurredAt!, format: DateUtils.DateFormat.ymdhms)
                    : DateUtils.formatDate(Date(), format: DateUtils.DateFormat.ymdhms)
                return [
                    "content": record.value,
                    "date": timeStr
                ]
            }
            data = recordData
        }
        
        let metadataDict: [String: Any] = [
            "dataType": dataTypeCode,
            "data": data
        ]
        
        // 转换为JSON字符串
        let jsonData = try JSONSerialization.data(withJSONObject: metadataDict, options: [])
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw NSError(domain: "ProfileInfoEditView", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法转换为JSON字符串"])
        }
        
        return jsonString
    }
}

// MARK: - API 请求模型
struct ProfileMetadataAddOrUpdateRequest: Codable {
    var metadataCode: String
    var metadataValue: String
    var bizLabel: Int16
}

// MARK: - 智能建议组件
struct SuggestionRow: View {
    let profile: ProfileMetadata
    let searchText: String
    let isLast: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    // 数据类型图标
                    Image(systemName: profile.dataType.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .appGlass(.regular.interactive().tint(Color(profile.dataType.color)), in: Circle())
                    
                    // 档案信息
                    VStack(alignment: .leading, spacing: 3) {
                        // 高亮匹配的文本
                        HighlightedText(
                            text: profile.name ?? "",
                            highlight: searchText,
                            font: .system(size: 14, weight: .medium),
                            normalColor: Color("text_primary"),
                            highlightColor: Color.theme(.primary)
                        )
                        
                        HStack(spacing: 6) {
                            Text(profile.dataType.displayName)
                                .font(.system(size: 11))
                                .foregroundStyle(Color(profile.dataType.color))
                            
                            if let updateTime = profile.gmtModified {
                                Text("•")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color("text_secondary"))
                                
                                Text(formatUpdateTime(updateTime))
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color("text_secondary"))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // 使用图标
                    Image(systemName: "arrow.up.left.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.theme(.primary).opacity(0.6))
                }
            }.glassCardStyle(.regular.interactive().tint(AppColor.content.opacity(0.5)))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatUpdateTime(_ timeStr: String) -> String {
        if let date = DateUtils.stringToDate(timeStr, format: DateUtils.DateFormat.ymdhms) {
            let calendar = Calendar.current
            let now = Date()
            
            if calendar.isDateInToday(date) {
                return "今天"
            }
            
            if calendar.isDateInYesterday(date) {
                return "昨天"
            }
            
            if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM-dd"
                return formatter.string(from: date)
            }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            return formatter.string(from: date)
        }
        
        return ""
    }
}

// 高亮文本组件
struct HighlightedText: View {
    let text: String
    let highlight: String
    let font: Font
    let normalColor: Color
    let highlightColor: Color
    
    var body: some View {
        let parts = highlightParts(text: text, highlight: highlight)
        
        HStack(spacing: 0) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                Text(part.text)
                    .font(font)
                    .foregroundStyle(part.isHighlight ? highlightColor : normalColor)
                    .fontWeight(part.isHighlight ? .semibold : .regular)
            }
        }
    }
    
    private func highlightParts(text: String, highlight: String) -> [(text: String, isHighlight: Bool)] {
        guard !highlight.isEmpty else {
            return [(text, false)]
        }
        
        var parts: [(String, Bool)] = []
        let lowercaseText = text.lowercased()
        let lowercaseHighlight = highlight.lowercased()
        
        var currentIndex = text.startIndex
        
        while currentIndex < text.endIndex {
            let remainingText = String(text[currentIndex...])
            let remainingLowercase = String(lowercaseText[currentIndex...])
            
            if let range = remainingLowercase.range(of: lowercaseHighlight) {
                // 添加高亮前的文本
                if range.lowerBound != remainingText.startIndex {
                    let beforeText = String(remainingText[..<range.lowerBound])
                    parts.append((beforeText, false))
                }
                
                // 添加高亮文本
                let highlightText = String(remainingText[range])
                parts.append((highlightText, true))
                
                currentIndex = text.index(currentIndex, offsetBy: text.distance(from: remainingText.startIndex, to: range.upperBound))
            } else {
                // 没有更多匹配，添加剩余文本
                parts.append((remainingText, false))
                break
            }
        }
        
        return parts
    }
}

// MARK: - 子组件
struct DataTypeOptionCard: View {
    let dataType: ProfileDataType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Spacer(minLength: 0)

                Image(systemName: dataType.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? .white : Color(dataType.color))
                    .frame(width: 36, height: 36)
                    .appGlass(
                        isSelected ? Glass.regular.interactive().tint(Color(dataType.color)) : Glass.clear.interactive().tint(Color("content_bg")),
                        in: Circle()
                    )

                Text(dataType.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : Color("text_primary"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(dataType.description)
                    .font(.system(size: 10))
                    .frame(height: 30)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color("text_secondary"))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .frame(height: 140)
            .padding(.horizontal, 6)
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
            .glassEffect(.regular.interactive().tint(isSelected ? AppColor.primary : AppColor.content.opacity(0.5)), in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecordRow: View {
    let record: ProfileRecord
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 左侧时间图标
            VStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.theme(.primary))
                    .frame(width: 32, height: 32)
                       .background(Color.theme(.primary).opacity(0.1))
                    .clipShape(Circle())
            }
            
            // 中间内容
            VStack(alignment: .leading, spacing: 6) {
                if let time = record.occurredAt {
                    Text(DateUtils.formatDate(time, format: DateUtils.DateFormat.ymdhms))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color("text_secondary"))
                }
                
                Text(record.value)
                    .font(.system(size: 14))
                    .foregroundStyle(Color("text_primary"))
                    .lineLimit(3)
            }
            
            Spacer()
            
            // 右侧操作按钮
            HStack(spacing: 8) {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.theme(.primary))
                }
                
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color("error"))
                }
            }
        }
        .padding(12)
        .glassContainer(.regular.interactive(), cornerRadius: 12)
    }
}

struct RecordEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var record: ProfileRecord?
    var onSave: (ProfileRecord) -> Void
    
    @State private var value: String = ""
    @State private var occurredAt: Date = Date()
    
    var isEditing: Bool {
        record != nil
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("background").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 时间选择卡片
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.theme(.primary))
                                Text("记录时间")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color("text_primary"))
                            }
                            
                            DatePicker("", selection: $occurredAt, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(Color.theme(.primary))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                        
                        // 内容输入卡片
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "text.alignleft")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.theme(.primary))
                                Text("记录内容")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color("text_primary"))
                            }
                            
                            ZStack(alignment: .topLeading) {
                                if value.isEmpty {
                                    Text("请输入记录内容...")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Color("text_secondary").opacity(0.5))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                }
                                
                                TextEditor(text: $value)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color("text_primary"))
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 120)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                            }
                            .appGlass(.regular.interactive().tint(AppColor.content.opacity(0.5)), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            
                            HStack {
                                Spacer()
                                Text("\(value.count) 字符")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color("text_secondary"))
                            }
                        }
                        .cardStyle()
                        
                        // 保存按钮
                        Button {
                            saveRecord()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                Text("保存记录")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppColor.divider :  AppColor.primary)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                        .disabled(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .padding(.top, 8)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle(isEditing ? "编辑记录" : "添加记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("取消")
                            .font(.system(size: 16))
                            .foregroundStyle(Color("text_secondary"))
                    }
                }
            }
        }
        .sheetAppBackground()
        .onAppear {
            if let existingRecord = record {
                value = existingRecord.value
                occurredAt = existingRecord.occurredAt ?? Date()
            }
        }
    }
    
    private func saveRecord() {
        let newRecord = ProfileRecord(
            id: record?.id ?? ULIDUtils.generate(),
            value: value,
            occurredAt: occurredAt
        )
        onSave(newRecord)
        dismiss()
    }
}

#Preview {
    @State var profile: ProfileMetadata? = nil
    return ProfileInfoEditView(profileMetadata: $profile, onUpdate: {})
}
