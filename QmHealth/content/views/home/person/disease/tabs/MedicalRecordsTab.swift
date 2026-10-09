//
//  MedicalRecordsTab.swift
//  QmHealth
//  就诊记录标签页
//
//  Created by 周荥马 on 2025/10/2.
//

import SwiftUI

struct MedicalRecordsTab: View {
    var diseaseId: String?
    
    @State private var medicalRecords: [MedicalVisitResponse] = []
    @State private var groupedRecords: [String: [MedicalVisitResponse]] = [:]
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var currentPage: Int16 = 1
    @State private var pageSize: Int16 = 10
    @State private var totalRecords: Int64 = 0
    @StateObject private var popManager = PopManager()
    @State private var selectedRecord: MedicalVisitResponse? = nil
    
    var hasMoreRecords: Bool {
        Int64(medicalRecords.count) < totalRecords
    }
    
    private func groupRecordsByYear() {
        groupedRecords = Dictionary(grouping: medicalRecords, by: { $0.year })
    }

    // 按 id 去重，避免同一记录重复渲染导致 ForEach ID 冲突
    private func deduplicate(_ records: [MedicalVisitResponse]) -> [MedicalVisitResponse] {
        var seen = Set<String>()
        return records.filter { seen.insert($0.id).inserted }
    }
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(Color.theme(.primary))
                    Text("加载中...")
                        .font(.system(size: 14))
                        .foregroundColor(Color("text_secondary"))
                }
            } else if medicalRecords.isEmpty {
                EmptyStateView(
                    icon: "doc.text.magnifyingglass",
                    message: "暂无就诊记录",
                )
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8, pinnedViews: [.sectionHeaders]) {
                        if groupedRecords.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 48))
                                    .foregroundColor(Color("text_primary"))
                                Text("暂无就诊记录")
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
                                            MedicalVisitCard(record: record)
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
                                    YearHeaderView(year: year)
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
        .withLocalPop(popManager)
        .sheet(item: $selectedRecord) { record in
            CreateMedicalRecordView(
                recordId: record.id,
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
        guard let diseaseId = diseaseId else { return }
        
        isLoading = true
        currentPage = 1
        medicalRecords = []
        groupedRecords = [:]
        
        let params = MedicalVisitPageByDiseaseParam(
            diseaseId: diseaseId,
            pageNumber: currentPage,
            pageSize: pageSize
        )
        
        BgResultNetWork<MedicalVisitPageByDiseaseParam, Page<MedicalVisitResponse>>.post(
            apiUrl(MEDICALVISIT_PAGE_BY_DISEASE),
            params: params,
            popManager: popManager
        )
        .complicationHand {(pageInfo: Page<MedicalVisitResponse>?) in
            DispatchQueue.main.async {
                self.isLoading = false
                if let pageInfo = pageInfo {
                    self.totalRecords = pageInfo.total
                    self.medicalRecords = self.deduplicate(pageInfo.datas)
                    self.groupRecordsByYear()
                }
            }
        }
        .responseDecodable()
    }
    
    private func loadMoreRecords() {
        guard let diseaseId = diseaseId, hasMoreRecords else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        let params = MedicalVisitPageByDiseaseParam(
            diseaseId: diseaseId,
            pageNumber: currentPage,
            pageSize: pageSize
        )
        
        BgResultNetWork<MedicalVisitPageByDiseaseParam, Page<MedicalVisitResponse>>.post(
            apiUrl(MEDICALVISIT_PAGE_BY_DISEASE),
            params: params,
            popManager: popManager
        )
        .complicationHand { (pageInfo: Page<MedicalVisitResponse>?) in
            DispatchQueue.main.async {
                self.isLoadingMore = false
                if let pageInfo = pageInfo {
                    self.totalRecords = pageInfo.total
                    self.medicalRecords.append(contentsOf: pageInfo.datas)
                    self.medicalRecords = self.deduplicate(self.medicalRecords)
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
        let param = MedicalVisitDetailParam(id: recordId)
        
        BgResultNetWork<MedicalVisitDetailParam, Int32>.post(
            apiUrl(MEDICALVISIT_DELETE),
            params: param,
            popManager: popManager
        )
        .complicationHand {(response: Int32?) in
            DispatchQueue.main.async {
                self.medicalRecords.removeAll { $0.id == recordId }
                self.groupRecordsByYear()
            }
        }
        .responseDecodable()
    }
}
