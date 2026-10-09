//
//  CompactLabelStyle.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/12/8.
//

import SwiftUI

// MARK: - Compact Label Style
struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
            configuration.title
        }
    }
}
