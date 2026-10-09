//  定性类型的健康指标添加页面
//  QualitativeHealthIndicatorAddView.swift
//  QmHealth
//
//  Created by AI on 2025/12/02.

import SwiftUI

struct QualitativeHealthIndicatorAddView: View {
    // 指标编码
    var indicatorCode: String = ""
    // 指标名称
    var indicatorName: String = ""
    // 可选值域
    var valueScope: [String] = []
    // 默认值（例如最近一次记录的值）
    var defaultValue: String?
    // 保存操作
    var onSave: ((UsersHealthIndicatorAddParam) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var measureDate: Date = Date()
    @State private var selectedValue: String = ""
    @State private var saveHandling = false

    init(
        indicatorCode: String = "",
        indicatorName: String = "",
        valueScope: [String] = [],
        defaultValue: String? = nil,
        onSave: ((UsersHealthIndicatorAddParam) -> Void)? = nil
    ) {
        self.indicatorCode = indicatorCode
        self.indicatorName = indicatorName
        self.valueScope = valueScope
        self.defaultValue = defaultValue
        self.onSave = onSave

        let initial: String
        if let dv = defaultValue, !dv.isEmpty, valueScope.contains(dv) {
            initial = dv
        } else {
            initial = valueScope.first ?? ""
        }
        _selectedValue = State(initialValue: initial)
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

                // 定性选项卡片
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "text.badge.checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.theme(.primary))
                        Text("结果选择")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color("text_secondary"))
                    }

                    if valueScope.isEmpty {
                        Text("暂无可选结果，请检查配置")
                            .font(.system(size: 13))
                            .foregroundColor(Color("text_secondary"))
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(valueScope, id: \.self) { value in
                                    Button(action: { selectedValue = value }) {
                                        HStack {
                                            Text(value)
                                                .font(.system(size: 14, weight: .medium))
                                                .lineLimit(1)
                                            Spacer()
                                            if selectedValue == value {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(AppColor.primary)
                                            }
                                        }
                                        .padding(.horizontal, AppRadius.large)
                                    }
                                    .buttonStyle(SecondaryActionButtonStyle(tintColor: AppColor.content.opacity(0.5)))
                                }
                            }
                        }
                    }
                }.frame(maxWidth: .infinity)
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
                    }
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
        if selectedValue.isEmpty {
            return
        }
        saveHandling = true

        let dto = UsersHealthIndicatorAddParam(
            indicatorCode: indicatorCode,
            indicatorValue: selectedValue,
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
    QualitativeHealthIndicatorAddView(
        indicatorCode: "qualitative_test",
        indicatorName: "定性示例",
        valueScope: ["阴性", "阳性", "弱阳性"],
        defaultValue: "阴性"
    )
}
