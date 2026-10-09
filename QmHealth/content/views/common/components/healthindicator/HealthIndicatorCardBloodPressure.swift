//
//  HealthIndicatorCard.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/12/03.
//

import SwiftUI

struct HealthIndicatorCardBloodPressure: View {
    let icon: String
    let title: String
    let systolic: String
    let diastolic: String
    let unit: String
    let systolicStatus: HealthStatus
    let diastolicStatus: HealthStatus
    let color: Color
    let otherLabel: String?
    let measureTime: String?
    let systolicReferenceRange: String?
    let diastolicReferenceRange: String?
    
    init(icon: String, title: String, systolic: String, diastolic: String, unit: String, systolicStatus: HealthStatus, diastolicStatus:HealthStatus, color: Color, otherLabel: String? = nil, measureTime: String? = nil, systolicReferenceRange: String? = nil, diastolicReferenceRange: String? = nil) {
        self.icon = icon
        self.title = title
        self.systolic = systolic
        self.diastolic = diastolic
        self.unit = unit
        self.systolicStatus = systolicStatus
        self.diastolicStatus = diastolicStatus
        self.color = color
        self.otherLabel = otherLabel
        self.measureTime = measureTime
        self.systolicReferenceRange = systolicReferenceRange
        self.diastolicReferenceRange = diastolicReferenceRange
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // 图标和状态
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color("text_secondary"))
                Spacer()
            }
            Spacer()
            // 数值和单位
            HStack(alignment: .bottom, spacing: 2) {
                Text(systolic)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(systolicStatus.textColor)
                Text("/")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color("text_secondary"))
                Text(diastolic)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(diastolicStatus.textColor)
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundStyle(Color("text_secondary"))
                    .padding(.bottom, 2)
                Spacer()
            }
            Spacer()
            // 参考范围（单独一行）
            if let range = systolicReferenceRange, !range.isEmpty, let range1 = diastolicReferenceRange, !range1.isEmpty{
                HStack {
                    Text("参考:")
                        .font(.system(size: 8))
                        .foregroundStyle(Color("text_secondary"))
                        .lineLimit(1)
                    if let range = systolicReferenceRange, !range.isEmpty {
                        Text("\(range)")
                            .font(.system(size: 8))
                            .foregroundStyle(Color("text_secondary"))
                            .lineLimit(1)
                    }
                    Text("/")
                        .font(.system(size: 8))
                        .foregroundStyle(Color("text_secondary"))
                        .lineLimit(1)
                    if let range = diastolicReferenceRange, !range.isEmpty {
                        Text("\(range)")
                            .font(.system(size: 8))
                            .foregroundStyle(Color("text_secondary"))
                            .lineLimit(1)
                    }
                    Spacer()
                    
                }
            }
            // 时间和标签
            HStack(alignment: .bottom, spacing: 2) {
                if let time = measureTime {
                    Text(formatMeasureTime(time))
                        .font(.system(size: 8))
                        .foregroundStyle(Color("text_secondary"))
                }
                Spacer()
                if let label = otherLabel {
                    Text(label)
                        .font(.system(size: 8))
                        .foregroundStyle(Color("text_secondary"))
                }
                
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 60)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .glassContainer(.clear.interactive(), cornerRadius: 12)
    }
    
    private func formatMeasureTime(_ time: String) -> String {
        // 格式化时间，如果是 "2025-11-21 20:51:27" 格式，显示为 "2025-11-21"
        let components = time.split(separator: " ")
        if components.count >= 1 {
            return String(components[0])
        }
        return time
    }
}

#Preview {
    HealthIndicatorCardBloodPressure(
        icon: "heart.fill",
        title: "血压",
        systolic: "120",
        diastolic: "80",
        unit: "mmHg",
        systolicStatus: .normal,
        diastolicStatus: .low,
        color: .red,
        otherLabel: "空腹",
        measureTime: "2025-12-03 10:30:00",
        systolicReferenceRange: "90-140",
        diastolicReferenceRange: "60-90"
    )
}
