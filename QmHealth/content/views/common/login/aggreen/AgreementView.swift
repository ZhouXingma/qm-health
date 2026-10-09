//
//  AgreementView.swift
//  QmHealth
//
//  协议展示页面
//

import SwiftUI

struct AgreementView: View {
    @Environment(\.dismiss) private var dismiss
    let type: AgreementType

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.regular) {
                    Text(type.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, AppSpacing.compact)

                    Text("最后更新日：\(type.updateDate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, AppSpacing.compact)

                    Divider()

                    ForEach(Array(type.sections.enumerated()), id: \.element.id) { index, section in
                        AgreementSectionView(section: section)
                    }

                    Text("— 协议正文结束 —")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, AppSpacing.regular)
                }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.bottom, AppSpacing.card)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .fontWeight(.medium)
                }
            }
        }
    }
}

private struct AgreementSectionView: View {
    let section: AgreementSection

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            Text(section.heading)
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.top, AppSpacing.compact)

            ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    AgreementView(type: .userAgreement)
}

#Preview {
    AgreementView(type: .privacyPolicy)
}