//
//  Common.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/6/21.
//
import SwiftUI
// MARK: - 自定义输入框组件
/// 通用的输入框组件，包含图标、标题和输入框
struct CustomTextField: View {
    let icon: String
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(Color.theme(.primary).opacity(0.7))
                    .frame(width: 14)
                
                TextField(placeholder.isEmpty ? title : placeholder, text: $text)
                    .font(.system(size: 14))
            }.inputFieldStyle()
        }
    }
}
