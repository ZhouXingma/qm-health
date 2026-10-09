//
//  AllergyInfoTab.swift
//  QmHealth
//  过敏信息编辑标签页
//
//  Created by 周荥马 on 2025/10/12.
//

import SwiftUI

struct AllergyInfoTab: View {
    @ObservedObject var allergyEditorInfo: AllergyEditorInfo
    var isNewAllergyInfo: Bool
    var onDelete: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 名称
                CustomTextField(icon: "tag.fill", title: "过敏源名称", text: $allergyEditorInfo.name, placeholder: "如：花粉、海鲜、青霉素")
                    .cardStyle()
                
                // 过敏程度
                VStack(alignment: .leading, spacing: 12) {
                    Text("过敏程度")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color("text_secondary"))
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(AllergySeverity.allCases, id: \.self) { item in
                            let isSelected = allergyEditorInfo.severity == item.rawValue
                            Button {
                                allergyEditorInfo.severity = item.rawValue
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 12))
                                    Text(item.displayName)
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .glassPill(isSelected ? Glass.regular.interactive().tint(item.color) : Glass.regular.interactive())
                                .foregroundStyle(isSelected ? .white : Color(item.color))
                            }
                        }
                    }
                }
                .cardStyle()

                // 治疗/缓解方案
                VStack(alignment: .leading, spacing: 8) {
                    Text("治疗/缓解方案")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color("text_secondary"))
                    TextEditor(text: $allergyEditorInfo.treatment)
                        .font(.system(size: 14))
                        .frame(minHeight: 90)
                }
                .cardStyle()

                // 备注
                VStack(alignment: .leading, spacing: 8) {
                    Text("备注")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color("text_secondary"))
                    TextEditor(text: $allergyEditorInfo.remarks)
                        .font(.system(size: 14))
                        .frame(minHeight: 80)
                }
                .cardStyle()

                // 删除按钮
                if !isNewAllergyInfo {
                    Button {
                        onDelete()
                    } label: {
                        HStack {
                            Text("删除")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(Color(.red))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 30)
                    }.buttonStyle(SecondaryActionButtonStyle())
                }
                
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(Color("background"))
    }
}
