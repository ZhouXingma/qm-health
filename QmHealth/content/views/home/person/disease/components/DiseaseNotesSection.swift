//
//  DiseaseNotesSection.swift
//  QmHealth
//  疾病备注信息区域组件
//
//  Created by 周荥马 on 2025/10/2.
//

import SwiftUI

struct DiseaseNotesSection: View {
    @ObservedObject var diseaseEditorInfo: DiseaseEditorInfo
    
    var body: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "备注信息", icon: "note.text")
            
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $diseaseEditorInfo.remarks)
                    .frame(minHeight: 60)
                    .font(.system(size: 14))
            }
        }
        .cardStyle()
    }
}
