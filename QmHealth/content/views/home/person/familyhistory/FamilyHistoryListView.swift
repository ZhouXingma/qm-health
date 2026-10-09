//
//  FamilyHistoryListView.swift
//  QmHealth
//  家族史列表页面
//
//  Created by Kiro on 2025/1/28.
//

import SwiftUI

struct FamilyHistoryListView: View {
    @Binding var showingFamilyHistoryDetail: Bool
    @State private var selectedHistory: FamilyHistory?
    @State private var searchText = ""
    @State private var selectedGroup: FamilyGroup?
    @State private var familyHistories: [FamilyHistory] = []
    
    var filteredHistories: [FamilyHistory] {
        var histories = familyHistories
        
        // 搜索过滤
        if !searchText.isEmpty {
            histories = histories.filter { history in
                let relationshipName = history.relationshipName ?? ""
                let diseaseName = history.diseaseName ?? ""
                return relationshipName.localizedCaseInsensitiveContains(searchText) ||
                       diseaseName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 分组过滤
        if let group = selectedGroup {
            histories = histories.filter { history in
                guard let relationship = history.relationship,
                      let rel = FamilyRelationship.getByCode(code: relationship) else {
                    return false
                }
                return rel.group == group
            }
        }
        
        return histories.sorted { h1, h2 in
            let a = h1.gmtModified ?? ""
            let b = h2.gmtModified ?? ""
            return a.compare(b).rawValue > 0
        }
    }
    
    // 按分组组织数据
    var groupedHistories: [FamilyGroup: [FamilyHistory]] {
        Dictionary(grouping: filteredHistories) { history in
            guard let relationship = history.relationship,
                  let rel = FamilyRelationship.getByCode(code: relationship) else {
                return .extended
            }
            return rel.group
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索和过滤栏
            VStack(spacing: 12) {
                searchBar
                filterBar
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color("background"))
            
            // 家族史列表
            if filteredHistories.isEmpty {
                emptyStateView
            } else {
                historyListSection
            }
        }
        .onAppear {
            loadFamilyHistories()
        }
        .onChange(of: showingFamilyHistoryDetail) { oldValue, newValue in
            if newValue == false {
                selectedHistory = nil
            }
        }
        .sheet(isPresented: $showingFamilyHistoryDetail) {
            FamilyHistoryEditView(
                familyHistory: $selectedHistory,
                allHistories: $familyHistories,
                onUpdate: {
                    loadFamilyHistories()
                }
            )
        }
    }
    
    // MARK: - 搜索栏
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color("text_secondary"))
            
            TextField("搜索亲属或疾病", text: $searchText)
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
    
    // MARK: - 过滤栏
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FamilyGroup.allCases, id: \.self) { group in
                    GroupFilterTag(
                        group: group,
                        isSelected: selectedGroup == group
                    ) {
                        selectedGroup = selectedGroup == group ? nil : group
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - 列表区域
    private var historyListSection: some View {
        ScrollView {
            LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                ForEach(FamilyGroup.allCases, id: \.self) { group in
                    if let histories = groupedHistories[group], !histories.isEmpty {
                        Section {
                            ForEach(histories, id: \.id) { history in
                                FamilyHistoryRow(
                                    history: history,
                                    onTap: {
                                        selectedHistory = history
                                        showingFamilyHistoryDetail = true
                                    }
                                )
                            }
                        } header: {
                            FamilyGroupHeader(group: group)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color("text_secondary"))
            
            Text(searchText.isEmpty ? "暂无家族史记录" : "未找到相关记录")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color("text_primary"))
            
            Text(searchText.isEmpty ? "点击右上角 + 号添加家族史信息" : "尝试调整搜索条件")
                .font(.system(size: 14))
                .foregroundStyle(Color("text_secondary"))
                .multilineTextAlignment(.center)
            
            if searchText.isEmpty {
                Button("添加家族史") {
                    selectedHistory = nil
                    showingFamilyHistoryDetail = true
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
    
    // MARK: - 数据加载
    private func loadFamilyHistories() {
        let param = MetaDataGetByCodeParam(metadataCode: "家族史")
        
        BgResultNetWork<MetaDataGetByCodeParam, UsersMetadataRecordDTO>
            .post(apiUrl(METADATA_GETBYCODE), params: param)
            .complicationHand { (record: UsersMetadataRecordDTO?) in
                let response = FamilyHistoryLoadResponse.from(metadataRecord: record)
                self.familyHistories = response.histories
            }
            .responseDecodable()
    }
}

// MARK: - 子组件
struct FamilyHistoryRow: View {
    let history: FamilyHistory
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                // 头像
                if let relationship = history.relationship,
                   let rel = FamilyRelationship.getByCode(code: relationship) {
                    Image(rel.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .appGlass(.regular.interactive().tint(Color(rel.group.color)), in: Circle())
                }
                
                // 信息
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(history.relationshipName ?? "")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color("text_primary"))
                        
                        if let age = history.diagnosisAge {
                            Text("(\(age)岁)")
                                .font(.system(size: 12))
                                .foregroundStyle(Color("text_secondary"))
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "cross.case.fill")
                            .font(.system(size: 12))
                        Text(history.diseaseName ?? "")
                            .font(.system(size: 14))
                    }
                    .foregroundStyle(Color("text_secondary"))
                    
                    if let notes = history.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 12))
                            .foregroundStyle(Color("text_secondary"))
                            .lineLimit(2)
                    }
                }
                
                Spacer()
            }
            .cardStyle()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FamilyGroupHeader: View {
    let group: FamilyGroup
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: group.icon)
                .font(.system(size: 14))
                .foregroundStyle(Color(group.color))
            
            Text(group.displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color("text_primary"))
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color("background"))
    }
}

struct GroupFilterTag: View {
    let group: FamilyGroup
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: group.icon)
                    .font(.system(size: 12))
                Text(group.displayName)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : .black)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .glassPillColor(.regular.interactive(), isSelected ? Color(group.color) : Color("content_bg").opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        }
    }
}

#Preview {
    @State var showingDetail = false
    return FamilyHistoryListView(showingFamilyHistoryDetail: $showingDetail)
}
