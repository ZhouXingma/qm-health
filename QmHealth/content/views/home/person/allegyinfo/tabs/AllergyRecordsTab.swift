//
//  AllergyRecordsTab.swift
//  QmHealth
//  过敏记录标签页
//
//  Created by 周荥马 on 2025/10/12.
//

import SwiftUI

struct AllergyRecordsTab: View {
    var allergyId: String
    
    @State private var allergyRecords: [AllergyRecordResponse] = []
    @State private var groupedRecords: [String: [AllergyRecordResponse]] = [:]
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var currentPage: Int16 = 1
    @State private var pageSize: Int16 = 10
    @State private var totalRecords: Int64 = 0
    @StateObject private var popManager = PopManager()
    @State private var showCreateSheet = false
    @State private var selectedRecord: AllergyRecordResponse? = nil
    
    var hasMoreRecords: Bool {
        Int64(allergyRecords.count) < totalRecords
    }
    
    private func groupRecordsByYear() {
        groupedRecords = Dictionary(grouping: allergyRecords, by: { $0.year })
    }
    
    var body: some View {
        ZStack {
            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(Color.theme(.primary))
                        Text("加载中...")
                            .font(.system(size: 14))
                            .foregroundColor(Color("text_secondary"))
                    }
                } else if allergyRecords.isEmpty {
                    EmptyStateView(
                        icon: "doc.text.magnifyingglass",
                        message: "暂无过敏记录"
                    )
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 6, pinnedViews: [.sectionHeaders]) {
                            if groupedRecords.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "doc.text.magnifyingglass")
                                        .font(.system(size: 48))
                                        .foregroundColor(Color("text_primary"))
                                    Text("暂无过敏记录")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color("text_secondary"))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 100)
                            } else {
                                // 按年份分组显示
                                ForEach(groupedRecords.keys.sorted(by: >), id: \.self) { year in
                                    Section {
                                        ForEach(groupedRecords[year] ?? []) { record in
                                            Button {
                                                selectedRecord = record
                                            } label: {
                                                AllergyRecordCard(record: record)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    deleteRecord(recordId: record.id)
                                                } label: {
                                                    Label("删除记录", systemImage: "trash")
                                                }
                                            }
                                        }
                                    } header: {
                                        AllergyYearHeaderView(year: year)
                                    }
                                }
                                
                                // 加载更多指示器
                                if hasMoreRecords {
                                    HStack {
                                        Spacer()
                                        if isLoadingMore {
                                            ProgressView()
                                                .padding(.vertical, 20)
                                        } else {
                                            Color.clear
                                                .frame(height: 50)
                                                .onAppear {
                                                    loadMoreRecords()
                                                }
                                        }
                                        Spacer()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        Color.clear.frame(height: 50)
                    }
                    .refreshable {
                        await refreshRecords()
                    }
                }
            }
            .background(Color("background"), ignoresSafeAreaEdges: .all)
            
        }
        .withLocalPop(popManager)
        .sheet(isPresented: $showCreateSheet) {
            CreateAllergyRecordSheet(
                allergyId: allergyId,
                onRecordCreated: {
                    loadRecords()
                }
            )
        }
        .sheet(item: $selectedRecord) { record in
            CreateAllergyRecordSheet(
                allergyId: allergyId,
                record: record,
                onRecordCreated: {
                    loadRecords()
                }
            )
        }
        .onAppear {
            loadRecords()
        }
    }
    
    private func loadRecords() {
        isLoading = true
        currentPage = 1
        allergyRecords = []
        groupedRecords = [:]
        
        let params = AllergyRecordPageParam(
            allergyId: allergyId,
            pageNumber: currentPage,
            pageSize: pageSize
        )
        
        BgResultNetWork<AllergyRecordPageParam, Page<AllergyRecordResponse>>.post(
            apiUrl(ALLERGY_RECORDS_PAGE),
            params: params,
            popManager: popManager
        )
        .complicationHand { (pageInfo: Page<AllergyRecordResponse>?) in
            DispatchQueue.main.async {
                self.isLoading = false
                if let pageInfo = pageInfo {
                    self.totalRecords = pageInfo.total
                    self.allergyRecords = pageInfo.datas
                    self.groupRecordsByYear()
                }
            }
        }
        .responseDecodable()
    }
    
    private func loadMoreRecords() {
        guard hasMoreRecords else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        let params = AllergyRecordPageParam(
            allergyId: allergyId,
            pageNumber: currentPage,
            pageSize: pageSize
        )
        
        BgResultNetWork<AllergyRecordPageParam, Page<AllergyRecordResponse>>.post(
            apiUrl(ALLERGY_RECORDS_PAGE),
            params: params,
            popManager: popManager
        )
        .complicationHand { (pageInfo: Page<AllergyRecordResponse>?) in
            DispatchQueue.main.async {
                self.isLoadingMore = false
                if let pageInfo = pageInfo {
                    self.totalRecords = pageInfo.total
                    self.allergyRecords.append(contentsOf: pageInfo.datas)
                    self.groupRecordsByYear()
                }
            }
        }
        .responseDecodable()
    }
    
    private func refreshRecords() async {
        await MainActor.run {
            loadRecords()
        }
    }
    
    private func deleteRecord(recordId: String) {
        let param = AllergyRecordDeleteParam(id: recordId)
        
        BgResultNetWork<AllergyRecordDeleteParam, Int32>.post(
            apiUrl(ALLERGY_RECORD_DELETE),
            params: param,
            popManager: popManager
        )
        .complicationHand { (response: Int32?) in
            DispatchQueue.main.async {
                self.allergyRecords.removeAll { $0.id == recordId }
                self.groupRecordsByYear()
            }
        }
        .responseDecodable()
    }
}
