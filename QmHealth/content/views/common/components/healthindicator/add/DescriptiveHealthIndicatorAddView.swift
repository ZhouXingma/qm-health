//  描述性类型的健康指标添加页面
//  DescriptiveHealthIndicatorAddView.swift
//  QmHealth
//
//  Created by AI on 2025/12/02.

import SwiftUI

struct DescriptiveHealthIndicatorAddView: View {
    // 指标编码
    var indicatorCode: String = ""
    // 指标名称
    var indicatorName: String = ""
    // 默认描述（例如最近一次记录的值）
    var defaultText: String?
    // 保存操作
    var onSave: ((UsersHealthIndicatorAddParam) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var measureDate: Date = Date()
    @State private var descriptionText: String = ""
    @State private var saveHandling = false

    init(
        indicatorCode: String = "",
        indicatorName: String = "",
        defaultText: String? = nil,
        onSave: ((UsersHealthIndicatorAddParam) -> Void)? = nil
    ) {
        self.indicatorCode = indicatorCode
        self.indicatorName = indicatorName
        self.defaultText = defaultText
        self.onSave = onSave

        _descriptionText = State(initialValue: defaultText ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            SheetHeader(title: "添加\(indicatorName)")
                .padding(.bottom, 24)

            // Content
            VStack(spacing: 20) {
                // 测量时间卡片
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.theme(.primary))
                        Text("测量时间")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color("text_secondary"))
                    }

                    DatePicker("", selection: $measureDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .tint(Color.theme(.primary))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()

                // 描述输入卡片
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.theme(.primary))
                        Text("文字说明")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color("text_secondary"))
                    }

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $descriptionText)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 140)
                            .padding(8)
                            .appGlass(.clear.tint(AppColor.content.opacity(0.1)),
                                      in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                           

                        if descriptionText.isEmpty {
                            Text("请输入详细的描述信息，例如检查结果、医生建议等")
                                .font(.system(size: 13))
                                .foregroundColor(Color("text_secondary").opacity(0.6))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                        }
                    }
                }
                .cardStyle()
            }
            .padding(.horizontal, 20)

            Spacer()

            // 操作按钮
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("取消")
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Button {
                    save()
                } label: {
                    ZStack(alignment: .center) {
                        if saveHandling {
                            ProgressView().tint(.white)
                        }
                        Text("保存")
                            .opacity(saveHandling ? 0 : 1)
                    }.foregroundStyle(AppColor.primary)
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .withGlobalPop()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("background"))
    }

    private func save() {
        if saveHandling {
            return
        }
        let text = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return
        }
        saveHandling = true

        let dto = UsersHealthIndicatorAddParam(
            indicatorCode: indicatorCode,
            indicatorValue: text,
            measureTime: measureDate,
            label: 1
        )

        BgResultNetWork<[UsersHealthIndicatorAddParam], [String]>.post(apiUrl(HEALTH_INDICATOR_ADD), params: [dto])
            .complicationHand { (v: [String]?) in
                DispatchQueue.main.async {
                    onSave?(dto)
                    dismiss()
                }
            }
            .finalHandleFunc { _ in
                DispatchQueue.main.async {
                    self.saveHandling = false
                }
            }
            .responseDecodable()
    }
}

#Preview {
    DescriptiveHealthIndicatorAddView(
        indicatorCode: "desc_test",
        indicatorName: "描述性示例",
        defaultText: "这是上一次的检查结果描述。\n可以在这里继续编辑或覆盖。"
    )
}
