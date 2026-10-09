//
//  HealthIndicatorCard.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/12/03.
//

import SwiftUI

struct HealthIndicatorCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let status: HealthStatus
    let color: Color
    let otherLabel: String?
    let measureTime: String?
    let referenceRange: String?
    
    init(icon: String, title: String, value: String, unit: String, status: HealthStatus, color: Color, otherLabel: String? = nil, measureTime: String? = nil, referenceRange: String? = nil) {
        self.icon = icon
        self.title = title
        self.value = value
        self.unit = unit
        self.status = status
        self.color = color
        self.otherLabel = otherLabel
        self.measureTime = measureTime
        self.referenceRange = referenceRange
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
                if status != .none {
                    Text(status.text)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(status.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .glassPillColor(.clear.interactive(), status.color.opacity(0.18))
                }
            }
            Spacer()
            // 数值和单位
            HStack(alignment: .bottom, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .lineLimit(1, reservesSpace: true)
                    .foregroundStyle(status.textColor)
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundStyle(Color("text_secondary"))
                    .padding(.bottom, 2)
                Spacer()
            }
            Spacer()
            // 参考范围（单独一行）
            if let range = referenceRange, !range.isEmpty {
                Text("参考: \(range)")
                    .font(.system(size: 8))
                    .foregroundStyle(Color("text_secondary"))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
    HealthIndicatorCard(
        icon: "heart.fill",
        title: "血压",
        value: "120/80",
        unit: "mmHg",
        status: .normal,
        color: .red,
        otherLabel: "空腹",
        measureTime: "2025-12-03 10:30:00",
        referenceRange: "90-140/60-90"
    )
}
