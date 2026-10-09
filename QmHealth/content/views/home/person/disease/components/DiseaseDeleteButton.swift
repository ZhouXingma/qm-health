//
//  DiseaseDeleteButton.swift
//  QmHealth
//  疾病删除按钮组件
//
//  Created by 周荥马 on 2025/10/2.
//

import SwiftUI

struct DiseaseDeleteButton: View {
    var isNewDisease: Bool
    var onDelete: () -> Void
    
    var body: some View {
        VStack {
            if !isNewDisease {
                Button {
                    onDelete()
                } label: {
                    HStack {
                        Text("删除")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(Color(.red))
                    .padding(.horizontal, 30)
                }.buttonStyle(SecondaryActionButtonStyle())
            }
        }
    }
}
