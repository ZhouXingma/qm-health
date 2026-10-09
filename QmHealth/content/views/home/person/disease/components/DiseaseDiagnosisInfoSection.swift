//
//  DiseaseDiagnosisInfoSection.swift
//  QmHealth
//  疾病诊断信息区域组件
//
//  Created by 周荥马 on 2025/10/2.
//

import SwiftUI

struct DiseaseDiagnosisInfoSection: View {
    @ObservedObject var diseaseEditorInfo: DiseaseEditorInfo
    var subPopManager: SubPopManager
    
    var body: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "诊断信息", icon: "stethoscope")
            
            VStack(spacing: 12) {
                // 主治医生
                InputField(
                    title: "主治医生",
                    text: $diseaseEditorInfo.doctor,
                    placeholder: "请输入医生姓名",
                    icon: "person.fill.badge.plus"
                )
                
                // 就诊医院
                InputField(
                    title: "就诊医院",
                    text: $diseaseEditorInfo.hospital,
                    placeholder: "请输入医院名称",
                    icon: "building.2.fill"
                )
                
                // 下次复诊时间
                DatePickerField(
                    title: "下次复诊",
                    date: $diseaseEditorInfo.followupVisitTime,
                    icon: "calendar.badge.plus",
                    allowFuture: true,
                    selectDate: diseaseEditorInfo.followupVisitTime ?? DateUtils.formatDate(Date(), format: DateUtils.DateFormat.ymd),
                    subPopManager: subPopManager
                )
            }
        }
        .cardStyle()
    }
}
