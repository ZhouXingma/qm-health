//
//  HealthCurvePlan.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/10/13.
//

import SwiftUI

struct HealthCurvePlan: View {
    // 显示计划表单
    @Binding var showPlanForm:Bool
    // 当前体重
    @State private var currentWeight: String = ""
    // 当前身高
    @State private var currentHeight: String = ""
    // 开始体重（计划开始时的体重）
    @State private var startWeight: String = ""
    // 目标体重
    @State private var targetWeight: String = ""
    // 开始身高（计划开始时的身高）
    @State private var startHeight: String = ""
    // 计划的周数
    @State private var planDuration: Int16?
   
    // 选择的减重计划类型
    @State private var selectedPlanType: HealthCurvePlanType?
    
    // 计划状态：0=失效, 1=有效
    @State private var planStatus:Int16?
    
    // AI生成的计划内容（HTML格式）
    // 用于显示AI为用户制定的专属健康计划
    @State private var aiPlanContent: String?
    
    // 是否显示AI计划预览弹窗
    @State private var showAIPlanPreview: Bool = false
    
    // 当前bmi计算
    private var currentBMI: Double? {
        guard let weight = Double(currentWeight), let height = Double(currentHeight), height > 0 else { return nil }
        return computerBmiValue(height: height, weight: weight)
    }
    // 开始bmi计算
    private var startBMI: Double? {
        guard let weight = Double(startWeight), let height = Double(startHeight), height > 0 else { return nil }
        return computerBmiValue(height: height, weight: weight)
    }
    // 目标bmi计算
    private var targetBMI: Double? {
        guard let weight = Double(targetWeight), let height = Double(startHeight), height > 0 else { return nil }
        return computerBmiValue(height: height, weight: weight)
    }
    // 体重差距
    private var weightDifference: Double? {
        guard let start = Double(startWeight), let target = Double(targetWeight) else { return nil }
        return start - target
    }
    // 一周需要减重大小
    private var weeklyWeightLoss: Double? {
        guard let planDurationValue = planDuration else {
            return nil;
        }
        guard planDurationValue > 0 else { return nil }
        return (weightDifference ?? 0) / Double(planDurationValue)
    }
    // bmi状态
    private var bmiStatus: (text: String, color: Color) {
        guard let startBMIValue = startBMI else {
            return ("", .blue)
        }
       return bimStatusAndColor(bmiValue: startBMIValue)
    }
    // 当前bmi状态
    private var currentBmiStatus: (text: String, color: Color) {
        guard let currentBMIValue = currentBMI else {
            return ("", .blue)
        }
       return bimStatusAndColor(bmiValue: currentBMIValue)
    }
    
    private var lossWeightDifficultyLevel: (text: String, color: Color)? {
        return getLossWeightDifficultyLevel(weeklyWeightLoss)
    }
    
    // 状态显示文本和颜色
    private var statusDisplay: (text: String, color: Color) {
        if planStatus == 1 {
            return ("", Color.clear)
        } else if planStatus == 0 {
            return ("失效", Color("text_secondary"))
        } else {
            return ("", Color.clear)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // 顶部摘要 - 当前状态
                    currentStatusSummary()
                    
                    // 目标进度 - 核心信息
                    goalProgressSection()
                    
                    // 详细数据 - 分组展示
                    detailedDataSection()
                    
                    // 方案信息
                    planInfoSection()
                    
                    // AI健康计划 - 如果存在则显示
                    if aiPlanContent != nil {
                        aiPlanSection()
                    }
                    
                    // 建议
                    recommendationsSection()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color("background").ignoresSafeArea())
        }
        .sheet(isPresented: $showPlanForm) {
            HealthCurveManagePlanFormView(
                height: currentHeight,
                weight: currentWeight,
                saveHandle: { _ in 
                    loadData()
                }
            )
        }
        .onAppear() {
            initData()
            loadData()
        }
        // AI计划预览弹窗
        .sheet(isPresented: $showAIPlanPreview) {
            if let content = aiPlanContent {
                // 使用AIReportPreviewView显示AI生成的计划内容
                AIReportPreviewView(report: AIGeneratedReport(
                    htmlContent: content,
                    conversationId: "",
                    messageId: ""
                ))
            }
        }
    }
    
    // MARK: - 当前状态摘要（顶部简洁展示）
    private func currentStatusSummary() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.theme(.primary))
                Text("当前状态")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                Spacer()
                if currentBmiStatus.text != "" {
                    Chip(text: currentBmiStatus.text, color: currentBmiStatus.color)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            
            HStack(spacing: 16) {
                // 体重
                VStack(alignment: .leading, spacing: 4) {
                    Text("体重")
                        .font(.caption)
                        .foregroundStyle(Color("text_secondary"))
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(currentWeight)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color("text_primary"))
                        Text("kg")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color("text_secondary"))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                    .frame(height: 40)
                
                // BMI
                VStack(alignment: .leading, spacing: 4) {
                    Text("BMI")
                        .font(.caption)
                        .foregroundStyle(Color("text_secondary"))
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        if let currentBMIValue = currentBMI {
                            Text(String(format: "%.1f", currentBMIValue))
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(currentBmiStatus.color)
                        }
                        Text("kg/m²")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color("text_secondary"))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Color.theme(.primary).opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .cardStyle()
    }
    
    // MARK: - 目标进度区（核心信息）
    private func goalProgressSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.theme(.primary))
                Text("减肥目标")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                Chip(text: statusDisplay.text, color: statusDisplay.color)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if let lossWeightDifficulty = lossWeightDifficultyLevel {
                    Chip(text: lossWeightDifficulty.text, color: lossWeightDifficulty.color)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            
            // 进度对比展示
            VStack(spacing: 10) {
                // 从 → 到 的对比
                HStack(spacing: 12) {
                    VStack(alignment: .center, spacing: 4) {
                        Text("初始")
                            .font(.caption)
                            .foregroundStyle(Color("text_secondary"))
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text(startWeight)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Color("text_primary"))
                            Text("kg")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color("text_secondary"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack(alignment: .center, spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.theme(.primary))
                        if let weightDifferenceValue = weightDifference {
                            Text(String(format: "%.1f", weightDifferenceValue))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.theme(.primary))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack(alignment: .center, spacing: 4) {
                        Text("目标")
                            .font(.caption)
                            .foregroundStyle(Color("text_secondary"))
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text(targetWeight)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Color("text_primary"))
                            Text("kg")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color("text_secondary"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(12)
                .background(Color.theme(.primary).opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                // 周期和每周减肥
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.circle.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.orange)
                            Text("计划周期")
                                .font(.caption2)
                                .foregroundStyle(Color("text_secondary"))
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            if let planDurationValue = planDuration {
                                Text("\(planDurationValue)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Color.orange)
                            }
                            Text("周")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color("text_secondary"))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.theme(.primary))
                            Text("每周减肥")
                                .font(.caption2)
                                .foregroundStyle(Color("text_secondary"))
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            if let weeklyWeightLossValue = weeklyWeightLoss {
                                Text(String(format: "%.2f", weeklyWeightLossValue))
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Color.theme(.primary))
                            }
                            Text("kg")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color("text_secondary"))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.theme(.primary).opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }.cardStyle()
    }

    // MARK: - 详细数据区
    private func detailedDataSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.theme(.primary))
                Text("详细数据")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                Chip(text: statusDisplay.text, color: statusDisplay.color)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            
            // BMI 对比
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("初始BMI")
                            .font(.caption2)
                            .foregroundStyle(Color("text_secondary"))
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            if let startBMIValue = startBMI {
                                Text(String(format: "%.1f", startBMIValue))
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.green)
                            }
                            Text("kg/m²")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color("text_secondary"))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("目标BMI")
                            .font(.caption2)
                            .foregroundStyle(Color("text_secondary"))
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            if let targetBMIValue = targetBMI {
                                Text(String(format: "%.1f", targetBMIValue))
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.green)
                            }
                            Text("kg/m²")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color("text_secondary"))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }.cardStyle()
    }
    
    // MARK: - 方案信息区
    private func planInfoSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.theme(.primary))
                Text("减肥方案")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                Chip(text: statusDisplay.text, color: statusDisplay.color)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            
            if let selectedPlanTypeValue = selectedPlanType {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(selectedPlanTypeValue.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color("text_primary"))
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text(selectedPlanTypeValue.weeklyLoss)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(Color.theme(.primary))
                    }
                    Text(selectedPlanTypeValue.description)
                        .font(.caption)
                        .foregroundStyle(Color("text_secondary"))
                        .lineSpacing(2)
                }
                .padding(12)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.theme(.primary).opacity(0.08), Color.theme(.primary).opacity(0.03)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                    Text("未选择方案")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(12)
                .background(Color("divider").opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            
            // 预期完成日期
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.purple)
                    Text("预期完成")
                        .font(.caption2)
                        .foregroundStyle(Color("text_secondary"))
                }
                let completionDate = nil != planDuration ? Calendar.current.date(byAdding: .weekOfYear, value: Int(planDuration!), to: Date()) : nil
                Text(completionDate?.formatted(date: .abbreviated, time: .omitted) ?? "--")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.purple)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.purple.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }.cardStyle()
    }
    
    // MARK: - AI健康计划区
    /// 显示AI生成的健康计划卡片
    /// 点击后打开弹窗查看完整的AI健康计划报告
    private func aiPlanSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.theme(.primary))
                Text("AI健康计划")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                Spacer()
            }
            
            // AI计划卡片 - 点击查看完整内容
            Button(action: {
                showAIPlanPreview = true
            }) {
                HStack(spacing: 16) {
                    // 左侧图标
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.green.opacity(0.15),
                                        Color.green.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.green,
                                        Color.green.opacity(0.7)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    
                    // 右侧信息
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("专属健康计划")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color("text_primary"))
                            
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.green)
                        }
                        
                        Text("点击查看AI为您制定的详细计划")
                            .font(.system(size: 13))
                            .foregroundStyle(Color("text_secondary"))
                    }
                    
                    Spacer()
                    
                    // 右侧箭头
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.green)
                }
                .padding(16)
                .background(Color.green.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.green.opacity(0.2), Color.green.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
            }
        }.cardStyle()
    }
    
    // MARK: - 建议区
    private func recommendationsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.theme(.primary))
                Text("减肥建议")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                recommendationBullet("每周减肥 0.5-1.0 kg 为健康速度，避免过快导致肌肉流失。")
                recommendationBullet("结合有氧运动（如快走、跑步）和力量训练效果更佳。")
                recommendationBullet("保证充足睡眠（7-9 小时）有助于代谢和体重管理。")
                recommendationBullet("定期监测体重，建议每周同一时间、同一地点测量。")
                recommendationBullet("咨询营养师或医生制定个性化饮食和运动计划。")
            }
            .font(.caption)
            .foregroundStyle(Color("text_secondary"))
            .lineSpacing(2)
        }.cardStyle()
    }
    
    private func recommendationBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.theme(.primary))
                .padding(.top, 2)
            Text(text)
        }
    }
    
    
   
    
    
    
    
    
    
    
    // MARK: - 辅助方法
    func initData() {
        let param = UsersHealthIndicatorLastedStatusParam(
            indicatorCodes: ["height","weight"]
        )
        BgResultNetWork<UsersHealthIndicatorLastedStatusParam, [String:UsersHealthIndicatorLastedStatusDTO]>.post(apiUrl(HEALTH_INDICATOR_LAST_STATUS), params: param)
            .complicationHand { (r:[String:UsersHealthIndicatorLastedStatusDTO]?) in
                if let result = r {
                    let heightDto = result["height"];
                    let weightDto = result["weight"];
                    showHeight(heightDto);
                    showWeight(weightDto)
                }
            }.finalHandleFunc{ _ in
                
            }.responseDecodable()
    }
    
    /// 加载计划数据
    /// 从服务器获取健康曲线计划信息，从plan字段中读取AI生成的HTML报告内容
    func loadData() {
        BgResultNetWork<Empty, HealthCurveManagePlanDTO>.post(apiUrl(HEALTH_CURVE_GET), params: Empty())
            .complicationHand({ (r:HealthCurveManagePlanDTO?) in
                if let result = r {
                    // 加载基本计划信息
                    self.startHeight = result.startHeight ?? "";
                    self.startWeight = result.startWeight ?? "";
                    self.targetWeight = result.targetWeight ?? "";
                    self.planDuration = result.planDuration
                    self.planStatus = result.statusCode
                    self.selectedPlanType = HealthCurvePlanType.getByRowValue(result.planType)
                    // 从plan字段中加载AI生成的HTML报告内容
                    // plan字段包含了AI制定的健康计划HTML代码
                    self.aiPlanContent = result.plan
                }
            })
            .responseDecodable()
    }
    // 显示的升高
    func showHeight(_ valueOption : UsersHealthIndicatorLastedStatusDTO?) {
        if let value = valueOption {
            self.currentHeight = value.indicatorValue
        }
    }
    // 显示的体重
    func showWeight(_ valueOption : UsersHealthIndicatorLastedStatusDTO?) {
        if let value = valueOption {
            self.currentWeight = value.indicatorValue
        }
    }
}


#Preview {
    @Previewable @State var a = false;
    HealthCurvePlan(showPlanForm: $a)
}
