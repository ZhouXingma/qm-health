//
//  AllergyRecordCard.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/3/27.
//

import SwiftUI

struct AllergyRecordCard: View {
    let record: AllergyRecordResponse
    
    var severityInfo: (icon: String, name: String, color: Color)? {
        guard let severity = record.severity else { return nil }
        let allergyLevel = AllergySeverity(rawValue: severity)
        guard let level = allergyLevel else { return nil }
        return (
            icon: level.icon,
            name: level.displayName,
            color: level.color
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 头部：发作时间 + 严重程度
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("发作时间")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color("text_secondary"))
                    Text(formatDateTime(record.onsetTime ?? "-"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color("text_primary"))
                }
                
                Spacer()
                
                if let severity = severityInfo {
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("严重程度")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color("text_secondary"))
                        
                        HStack(spacing: 6) {
                            Image(systemName: severity.icon)
                                .font(.system(size: 13, weight: .semibold))
                            Text(severity.name)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .glassPill(.regular.interactive().tint(severity.color))
                    }
                }
            }
            // 内容区域
            VStack(alignment: .leading, spacing: 12) {
                // 症状
                if let symptoms = record.symptoms, !symptoms.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color("warning"))
                            .padding(.top, 2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("症状")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color("text_secondary"))
                            Text(symptoms)
                                .font(.system(size: 13))
                                .foregroundColor(Color("text_primary"))
                                .lineLimit(2)
                        }
                        
                        Spacer()
                    }
                }
                
                // 治疗方法
                if let treatment = record.treatmentMethod, !treatment.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "pills.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.theme(.primary))
                            .padding(.top, 2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("治疗方法")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color("text_secondary"))
                            Text(treatment)
                                .font(.system(size: 13))
                                .foregroundColor(Color("text_primary"))
                                .lineLimit(2)
                        }
                        
                        Spacer()
                    }
                }
                
                // 备注
                if let remarks = record.remarks, !remarks.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "note.text")
                            .font(.system(size: 14))
                            .foregroundColor(Color.theme(.secondary))
                            .padding(.top, 2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("备注")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color("text_secondary"))
                            Text(remarks)
                                .font(.system(size: 13))
                                .foregroundColor(Color("text_primary"))
                                .lineLimit(2)
                        }
                        
                        Spacer()
                    }
                }
            }
            .glassCardStyle(.regular.interactive().tint(AppColor.content.opacity(0.5)))
            .padding(.top, 10)
        }.cardStyle()
    }
    
    private func formatDateTime(_ dateTime: String) -> String {
        let components = dateTime.split(separator: " ")
        return components.count >= 1 ? String(components[0]) : dateTime
    }
}
