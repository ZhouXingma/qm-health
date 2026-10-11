//
//  HealthIndicatorReferenceRange.swift
//  QmHealth
//
//  历史记录行参考范围标记：存在参考范围时展示，为空则不显示
//

import SwiftUI

struct HealthIndicatorReferenceRange: View {
    let referenceRange: String?

    var body: some View {
        if let range = referenceRange, !range.isEmpty {
            Text("参考: \(range)")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

#Preview {
    VStack(alignment: .trailing, spacing: 8) {
        HealthIndicatorReferenceRange(referenceRange: "3.9-6.1")
        HealthIndicatorReferenceRange(referenceRange: nil)
    }
}
