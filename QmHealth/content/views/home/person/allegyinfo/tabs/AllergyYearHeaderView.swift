//
//  AllergyYearHeaderView.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/3/27.
//

import SwiftUI

struct AllergyYearHeaderView: View {
    let year: String

    var body: some View {
        HStack {
            Text(year)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color("text_primary"))

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
