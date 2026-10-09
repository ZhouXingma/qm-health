//
//  HelpFeedbackView.swift
//  QmHealth
//
//  帮助与反馈页面
//

import SwiftUI

struct HelpFeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    // 顶部引导卡片
                    introCard

                    // FAQ 分类
                    ForEach(HelpFAQData.categories) { category in
                        FAQCategorySection(category: category)
                    }

                    // 反馈入口
                    feedbackSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .pageBackground()
            .navigationTitle("帮助与反馈")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                            Text("关闭")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(Color.theme(.primary))
                    }
                }
            }
        }
    }

    // MARK: - 顶部引导
    private var introCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.theme(.primary).opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: "questionmark.bubble.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color.theme(.primary))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("您好，需要什么帮助？")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color("text_primary"))
                Text("下列是您最常遇到的问题，如未解决请通过反馈入口联系我们。")
                    .font(.system(size: 12))
                    .foregroundColor(Color("text_secondary"))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColor.content)
        )
        .appShadow(AppShadow.card)
    }

    // MARK: - 反馈入口
    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.theme(.primary))
                Text("问题仍未解决？")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color("text_primary"))
            }
            .padding(.leading, 4)

            VStack(spacing: 0) {
                FeedbackRow(
                    icon: "exclamationmark.bubble.fill",
                    title: "提交问题反馈",
                    subtitle: "描述您遇到的故障或建议"
                )
                Divider().padding(.leading, 56)
                FeedbackRow(
                    icon: "ant.fill",
                    title: "反馈 Bug",
                    subtitle: "应用崩溃、显示异常、功能错误"
                )
                Divider().padding(.leading, 56)
                FeedbackRow(
                    icon: "lightbulb.fill",
                    title: "功能建议",
                    subtitle: "您希望新增或改进的功能"
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColor.content)
            )
            .appShadow(AppShadow.card)
        }
    }
}

// MARK: - FAQ 分类区块
private struct FAQCategorySection: View {
    let category: FAQCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(category.tint.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: category.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(category.tint)
                }

                Text(category.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("text_primary"))

                Spacer()

                Text("\(category.items.count) 项")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color("text_secondary"))
            }
            .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(category.items.enumerated()), id: \.element.id) { index, item in
                    FAQItemRow(item: item)
                    if index < category.items.count - 1 {
                        Divider().padding(.leading, 50)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColor.content)
            )
            .appShadow(AppShadow.card)
        }
    }
}

// MARK: - FAQ 单条问题
private struct FAQItemRow: View {
    let item: FAQItem
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isExpanded ? "minus.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(isExpanded ? Color.theme(.primary) : Color("text_secondary"))

                    Text(item.question)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color("text_primary"))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color("text_secondary").opacity(0.6))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                Text(item.answer)
                    .font(.system(size: 13))
                    .foregroundColor(Color("text_secondary"))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - 反馈入口行
private struct FeedbackRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        Button {
            // TODO: 接入反馈收集
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.theme(.primary).opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.theme(.primary))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color("text_primary"))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(Color("text_secondary"))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color("text_secondary").opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    HelpFeedbackView()
}