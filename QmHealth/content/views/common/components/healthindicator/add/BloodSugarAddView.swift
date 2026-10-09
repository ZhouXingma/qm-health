//
//  血糖添加页面
//  BloodSugarAddView.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/11/29.
//

import SwiftUI

struct BloodSugarAddView: View {
    // 血糖默认值
    var bloodSugarDefaultValue: Double?
    // 血糖配置信息
    var bloodSugarConfig: UsersHealthIndicatorConfigurationInfo?
    // 步宽
    var step: Double = 1
    // 保存操作
    var onSave: ((UsersHealthIndicatorAddParam) -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @State private var measureDate: Date = Date()
    @State private var bloodSugar: Double = 0
    @State private var saveHandling = false
    @State private var selectedTimeLabel: HealthIndicatorTimeLabel = BizCommonFunctions.getDefaultHealthIndicatorTimeLabel()
    @State private var hasInitializedDefaultValue = false
    
    // 获取血糖范围
    private var minValue: Double {
        bloodSugarConfig?.minValue ?? 0
    }
    private var maxValue: Double {
        bloodSugarConfig?.maxValue ?? 600
    }
    
    // 获取数值格式
    private var valueFormate: String {
        bloodSugarConfig?.valueFormate ?? "%.1f"
    }
    
    init(
        bloodSugarDefaultValue: Double? = nil,
        bloodSugarConfig: UsersHealthIndicatorConfigurationInfo? = nil,
        step: Double = 1,
        onSave: ((UsersHealthIndicatorAddParam) -> Void)? = nil
    ) {
        self.bloodSugarDefaultValue = bloodSugarDefaultValue
        self.bloodSugarConfig = bloodSugarConfig
        self.step = step
        self.onSave = onSave
        _bloodSugar = State(initialValue: bloodSugarDefaultValue ?? 100)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            SheetHeader(title: "添加血糖")
                .padding(.bottom, 24)
            
            // Content
            VStack(spacing: 20) {
                ScrollView(.vertical, showsIndicators: false) {
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

                    // 时间标签卡片
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.theme(.primary))
                            Text("测量时段")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color("text_secondary"))
                        }

                        // 时间标签选择
                        VStack(spacing: 10) {
                            ForEach(0..<(HealthIndicatorTimeLabel.allCases.count + 1) / 3, id: \.self) { rowIndex in
                                HStack(spacing: 10) {
                                    ForEach(0..<3, id: \.self) { colIndex in
                                        let index = rowIndex * 3 + colIndex
                                        if index < HealthIndicatorTimeLabel.allCases.count {
                                            let timeLabel = HealthIndicatorTimeLabel.allCases[index]
                                            Button(action: { selectedTimeLabel = timeLabel }) {
                                                Text(timeLabel.displayName)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .frame(maxWidth: .infinity)
                                                    .foregroundStyle(selectedTimeLabel == timeLabel ? .white : AppColor.textPrimary)
                                            }
                                            .buttonStyle(SecondaryActionButtonStyle(tintColor: selectedTimeLabel == timeLabel ? AppColor.primary : Color.clear, cornerRadius: AppRadius.medium))
                                        } else {
                                            Color.clear
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()

                    // 血糖输入卡片
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.theme(.primary))
                            Text("血糖输入")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color("text_secondary"))
                        }

                        // 血糖数值输入
                        VStack(alignment: .leading, spacing: 8) {
                            Text("血糖值")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color("text_secondary"))

                            VStack(spacing: 12) {
                                HStack(spacing: 8) {
                                    Button(action: { if bloodSugar > minValue { bloodSugar -= step } }) {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(Color.theme(.primary))
                                    }
                                    .appGlass(.regular.interactive(), in: Circle()) {
                                        Circle().fill(AppColor.content.opacity(0.6))
                                    }

                                    VStack(spacing: 4) {
                                        Text(String(format: valueFormate, bloodSugar))
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(Color.theme(.primary))
                                        Text("mg/dL")
                                            .font(.system(size: 11))
                                            .foregroundColor(Color("text_secondary"))
                                    }
                                    .frame(maxWidth: .infinity)

                                    Button(action: { if bloodSugar < maxValue { bloodSugar += step } }) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(Color.theme(.primary))
                                    }
                                    .appGlass(.regular.interactive(), in: Circle()) {
                                        Circle().fill(AppColor.content.opacity(0.6))
                                    }
                                }

                                CaliperRuler(
                                    value: $bloodSugar,
                                    minValue: minValue,
                                    maxValue: maxValue,
                                    step: step
                                )
                            }
                        }
                        .padding(12)
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: AppRadius.medium))
                    }
                    .cardStyle()
                }
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
        .onAppear {
            // 仅在未初始化且没有提供有效默认值时加载
            if !hasInitializedDefaultValue && (bloodSugarDefaultValue == nil || bloodSugarDefaultValue == 100) {
                loadLatestBloodSugarValue()
            }
            hasInitializedDefaultValue = true
        }
    }
    
    private func save() {
        if saveHandling {
            return
        }
        saveHandling = true
        
        let bloodSugarParam = UsersHealthIndicatorAddParam(
            indicatorCode: "blood_sugar",
            indicatorValue: String(format: valueFormate, bloodSugar),
            measureTime: measureDate,
            label: 1,
            otherLabel: Int16(selectedTimeLabel.rawValue)
        )
        
        BgResultNetWork<[UsersHealthIndicatorAddParam], [String]>.post(apiUrl(HEALTH_INDICATOR_ADD), params: [bloodSugarParam])
            .complicationHand { (v: [String]?) in
                DispatchQueue.main.async {
                    onSave?(bloodSugarParam)
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
    
    private func loadLatestBloodSugarValue() {
        let params = UsersHealthIndicatorLastParam(indicatorCodes: ["blood_sugar"])
        
        BgResultNetWork<UsersHealthIndicatorLastParam, [String: HealthIndicatorInfoDTO]>.post(
            apiUrl(HEALTH_INDICATOR_LAST),
            params: params
        )
        .complicationHand { (data: [String: HealthIndicatorInfoDTO]?) in
            DispatchQueue.main.async {
                if let indicators = data,
                   let indicator = indicators["blood_sugar"],
                   let valueStr = indicator.indicatorValue,
                   let doubleValue = Double(valueStr) {
                    bloodSugar = doubleValue
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
    BloodSugarAddView(
        bloodSugarDefaultValue: 100
    )
}
