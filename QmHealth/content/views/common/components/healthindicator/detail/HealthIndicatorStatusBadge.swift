//
//  HealthIndicatorStatusBadge.swift
//  QmHealth
//
//  历史记录行状态标记：正常绿、偏高/偏低/异常/检出红、未检出灰，无状态不显示
//  颜色与 HealthIndicatorCard 一致，取 HealthStatus.color
//

import SwiftUI

struct HealthIndicatorStatusBadge: View {
    let indicatorStatus: Int16?

    var body: some View {
        let status = HealthStatus.getHealthStatus(indicatorStatus: indicatorStatus)
        if status != .none {
            Text(status.text)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(status.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .glassPillColor(.clear.interactive(), status.color.opacity(0.2))
        }
    }
}