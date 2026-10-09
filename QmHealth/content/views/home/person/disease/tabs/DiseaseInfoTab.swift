//
//  DiseaseInfoTab.swift
//  QmHealth
//  疾病信息标签页 - 查看/编辑疾病
//
//  Created by 周荥马 on 2025/10/2.
//

import SwiftUI

struct DiseaseInfoTab: View {
    @ObservedObject var diseaseEditorInfo: DiseaseEditorInfo
    var isNewDisease: Bool
    var subPopManager: SubPopManager
    var onDelete: () -> Void
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // 基本信息卡片
                DiseaseBasicInfoSection(
                    diseaseEditorInfo: diseaseEditorInfo,
                    subPopManager: subPopManager
                )
                
                // 诊断信息卡片
                DiseaseDiagnosisInfoSection(
                    diseaseEditorInfo: diseaseEditorInfo,
                    subPopManager: subPopManager
                )
                
                // 治疗方案卡片
                DiseaseTreatmentSection(diseaseEditorInfo: diseaseEditorInfo)
                
                // 备注信息卡片
                DiseaseNotesSection(diseaseEditorInfo: diseaseEditorInfo)
                
                // 删除按钮
                DiseaseDeleteButton(
                    isNewDisease: isNewDisease,
                    onDelete: onDelete
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color("background"))
    }
}
