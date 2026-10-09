//
//  FamilyHistoryEditView.swift
//  QmHealth
//  家族史编辑页面
//
//  Created by Kiro on 2025/1/28.
//

import SwiftUI

struct FamilyHistoryEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var familyHistory: FamilyHistory?
    @Binding var allHistories: [FamilyHistory]  // 添加所有历史记录的绑定
    var onUpdate: () -> Void
    
    @State private var selectedRelationship: FamilyRelationship = .father
    @State private var diseaseName: String = ""
    @State private var diagnosisAge: Double = 50
    @State private var notes: String = ""
    @State private var showingDeleteAlert = false
    
    private var isEditing: Bool {
        familyHistory != nil
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景渐变
                LinearGradient(
                    colors: [Color("background"), Color("input_bg").opacity(0.3)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 亲属关系选择
                        relationshipSection
                        
                        // 疾病信息
                        diseaseInfoSection
                        
                        // 备注
                        notesSection
                        
                        // 操作按钮
                        actionButtons
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle(isEditing ? "编辑家族史" : "添加家族史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundStyle(Color("text_secondary"))
                }
            }
            .onAppear {
                loadData()
            }
            .alert("确认删除", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    deleteHistory()
                }
            } message: {
                Text("确定要删除这条家族史记录吗？")
            }
        }
        .sheetAppBackground()
        .presentationDragIndicator(.hidden)
    }

    // MARK: - 亲属关系选择
    private var relationshipSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(icon: "person.2.fill", title: "亲属关系")
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                ForEach(FamilyRelationship.allCases, id: \.self) { relationship in
                    CompactRelationshipCard(
                        relationship: relationship,
                        isSelected: selectedRelationship == relationship
                    ) {
                        selectedRelationship = relationship
                    }
                }
            }
        }
    }
    
    // MARK: - 疾病信息
    private var diseaseInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(icon: "cross.case.fill", title: "疾病信息")
            
            VStack(spacing: 16) {
                // 疾病名称
                VStack(alignment: .leading, spacing: 8) {
                    Text("疾病名称")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color("text_primary"))
                    
                    TextField("请输入疾病名称", text: $diseaseName)
                        .inputFieldStyle()
                }
                
                // 诊断年龄 - 滑动选择器
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("诊断年龄")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color("text_primary"))
                        
                        Spacer()
                        
                        Text("\(Int(diagnosisAge)) 岁")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .glassPill(.regular.interactive().tint(Color.theme(.primary)))
                    }
                    
                    // 滑动条
                    VStack(spacing: 8) {
                        Slider(value: $diagnosisAge, in: 0...120, step: 1)
                            .tint(Color.theme(.primary))
                        
                        // 刻度标签
                        HStack {
                            Text("0岁")
                                .font(.system(size: 11))
                                .foregroundStyle(Color("text_secondary"))
                            Spacer()
                            Text("30岁")
                                .font(.system(size: 11))
                                .foregroundStyle(Color("text_secondary"))
                            Spacer()
                            Text("60岁")
                                .font(.system(size: 11))
                                .foregroundStyle(Color("text_secondary"))
                            Spacer()
                            Text("90岁")
                                .font(.system(size: 11))
                                .foregroundStyle(Color("text_secondary"))
                            Spacer()
                            Text("120岁")
                                .font(.system(size: 11))
                                .foregroundStyle(Color("text_secondary"))
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .cardStyle()
        }
    }
    
    // MARK: - 备注
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(icon: "note.text", title: "备注")
            
            TextEditor(text: $notes)
                .frame(height: 100)
                .padding(8)
        }.cardStyle()
    }
    
    // MARK: - 操作按钮
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // 保存按钮（占满剩余宽度）
            Button {
                saveHistory()
            } label: {
                Text(isEditing ? "保存修改" : "添加")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(diseaseName.isEmpty ? AppColor.textSecondary: AppColor.primary)
                    .frame(maxWidth: .infinity)
            }
            .disabled(diseaseName.isEmpty)
            .buttonStyle(SecondaryActionButtonStyle())

            // 删除按钮（仅编辑时显示，较小）
            if isEditing {
                Button {
                    showingDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColor.error)
                        
                }.buttonStyle(SecondaryActionButtonStyle())
                    .frame(width: 60)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - 数据处理
    private func loadData() {
        if let history = familyHistory {
            if let rel = history.relationship,
               let relationship = FamilyRelationship.getByCode(code: rel) {
                selectedRelationship = relationship
            }
            diseaseName = history.diseaseName ?? ""
            diagnosisAge = Double(history.diagnosisAge ?? 50)
            notes = history.notes ?? ""
        }
    }
    
    private func saveHistory() {
        let age = Int(diagnosisAge)
        
        // 创建或更新当前记录
        let newHistory = FamilyHistory(
            id: familyHistory?.id ?? UUID().uuidString,  // 如果是新记录，生成临时ID
            userId: GlobalModel.shared.currentUser?.id,
            relationship: selectedRelationship.rawValue,
            relationshipName: selectedRelationship.displayName,
            diseaseName: diseaseName,
            diagnosisAge: age,
            notes: notes.isEmpty ? nil : notes,
            gmtCreate: familyHistory?.gmtCreate ?? DateUtils.formatDate(Date(), format: DateUtils.DateFormat.ymdhms),
            gmtModified: DateUtils.formatDate(Date(), format: DateUtils.DateFormat.ymdhms)
        )
        
        // 更新本地列表
        var updatedHistories = allHistories
        if let existingId = familyHistory?.id,
           let index = updatedHistories.firstIndex(where: { $0.id == existingId }) {
            // 更新现有记录
            updatedHistories[index] = newHistory
        } else {
            // 添加新记录
            updatedHistories.append(newHistory)
        }
        
        // 保存到后端
        saveFamilyHistoriesToBackend(histories: updatedHistories)
    }
    
    private func deleteHistory() {
        guard let historyId = familyHistory?.id else { return }
        
        // 从本地列表中删除
        let updatedHistories = allHistories.filter { $0.id != historyId }
        
        // 保存到后端（删除也是通过保存更新后的列表实现）
        saveFamilyHistoriesToBackend(histories: updatedHistories)
    }
    
    private func saveFamilyHistoriesToBackend(histories: [FamilyHistory]) {
        guard let saveParam = FamilyHistorySaveParam.from(histories: histories) else {
            print("转换家族史数据失败")
            return
        }
        
        let metaDataParam = saveParam.toMetaDataAddParam()
        
        BgResultNetWork<MetaDataAddParam, String>
            .post(apiUrl(METADATA_ADD_UPDATE), params: metaDataParam)
            .complicationHand { (result: String?) in
                print("保存家族史成功：\(result ?? "")")
                onUpdate()
                dismiss()
            }
            .responseDecodable()
    }
}

// MARK: - 子组件
struct CompactRelationshipCard: View {
    let relationship: FamilyRelationship
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(relationship.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                
                Text(relationship.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? .white : Color("text_primary"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .appGlass(
                isSelected ? Glass.regular.interactive().tint(Color(relationship.group.color)) : Glass.regular.interactive(),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RelationshipCard: View {
    let relationship: FamilyRelationship
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(relationship.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                
                Text(relationship.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? .white : Color("text_primary"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isSelected ?
                    Color(relationship.group.color) :
                    Color(relationship.group.color).opacity(0.1)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color(relationship.group.color) : Color("divider"),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SectionTitle: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.theme(.primary))
            
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color("text_primary"))
        }
    }
}

#Preview {
    @State var history: FamilyHistory? = nil
    @State var allHistories: [FamilyHistory] = []
    return FamilyHistoryEditView(
        familyHistory: $history,
        allHistories: $allHistories,
        onUpdate: {}
    )
}
