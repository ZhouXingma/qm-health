//
//  DiseaseTreatmentSection.swift
//  QmHealth
//  疾病治疗方案区域组件
//
//  Created by 周荥马 on 2025/10/2.
//

import SwiftUI

struct DiseaseTreatmentSection: View {
    @ObservedObject var diseaseEditorInfo: DiseaseEditorInfo
    
    var body: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "治疗方案", icon: "medical.thermometer.fill")
            
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $diseaseEditorInfo.treatment)
                    .font(.system(size: 14))
                    .frame(minHeight: 80)
            }
        }
        .cardStyle()
    }
}
