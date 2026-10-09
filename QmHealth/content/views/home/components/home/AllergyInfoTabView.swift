//
//  AllergyInfoTabView.swift
//  QmHealth
//  过敏源
//
//  Created by 周荥马 on 2025/9/15.
//

import SwiftUI

struct AllergyInfoTabView: View {
    @State var showingAllegyInfoDetail: Bool = false;
    @State private var allergies: [UserAllergy] = []
    // 选择的过敏源
    @State private var selectedAllergy: UserAllergy? = nil
    
    var body: some View {
        VStack(spacing: 12) {
            // 标题行
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color("warning"))
                Text("过敏源")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                Spacer()
                // 统计信息
                if !allergies.isEmpty {
                    HStack(spacing: 4) {
                        Text("\(allergies.count)")
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
                    selectedAllergy = nil
                    showingAllegyInfoDetail = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.theme(.primary))
                }
            }
            
            if allergies.isEmpty {
                // 空状态
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 24))
                        .foregroundStyle(Color("text_secondary"))
                    Text("暂无过敏记录")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("text_secondary"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 过敏源列表
                ScrollView(.vertical, showsIndicators: false) {
                    HFlow {
                        ForEach(allergies, id: \.name) { allergy in
                            AllergyTag(userAllergy: allergy, onTap: {
                                selectedAllergy = allergy
                                showingAllegyInfoDetail = true
                            })
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            HStack {
                ForEach(AllergySeverity.allCases, id:\.self) { item in
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
        .sheet(isPresented: $showingAllegyInfoDetail) {
            AllergyInfoEditSheet(
                userAllergy: $selectedAllergy,
                onUpdate: {
                    loadUserAllegyInfo()
                }
            )
        }
    }
    
    
    // 过敏源标签
    struct AllergyTag: View {
        let userAllergy: UserAllergy
        let onTap: () -> Void
        
        var body: some View {
            let allergySeverity = AllergySeverity.getByCode(code: userAllergy.severity ?? 1) ?? AllergySeverity.mild;
            Button {
                onTap()
            } label: {
                HStack(spacing: 6) {
                    // 过敏源名称
                    HStack(spacing: 4) {
                        Image(systemName: allergySeverity.icon)
                            .font(.system(size: 13))
                            .foregroundStyle(allergySeverity.color)
                        Text(userAllergy.name ?? "")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color("text_primary"))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(allergySeverity.color.opacity(0.1))
                        .stroke(allergySeverity.color.opacity(0.3), lineWidth: 1)
                }
                .padding(2)
            }
        }
    }
    
    // MARK: -  辅助方法
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

#Preview {
    AllergyInfoTabView()
}
