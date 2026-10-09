//
//  CreateAllergyRecordSheet.swift
//  QmHealth
//  添加/编辑过敏记录
//
//  Created by 周荥马 on 2026/3/27.
//

import SwiftUI

struct CreateAllergyRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    var allergyId: String
    var record: AllergyRecordResponse? = nil
    var onRecordCreated: (() -> Void)? = nil
    
    @ObservedObject private var recordInfo = AllergyRecordEditorInfo()
    @StateObject private var popManager = PopManager()
    
    @State private var selectedDate = Date()
    @State private var showDatePicker = false
    
    var isEditMode: Bool {
        record != nil
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // 发作时间
                    VStack(alignment: .leading, spacing: 8) {
                        Text("发作时间")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color("text_secondary"))
                        
                        Button {
                            showDatePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(Color.theme(.primary))
                                Text(recordInfo.onsetTime.isEmpty ? "选择时间" : recordInfo.onsetTime)
                                    .foregroundColor(recordInfo.onsetTime.isEmpty ? Color("text_secondary") : Color("text_primary"))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Color("text_secondary"))
                            }
                            .inputFieldStyle()
                            
                        }
                    }
                    .cardStyle()

                    // 症状
                    VStack(alignment: .leading, spacing: 8) {
                        Text("症状")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color("text_secondary"))
                        TextEditor(text: $recordInfo.symptoms)
                            .font(.system(size: 14))
                            .frame(minHeight: 80)
                    }
                    .cardStyle()

                    // 严重程度
                    VStack(alignment: .leading, spacing: 12) {
                        Text("严重程度")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color("text_secondary"))
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(AllergySeverity.allCases, id: \.self) { item in
                                let isSelected = recordInfo.severity == item.rawValue
                                Button {
                                    recordInfo.severity = item.rawValue
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: item.icon)
                                            .font(.system(size: 12))
                                        Text(item.displayName)
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .glassPill(isSelected ? Glass.regular.interactive().tint(item.color) : Glass.regular.interactive())
                                    .foregroundStyle(isSelected ? .white : Color(item.color))
                                }
                            }
                        }
                    }
                    .cardStyle()

                    // 治疗方法
                    VStack(alignment: .leading, spacing: 8) {
                        Text("治疗方法")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color("text_secondary"))
                        TextEditor(text: $recordInfo.treatmentMethod)
                            .font(.system(size: 14))
                            .frame(minHeight: 80)
                    }
                    .cardStyle()

                    // 备注
                    VStack(alignment: .leading, spacing: 8) {
                        Text("备注")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color("text_secondary"))
                        TextEditor(text: $recordInfo.remarks)
                            .font(.system(size: 14))
                            .frame(minHeight: 80)
                    }
                    .cardStyle()

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .background(Color("background"))
            .navigationTitle(isEditMode ? "编辑过敏记录" : "添加过敏记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundStyle(Color("text_secondary"))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveRecord()
                    }
                    .foregroundStyle(Color.theme(.primary))
                    .fontWeight(.semibold)
                    .disabled(recordInfo.onsetTime.isEmpty || recordInfo.symptoms.isEmpty)
                }
            }
        }
        .sheetAppBackground()
        .sheet(isPresented: $showDatePicker) {
            DateTimePickerSheet(
                selectedDateTime: $recordInfo.onsetTime,
                isPresented: $showDatePicker
            )
        }
        .withLocalPop(popManager)
        .onAppear {
            recordInfo.allergyId = allergyId
            if let record = record {
                initEditData(record)
            }
        }
    }
    
    private func initEditData(_ record: AllergyRecordResponse) {
        recordInfo.id = record.id
        recordInfo.allergyId = record.allergyId ?? allergyId
        recordInfo.onsetTime = record.onsetTime ?? ""
        recordInfo.symptoms = record.symptoms ?? ""
        recordInfo.severity = record.severity ?? 1
        recordInfo.treatmentMethod = record.treatmentMethod ?? ""
        recordInfo.remarks = record.remarks ?? ""
    }
    
    private func saveRecord() {
        let param = AllergyRecordSaveParam(
            id: recordInfo.id.isEmpty ? nil : recordInfo.id,
            allergyId: recordInfo.allergyId,
            onsetTime: recordInfo.onsetTime,
            symptoms: recordInfo.symptoms,
            severity: recordInfo.severity,
            treatmentMethod: recordInfo.treatmentMethod,
            remarks: recordInfo.remarks
        )
        
        BgResultNetWork<AllergyRecordSaveParam, String>.post(
            apiUrl(ALLERGY_RECORD_SAVEORUPDATE),
            params: param,
            popManager: popManager
        )
        .complicationHand { (response: String?) in
            DispatchQueue.main.async {
                onRecordCreated?()
                dismiss()
            }
        }
        .responseDecodable()
    }
}
