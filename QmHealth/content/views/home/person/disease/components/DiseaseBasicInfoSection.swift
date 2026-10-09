//
//  DiseaseBasicInfoSection.swift
//  QmHealth
//  疾病基本信息区域组件
//
//  Created by 周荥马 on 2025/10/2.
//

import SwiftUI

struct DiseaseBasicInfoSection: View {
    @ObservedObject var diseaseEditorInfo: DiseaseEditorInfo
    var subPopManager: SubPopManager
    
    var body: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "基本信息", icon: "info.circle.fill")
            
            VStack(spacing: 12) {
                // 疾病名称
                InputField(
                    title: "疾病名称",
                    text: $diseaseEditorInfo.name,
                    placeholder: "请输入疾病名称",
                    icon: "cross.case.fill"
                )
                
                // 首诊时间
                DatePickerField(
                    title: "首诊时间",
                    date: $diseaseEditorInfo.firstVisitTime,
                    icon: "calendar.badge.clock",
                    allowFuture: false,
                    selectDate: diseaseEditorInfo.followupVisitTime ?? DateUtils.formatDate(Date(), format: DateUtils.DateFormat.ymd),
                    subPopManager: subPopManager
                )
                
                // 疾病严重程度
                PickerField(
                    title: "严重程度",
                    selection: $diseaseEditorInfo.severity,
                    options: DiseaseSeverity.allCases,
                    icon: "exclamationmark.triangle.fill"
                ) { severity in
                    HStack {
                        Image(systemName: severity.icon)
                            .foregroundStyle(Color(severity.color))
                        Text(severity.displayName)
                    }
                }
                
                // 当前状态
                PickerField(
                    title: "当前状态",
                    selection: $diseaseEditorInfo.status,
                    options: DiseaseStatus.allCases,
                    icon: "heart.text.square"
                ) { status in
                    HStack {
                        Image(systemName: status.icon)
                            .foregroundStyle(Color(status.color))
                        Text(status.displayName)
                    }
                }
            }
        }
        .cardStyle()
    }
}
