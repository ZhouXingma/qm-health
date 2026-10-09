//
//  DiseaseInfoTabView.swift
//  QmHealth
//  当前疾病
// 
//  Created by 周荥马 on 2025/9/15.
//

import SwiftUI

struct DiseaseInfoTabView: View {
    //@StateObject private var diseaseManager = DiseaseManager()
    @State private var showingDiseaseDetail = false
    @State private var selectedDisease: DiseaseInfo?
    @State private var diseaseList:[DiseaseInfo]  = []
    
    var body: some View {
        VStack(spacing: 12) {
            // 标题行
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color("error"))
                Text("疾病信息")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                Spacer()
                
                // 统计信息
                if !diseaseList.isEmpty {
                    HStack(spacing: 4) {
                        Text("\(diseaseList.count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.theme(.primary))
                        Text("项")
                            .font(.system(size: 10))
                            .foregroundStyle(Color("text_secondary"))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.theme(.primary).opacity(0.1))
                    .cornerRadius(8)
                }
                
                Button(action: {
                    selectedDisease = nil
                    showingDiseaseDetail = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.theme(.primary))
                }
            }
            
            if diseaseList.isEmpty {
                // 空状态
                VStack(spacing: 8) {
                    Image(systemName: "heart.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(Color("text_secondary"))
                    Text("暂无疾病记录")
                        .font(.system(size: 16))
                        .foregroundStyle(Color("text_secondary"))
                    
                    Button("添加疾病信息") {
                        selectedDisease = nil
                        showingDiseaseDetail = true
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(Color.theme(.primary))
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    HFlow(alignment: .top) {
                        ForEach(diseaseList, id: \.self.id) { disease in
                            DiseaseTag(
                                disease: disease,
                                onTap: {
                                    selectedDisease = disease
                                    showingDiseaseDetail = true
                                }
                            )
                        }
                    }
                }
            }
            HStack {
                ForEach(DiseaseSeverity.allCases, id:\.self) { item in
                    HStack {
                        Circle()
                            .fill(item.color)
                            .frame(width: 10,height: 10)
                        Text(item.displayName)
                            .font(.system(size: 12, weight: .black))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .cardStyle()
        .onAppear() {
            initData()
        }
        .sheet(isPresented: $showingDiseaseDetail) {
            DiseaseDetailEditView(
                diseaseInfo: $selectedDisease,
                onUpdate: {
                    loadDiseases()
                }
            )
        }
    }
    
    // MARK: - 子组件
    // 疾病标签
    struct DiseaseTag: View {
        let disease: DiseaseInfo
        let onTap: () -> Void
        var diseaseSeverity:DiseaseSeverity {
            if let severity = disease.severity {
                return DiseaseSeverity.getByCode(code:severity) ?? DiseaseSeverity.mild;
            }
            return DiseaseSeverity.mild;
        }
        var diseaseStatus:DiseaseStatus {
            if let status = disease.status {
                return DiseaseStatus.getByCode(code:status) ?? DiseaseStatus.stable;
            }
            return DiseaseStatus.stable;
        }
        var body: some View {
            Button {
                onTap()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: diseaseSeverity.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(diseaseSeverity.color)
                    
                    Text(disease.name ?? "")
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    
                    // 状态指示器
                    Circle()
                        .fill(Color(diseaseStatus.color))
                        .frame(width: 6, height: 6)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: 1)
                        )
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(diseaseSeverity.color.opacity(0.1)))
                        .stroke(diseaseSeverity.color.opacity(0.3), lineWidth: 1)
                }.padding(2)
            }.buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - 辅助方法
    /// 初始化数据
    func initData() {
        loadDiseases()
    }
    
    // 加载疾病信息
    private func loadDiseases() {
        BgResultNetWork<Empty, [DiseaseInfo]>.post(apiUrl(DISEASE_LIST_NOT_RECOVERED), params: nil)
            .complicationHand { (diseaseInfosOptions:[DiseaseInfo]?) in
                if let infos = diseaseInfosOptions {
                    self.diseaseList = infos
                } else {
                    self.diseaseList = []
                }
            }.responseDecodable()
    }
}

#Preview {
    DiseaseInfoTabView()
}
