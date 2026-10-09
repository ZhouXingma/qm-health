//
//  血压添加页面
//  BloodPressureAddView.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/11/29.
//

import SwiftUI

struct BloodPressureAddView: View {
    // 收缩压默认值
    var systolicDefaultValue: Double?
    // 舒张压默认值
    var diastolicDefaultValue: Double?
    // 血压配置信息
    var systolicConfig: UsersHealthIndicatorConfigurationInfo?
    var diastolicConfig: UsersHealthIndicatorConfigurationInfo?
    // 步宽
    var systolicStep: Double = 1
    var diastolicStep: Double = 1
    // 保存操作
    var onSave: ((UsersHealthIndicatorAddParam, UsersHealthIndicatorAddParam) -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @State private var measureDate: Date = Date()
    @State private var systolic: Double = 0
    @State private var diastolic: Double = 0
    @State private var saveHandling = false
    @State private var selectedTimeLabel: HealthIndicatorTimeLabel = BizCommonFunctions.getDefaultHealthIndicatorTimeLabel()
    
    // 血压状态
    private var bloodPressureStatus: BloodPressureStatus {
        return BloodPressureStatus.getStatus(systolic: Int(systolic), diastolic: Int(diastolic))
    }
    
    // 获取收缩压范围
    private var systolicMinValue: Double {
        systolicConfig?.minValue ?? 60
    }
    private var systolicMaxValue: Double {
        systolicConfig?.maxValue ?? 200
    }
    
    // 获取舒张压范围
    private var diastolicMinValue: Double {
        diastolicConfig?.minValue ?? 40
    }
    private var diastolicMaxValue: Double {
        diastolicConfig?.maxValue ?? 130
    }
    
    // 获取数值格式
    private var valueFormate: String {
        systolicConfig?.valueFormate ?? "%.0f"
    }
    
    init(
        systolicDefaultValue: Double? = nil,
        diastolicDefaultValue: Double? = nil,
        systolicConfig: UsersHealthIndicatorConfigurationInfo? = nil,
        diastolicConfig: UsersHealthIndicatorConfigurationInfo? = nil,
        systolicStep: Double = 1,
        diastolicStep: Double = 1,
        onSave: ((UsersHealthIndicatorAddParam, UsersHealthIndicatorAddParam) -> Void)? = nil
    ) {
        self.systolicDefaultValue = systolicDefaultValue
        self.diastolicDefaultValue = diastolicDefaultValue
        self.systolicConfig = systolicConfig
        self.diastolicConfig = diastolicConfig
        self.systolicStep = systolicStep
        self.diastolicStep = diastolicStep
        self.onSave = onSave
        _systolic = State(initialValue: systolicDefaultValue ?? 120)
        _diastolic = State(initialValue: diastolicDefaultValue ?? 80)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            SheetHeader(title: "添加血压")
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

                ScrollView(.vertical, showsIndicators: false) {
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

                    // 血压输入卡片
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.theme(.primary))
                            Text("血压输入")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color("text_secondary"))
                        }

                        // 血压状态指示
                        HStack(spacing: 12) {
                            Circle()
                                .fill(bloodPressureStatus.color)
                                .frame(width: 12, height: 12)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(bloodPressureStatus.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color("text_primary"))

                                Text(bloodPressureStatus.description)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color("text_secondary"))
                            }

                            Spacer()
                        }
                        .padding(12)
                        .appGlass(.regular.tint(bloodPressureStatus.color.opacity(0.5)),
                                  in: RoundedRectangle(cornerRadius: 10, style: .continuous)) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                        }

                        // 收缩压和舒张压输入
                        HStack(spacing: 12) {
                            // 收缩压
                            VStack(alignment: .leading, spacing: 8) {
                                Text("收缩压")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color("text_secondary"))

                                VStack(spacing: 12) {
                                    HStack(spacing: 8) {
                                        Button(action: { if systolic > systolicMinValue { systolic -= systolicStep } }) {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.system(size: 22))
                                                .foregroundColor(Color.theme(.primary))
                                        }
                                        .appGlass(.regular.interactive(), in: Circle()) {
                                            Circle().fill(AppColor.content.opacity(0.6))
                                        }

                                        VStack(spacing: 4) {
                                            Text(String(format: valueFormate, systolic))
                                                .font(.system(size: 24, weight: .bold))
                                                .foregroundColor(Color.theme(.primary))
                                            Text("mmHg")
                                                .font(.system(size: 11))
                                                .foregroundColor(Color("text_secondary"))
                                        }
                                        .frame(maxWidth: .infinity)

                                        Button(action: { if systolic < systolicMaxValue { systolic += systolicStep } }) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 22))
                                                .foregroundColor(Color.theme(.primary))
                                        }
                                        .appGlass(.regular.interactive(), in: Circle()) {
                                            Circle().fill(AppColor.content.opacity(0.6))
                                        }
                                    }

                                    Slider(value: $systolic, in: systolicMinValue...systolicMaxValue, step: systolicStep)
                                        .tint(Color.theme(.primary))
                                }
                            }
                            .glassCardStyle()

                            // 舒张压
                            VStack(alignment: .leading, spacing: 8) {
                                Text("舒张压")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color("text_secondary"))

                                VStack(spacing: 12) {
                                    HStack(spacing: 8) {
                                        Button(action: { if diastolic > diastolicMinValue { diastolic -= diastolicStep } }) {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.system(size: 22))
                                                .foregroundColor(Color.theme(.primary))
                                        }
                                        .appGlass(.regular.interactive(), in: Circle()) {
                                            Circle().fill(AppColor.content.opacity(0.6))
                                        }

                                        VStack(spacing: 4) {
                                            Text(String(format: valueFormate, diastolic))
                                                .font(.system(size: 24, weight: .bold))
                                                .foregroundColor(Color.theme(.primary))
                                            Text("mmHg")
                                                .font(.system(size: 11))
                                                .foregroundColor(Color("text_secondary"))
                                        }
                                        .frame(maxWidth: .infinity)

                                        Button(action: { if diastolic < diastolicMaxValue { diastolic += diastolicStep } }) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 22))
                                                .foregroundColor(Color.theme(.primary))
                                        }
                                        .appGlass(.regular.interactive(), in: Circle()) {
                                            Circle().fill(AppColor.content.opacity(0.6))
                                        }
                                    }

                                    Slider(value: $diastolic, in: diastolicMinValue...diastolicMaxValue, step: diastolicStep)
                                        .tint(Color.theme(.primary))
                                }
                            }
                            .glassCardStyle()
                        }
                    }.cardStyle()
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
    }
    
    private func save() {
        if saveHandling {
            return
        }
        saveHandling = true
        
        let systolicParam = UsersHealthIndicatorAddParam(
            indicatorCode: "systolic",
            indicatorValue: String(format: "%.0f", systolic),
            measureTime: measureDate,
            label: 1,
            otherLabel: Int16(selectedTimeLabel.rawValue)
        )
        
        let diastolicParam = UsersHealthIndicatorAddParam(
            indicatorCode: "diastolic",
            indicatorValue: String(format: "%.0f", diastolic),
            measureTime: measureDate,
            label: 1,
            otherLabel: Int16(selectedTimeLabel.rawValue)
        )
        
        BgResultNetWork<[UsersHealthIndicatorAddParam], [String]>.post(apiUrl(HEALTH_INDICATOR_ADD), params: [systolicParam, diastolicParam])
            .complicationHand { (v: [String]?) in
                DispatchQueue.main.async {
                    onSave?(systolicParam, diastolicParam)
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

// MARK: - 血压状态
enum BloodPressureStatus {
    case optimal        // 最佳
    case normal         // 正常
    case elevated       // 升高
    case stage1         // 1级高血压
    case stage2         // 2级高血压
    case crisis         // 高血压危象
    
    var title: String {
        switch self {
        case .optimal: return "最佳血压"
        case .normal: return "正常血压"
        case .elevated: return "升高血压"
        case .stage1: return "1级高血压"
        case .stage2: return "2级高血压"
        case .crisis: return "高血压危象"
        }
    }
    
    var description: String {
        switch self {
        case .optimal: return "收缩压 < 120 且舒张压 < 80"
        case .normal: return "收缩压 120-129 且舒张压 < 80"
        case .elevated: return "收缩压 130-139 或舒张压 80-89"
        case .stage1: return "收缩压 140-159 或舒张压 90-99"
        case .stage2: return "收缩压 ≥ 160 或舒张压 ≥ 100"
        case .crisis: return "收缩压 > 180 或舒张压 > 120"
        }
    }
    
    var color: Color {
        switch self {
        case .optimal: return Color(red: 0.2, green: 0.8, blue: 0.4)     // 绿色
        case .normal: return Color(red: 0.4, green: 0.8, blue: 0.2)      // 浅绿
        case .elevated: return Color(red: 1.0, green: 0.8, blue: 0.2)    // 黄色
        case .stage1: return Color(red: 1.0, green: 0.6, blue: 0.2)      // 橙色
        case .stage2: return Color(red: 1.0, green: 0.4, blue: 0.2)      // 深橙
        case .crisis: return Color(red: 1.0, green: 0.2, blue: 0.2)      // 红色
        }
    }
    
    static func getStatus(systolic: Int, diastolic: Int) -> BloodPressureStatus {
        if systolic > 180 || diastolic > 120 {
            return .crisis
        } else if systolic >= 160 || diastolic >= 100 {
            return .stage2
        } else if systolic >= 140 || diastolic >= 90 {
            return .stage1
        } else if systolic >= 130 || diastolic >= 80 {
            return .elevated
        } else if systolic >= 120 {
            return .normal
        } else {
            return .optimal
        }
    }
}

#Preview {
    BloodPressureAddView(
        systolicDefaultValue: 120,
        diastolicDefaultValue: 80
    )
}
