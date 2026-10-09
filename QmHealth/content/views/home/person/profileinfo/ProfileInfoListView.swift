//
//  ProfileInfoListView.swift
//  QmHealth
//  档案信息列表页面
//
//  Created by Kiro on 2025/1/30.
//

import SwiftUI

struct ProfileInfoListView: View {
    @Binding var showingProfileInfoDetail: Bool
    @State private var selectedProfile: ProfileMetadata?
    @State private var searchText = ""
    @State private var profileMetadatas: [ProfileMetadata] = []
    
    var filteredProfiles: [ProfileMetadata] {
        var profiles = profileMetadatas
        
        // 搜索过滤
        if !searchText.isEmpty {
            profiles = profiles.filter { profile in
                let name = profile.name ?? ""
                return name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return profiles.sorted { p1, p2 in
            let a = p1.gmtModified ?? ""
            let b = p2.gmtModified ?? ""
            return a.compare(b).rawValue > 0
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索和过滤栏
            VStack(spacing: 12) {
                searchBar
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Color("background"))
            
            // 档案信息列表
            if filteredProfiles.isEmpty {
                emptyStateView
            } else {
                profileListSection
            }
        }
        .onAppear {
            loadProfileMetadatas()
        }
        .onChange(of: showingProfileInfoDetail) { oldValue, newValue in
            if newValue == false {
                selectedProfile = nil
            }
        }
        .sheet(isPresented: $showingProfileInfoDetail) {
            ProfileInfoEditView(
                profileMetadata: $selectedProfile,
                onUpdate: {
                    loadProfileMetadatas()
                }
            )
        }
    }
    
    // MARK: - 搜索栏
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color("text_secondary").opacity(0.6))
            
            TextField("搜索档案信息", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 15))
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color("text_secondary").opacity(0.5))
                }
            }
        }
        .inputFieldStyle()
    }

    // MARK: - 列表区域
    private var profileListSection: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(filteredProfiles, id: \.id) { profile in
                    ProfileInfoRow(
                        profile: profile,
                        onTap: {
                            selectedProfile = profile
                            showingProfileInfoDetail = true
                        },
                        onDelete: {
                            deleteProfile(profile)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await refreshData()
        }
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // 图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.theme(.primary).opacity(0.1),
                                Color.theme(.primary).opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: searchText.isEmpty ? "doc.text.fill" : "magnifyingglass")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.theme(.primary),
                                Color.theme(.primary).opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "暂无档案信息" : "未找到相关档案")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                
                Text(searchText.isEmpty ? "点击右上角 + 号添加档案信息" : "尝试调整搜索条件")
                    .font(.system(size: 14))
                    .foregroundStyle(Color("text_secondary"))
                    .multilineTextAlignment(.center)
            }
            
            if searchText.isEmpty {
                Button {
                    selectedProfile = nil
                    showingProfileInfoDetail = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("添加档案信息")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .glassPill(.regular.interactive().tint(Color.theme(.primary)))
                }
                .buttonStyle(ScaleButtonStyle())
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
    
    // MARK: - 数据加载
    private func loadProfileMetadatas() {
        BgResultNetWork<Empty?, [ProfileMetadataResponse]>
            .post(apiUrl(METADATA_ALLLASTED))
            .complicationHand { (responses: [ProfileMetadataResponse]?) in
                DispatchQueue.main.async {
                    guard let responses = responses else {
                        self.profileMetadatas = []
                        return
                    }
                    
                    // 转换响应数据为 ProfileMetadata
                    self.profileMetadatas = responses.compactMap { response in
                        self.parseProfileMetadata(from: response)
                    }
                }
            }
            .responseDecodable()
    }
    
    // MARK: - 下拉刷新
    private func refreshData() async {
        await withCheckedContinuation { continuation in
            BgResultNetWork<Empty?, [ProfileMetadataResponse]>
                .post(apiUrl(METADATA_ALLLASTED))
                .complicationHand { (responses: [ProfileMetadataResponse]?) in
                    DispatchQueue.main.async {
                        guard let responses = responses else {
                            self.profileMetadatas = []
                            continuation.resume()
                            return
                        }
                        
                        // 转换响应数据为 ProfileMetadata
                        self.profileMetadatas = responses.compactMap { response in
                            self.parseProfileMetadata(from: response)
                        }
                        continuation.resume()
                    }
                }
                .errorHandle { _, _ in
                    DispatchQueue.main.async {
                        continuation.resume()
                    }
                }
                .responseDecodable()
        }
    }
    
    // MARK: - 删除档案信息
    private func deleteProfile(_ profile: ProfileMetadata) {
        guard let metadataCode = profile.metadataCode else { return }
        
        let params = ProfileMetadataDeleteRequest(metadataCode: metadataCode)
        
        BgResultNetWork<ProfileMetadataDeleteRequest, Int>
            .post(apiUrl(METADATA_DELETE), params: params)
            .complicationHand { (affectedRows: Int?) in
                DispatchQueue.main.async {
                    // 删除成功，从列表中移除
                    if let affectedRows = affectedRows, affectedRows > 0 {
                        self.profileMetadatas.removeAll { $0.id == profile.id }
                    }
                }
            }
            .responseDecodable()
    }
    
    // 解析 ProfileMetadata
    private func parseProfileMetadata(from response: ProfileMetadataResponse) -> ProfileMetadata? {
        let metadata = ProfileMetadata()
        metadata.id = response.id
        metadata.userId = response.userId
        metadata.metadataCode = response.metadataCode
        metadata.name = response.metadataCode // 使用 metadataCode 作为名称
        metadata.dataSource = response.dataSource
        metadata.bizLabel = response.bizLabel
        metadata.gmtCreated = response.gmtCreated
        metadata.gmtModified = response.gmtModified
        
        // 解析 metadataValue JSON 字符串
        guard let metadataValue = response.metadataValue,
              let jsonData = metadataValue.data(using: .utf8) else {
            return nil
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let dataTypeStr = json["dataType"] as? String {
                
                // 根据 dataType 解析数据
                switch dataTypeStr {
                case "1": // 单值
                    metadata.dataType = .single
                    if let data = json["data"] as? String {
                        metadata.singleValue = data
                    }
                    
                case "2": // 多值
                    metadata.dataType = .multiple
                    if let data = json["data"] as? [String] {
                        metadata.multipleValues = data
                    }
                    
                case "3": // 记录
                    metadata.dataType = .record
                    if let dataArray = json["data"] as? [[String: String]] {
                        metadata.recordValues = dataArray.compactMap { recordDict -> ProfileRecord? in
                            guard let content = recordDict["content"],
                                  let dateStr = recordDict["date"] else {
                                return nil
                            }
                            
                            // 解析日期
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
}

// MARK: - 子组件
struct ProfileInfoRow: View {
    let profile: ProfileMetadata
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                // 左侧彩色条纹和图标
                VStack {
                    ZStack {
                        Image(systemName: profile.dataType.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 44, height: 44)
                    .appGlass(.regular.interactive().tint(Color(profile.dataType.color)), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    
                    Spacer()
                }
                
                // 中间内容区域
                VStack(alignment: .leading, spacing: 6) {
                    // 标题行
                    HStack(alignment: .center, spacing: 8) {
                        Text(profile.name ?? "")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color("text_primary"))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // 时间标签
                        if let updateTime = profile.gmtModified {
                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9))
                                Text(formatUpdateTime(updateTime))
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(Color("text_secondary").opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            
                        }
                    }
                    
                    // 数据内容预览
                    dataContentPreview
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                }
            .cardStyle()
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
    
    // 格式化更新时间
    private func formatUpdateTime(_ timeStr: String) -> String {
        // 尝试解析时间字符串
        if let date = DateUtils.stringToDate(timeStr, format: DateUtils.DateFormat.ymdhms) {
            let calendar = Calendar.current
            let now = Date()
            
            // 如果是今天
            if calendar.isDateInToday(date) {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                return "今天 " + formatter.string(from: date)
            }
            
            // 如果是昨天
            if calendar.isDateInYesterday(date) {
                return "昨天"
            }
            
            // 如果是本年
            if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM-dd"
                return formatter.string(from: date)
            }
            
            // 其他情况显示年月日
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }
        
        // 如果解析失败，返回原字符串的简化版本
        if timeStr.count >= 10 {
            return String(timeStr.prefix(10))
        }
        return timeStr
    }
    
    @ViewBuilder
    private var dataContentPreview: some View {
        switch profile.dataType {
        case .single:
            if let value = profile.singleValue, !value.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(profile.dataType.color).opacity(0.6))
                    
                    Text(value)
                        .font(.system(size: 13))
                        .foregroundStyle(Color("text_secondary"))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
        case .multiple:
            if let values = profile.multipleValues, !values.isEmpty {
                HFlow(spacing: 6) {
                    ForEach(Array(values.prefix(5).enumerated()), id: \.offset) { _, value in
                        Text(value)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color("text_primary"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .glassPill(.regular.interactive().tint(Color(profile.dataType.color).opacity(0.18)))
                    }
                    if values.count > 5 {
                        Text("+\(values.count - 5)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color("text_secondary"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .glassPill(.regular.interactive())
                    }
                }
            }
            
        case .record:
            if let records = profile.recordValues, !records.isEmpty {
                let sortedRecords = records.sorted(by: { ($0.occurredAt ?? Date()) > ($1.occurredAt ?? Date()) })
                if let latestRecord = sortedRecords.first {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            // 时间标签
                            if let time = latestRecord.occurredAt {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 11, weight: .medium))
                                    Text(DateUtils.formatDate(time, format: DateUtils.DateFormat.ymd))
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .glassPill(.regular.interactive().tint(Color(profile.dataType.color)))
                            }

                            Spacer()

                            // 记录数量
                            if records.count > 1 {
                                HStack(spacing: 3) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 10))
                                    Text("\(records.count)条记录")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundStyle(Color("text_secondary").opacity(0.85))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .glassPill(.regular.interactive())
                            }
                        }

                        // 最新记录内容
                        Text(latestRecord.value)
                            .font(.system(size: 13))
                            .foregroundStyle(Color("text_secondary"))
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

struct ProfileDataTypeHeader: View {
    let dataType: ProfileDataType
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: dataType.icon)
                .font(.system(size: 14))
                .foregroundStyle(Color(dataType.color))
            
            Text(dataType.displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color("text_primary"))
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color("background"))
    }
}

struct DataTypeFilterTag: View {
    let dataType: ProfileDataType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: dataType.icon)
                    .font(.system(size: 12))
                Text(dataType.displayName)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : Color("text_primary"))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .appGlass(
                isSelected ? Glass.clear.interactive().tint(Color(dataType.color)) : Glass.clear.interactive().tint(Color("content_bg")),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
    }
}

// MARK: - API 响应模型
struct ProfileMetadataResponse: Codable {
    var id: String?
    var userId: String?
    var metadataCode: String?
    var metadataValue: String?
    var dataSource: String?
    var bizLabel: Int16?
    var gmtCreated: String?
    var gmtModified: String?
}

// MARK: - API 请求模型
struct ProfileMetadataDeleteRequest: Codable {
    var metadataCode: String
}

#Preview {
    @State var showingDetail = false
    return ProfileInfoListView(showingProfileInfoDetail: $showingDetail)
}
