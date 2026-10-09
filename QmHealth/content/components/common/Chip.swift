//
//  Chip.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/10/15.
//

import SwiftUI

struct Chip: View {
    var text: String
    var color: Color
    var body: some View {
        Text(text)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}

#Preview {
    Chip(text: "正常", color: .green).font(.system(.caption))
}
