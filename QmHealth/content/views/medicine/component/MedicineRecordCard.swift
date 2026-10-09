//
//  MedicineRecordCard.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/12/8.
//

import SwiftUI

// MARK: - 用药记录卡片
struct MedicineRecordCard: View {
    let record: MedicineRecord
    
    var body: some View {
        HStack(spacing: 12) {
            // 药品图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.theme(.primary).opacity(0.15), Color.theme(.secondary).opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Image(systemName: "pills.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.theme(.primary), Color.theme(.secondary)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // 药品信息
            VStack(alignment: .leading, spacing: 6) {
                Text(record.medicineName ?? "未知药品")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("text_primary"))
                
                HStack(spacing: 10) {
                    if !record.specificationString.isEmpty {
                        Label {
                            Text(record.specificationString)
                        } icon: {
                            Image(systemName: "cross.vial")
                                .font(.system(size: 11))
                        }
                        .font(.system(size: 12))
                        .foregroundColor(Color("text_secondary"))
                        .labelStyle(CompactLabelStyle())
                    }
                    
                    if !record.doseString.isEmpty {
                        Label {
                            Text(record.doseString)
                        } icon: {
                            Image(systemName: "pills")
                                .font(.system(size: 11))
                        }
                        .font(.system(size: 12))
                        .foregroundColor(Color("text_secondary"))
                        .labelStyle(CompactLabelStyle())
                    }
                    
                    if !record.timeString.isEmpty {
                        Label {
                            Text(record.timeString)
                        } icon: {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                        }
                        .font(.system(size: 12))
                        .foregroundColor(Color("text_secondary"))
                        .labelStyle(CompactLabelStyle())
                    }
                }
                
                // 显示备注和副作用（如果有）
                if let remarks = record.remarks, !remarks.isEmpty {
                    Text(remarks)
                        .font(.system(size: 11))
                        .foregroundColor(Color("text_secondary").opacity(0.7))
                        .lineLimit(1)
                }
                
                if let adverseReactions = record.adverseReactions, !adverseReactions.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color("warning"))
                        Text(adverseReactions)
                            .font(.system(size: 11))
                            .foregroundColor(Color("warning"))
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
        }.cardStyle()
    }
}
