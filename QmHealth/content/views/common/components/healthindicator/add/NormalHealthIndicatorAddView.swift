//
//  定量-常规的健康指标添加页面
//  NormalHealthIndicatorAddView.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/11/13.
//

import SwiftUI

struct NormalHealthIndicatorAddView: View {
    // 指标编码
    var indicatorCode: String = ""
    // 指标名称
    var indicatorName: String = ""
    // 单位
    var unit: String = ""
    // 最小值
    var minValue: Double = 0
    // 最大值
    var maxValue: Double = 100
    // 步宽
    var step: Double = 0.1
    // 默认值
    var defaultValue: Double?
    // 单位
    var valueFormate: String = "%.1f"
    // 保存操作
    var onSave: ((UsersHealthIndicatorAddParam) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var measureDate: Date = Date()
    @State private var value: Double = 0
    // 正在保存处理
    @State private var saveHandleing = false
    // 是否已初始化默认值
    @State private var hasInitializedDefaultValue = false
    

    init(
        indicatorCode: String = "",
        indicatorName: String = "",
        unit: String = "",
        minValue: Double = 0,
        maxValue: Double = 100,
        step: Double = 0.1,
        defaultValue: Double? = nil,
        valueFormate:String = "%.1f",
        onSave: ((UsersHealthIndicatorAddParam) -> Void)? = nil
    ) {
        self.indicatorCode = indicatorCode
        self.indicatorName = indicatorName
        self.unit = unit
        self.minValue = minValue
        self.maxValue = maxValue
        self.step = step
        self.defaultValue = defaultValue
        self.valueFormate = valueFormate
        self.onSave = onSave
        _value = State(initialValue: defaultValue ?? minValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            SheetHeader(title:"添加\(indicatorName)")
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

                // 数值输入卡片
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.theme(.primary))
                        Text("数值输入")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color("text_secondary"))
                    }

                    VStack(spacing: 16) {
                        EditableValueDisplay(
                            value: $value,
                            unit: self.unit,
                            minValue: self.minValue,
                            maxValue: self.maxValue,
                            step: self.step,
                            valueFormate: self.valueFormate
                        )

                        CaliperRuler(
                            value: $value,
                            minValue: self.minValue,
                            maxValue: self.maxValue,
                            step: self.step
                        )
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
                        if saveHandleing {
                            ProgressView().tint(.white)
                        }
                        Text("保存")
                            .opacity(saveHandleing ? 0 : 1)
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
        .onAppear {
            // 仅在未初始化且没有提供有效默认值时加载
            if !hasInitializedDefaultValue && (defaultValue == nil || defaultValue == minValue) {
                loadLatestIndicatorValue()
            }
            hasInitializedDefaultValue = true
        }
    }

    func formatted(_ v: Double) -> String {
        return String(format: valueFormate, v)
    }

    func save() {
        if self.saveHandleing {
            return
        }
        self.saveHandleing = true;
        let dto = UsersHealthIndicatorAddParam(indicatorCode: indicatorCode, indicatorValue: formatted(value), measureTime: measureDate, label: 1)
        BgResultNetWork<[UsersHealthIndicatorAddParam],[String]>.post(apiUrl(HEALTH_INDICATOR_ADD), params: [dto])
            .complicationHand({ (v:[String]?) in
                DispatchQueue.main.async {
                    onSave?(dto);
                    dismiss()
                }
            })
            .finalHandleFunc({ _ in
                DispatchQueue.main.async {
                    self.saveHandleing = false
                }
            })
            .responseDecodable()
        
    }
    
    func loadLatestIndicatorValue() {
        let params = UsersHealthIndicatorLastParam(indicatorCodes: [indicatorCode])
        
        BgResultNetWork<UsersHealthIndicatorLastParam, [String: HealthIndicatorInfoDTO]>.post(
            apiUrl(HEALTH_INDICATOR_LAST),
            params: params
        )
        .complicationHand { (data: [String: HealthIndicatorInfoDTO]?) in
            DispatchQueue.main.async {
                if let indicators = data,
                   let indicator = indicators[indicatorCode],
                   let valueStr = indicator.indicatorValue,
                   let doubleValue = Double(valueStr) {
                    value = doubleValue
                }
            }
        }
        .errorHandle { _, error in
            // 加载失败时保持当前值，不做任何处理
        }
        .responseDecodable()
    }
}

#Preview {
    NormalHealthIndicatorAddView(
        indicatorCode: "height",
        indicatorName: "身高",
        unit: "cm",
        minValue: 50,
        maxValue: 280,
        step: 0.1,
        defaultValue: 170
    )
}
