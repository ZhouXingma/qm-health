//
//  HealthCurveManagePlanFormView.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/11/15.
//

import SwiftUI

struct HealthCurveManagePlanFormView: View {
    @Environment(\.dismiss) private var dismiss
    var height:String
    var weight:String
    var saveHandle:((String) -> Void)?
    // 当前体重
    @State private var startWeight: String = ""
    // 当前身高
    @State private var startHeight: String = ""
    // 目标体重
    @State private var targetWeight: String = ""
    // 计划的周数
    @State private var planDuration: Int16 = 4
    // 选择的减重计划类型
    @State private var selectedPlanType: HealthCurvePlanType = .conservative
    // 日常活动水平
    @State private var activityLevel: String = ""
    // 活动水平选项
    private let activityLevelOptions = ["卧床", "久坐", "轻体力", "中体力", "重体力"]
    // 是否正在加载活动水平
    @State private var isLoadingActivityLevel: Bool = false
    // AI计划页面控制
    @State private var showAIPlanView: Bool = false
    // AI生成的报告数据
    @State private var aiGeneratedReport: AIGeneratedReport? = nil
    // 是否显示报告预览
    @State private var showReportPreview: Bool = false
    
    init(height:String, weight:String, saveHandle:((String) -> Void)? = nil) {
        self.height = height;
        self.weight = weight;
        self.saveHandle = saveHandle;
        _startHeight = State(initialValue: height)
        _startWeight = State(initialValue: weight)
        
    }
    
    
    // 当前bmi计算
    private var currentBMI: Double? {
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
        guard let current = Double(startWeight), let target = Double(targetWeight) else { return nil }
        return current - target
    }
    // 一周需要减重大小
    private var weeklyWeightLoss: Double? {
        guard planDuration > 0 else {
            return nil;
        }
        guard let weightDifferenceValue = weightDifference else {
            return nil;
        }
        return weightDifferenceValue / Double(planDuration)
    }
    // bmi状态
    private var bmiStatus: (text: String, color: Color) {
        guard let currentBMIValue = currentBMI else {
            return ("", .blue)
        }
       return bimStatusAndColor(bmiValue: currentBMIValue)
    }
    // 计划周期最小值（根据体重差和方案最大周减重量计算）
    private var minPlanDuration: Int16 {
        guard let diff = weightDifference, diff > 0 else { return 2 }
        let minWeeks = Int16(ceil(diff / selectedPlanType.maxWeeklyLoss))
        return max(minWeeks, 2)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // 身体信息卡
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.theme(.primary))
                                Text("身体信息")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color("text_primary"))
                                Spacer()
                            }
                            
                            VStack(spacing: 12) {
                                inputField(label: "身高", placeholder: "cm", text: $startHeight, icon: "ruler.fill")
                                Divider()
                                inputField(label: "当前体重", placeholder: "kg", text: $startWeight, icon: "scalemass.fill")
                                Divider()
                                // 日常活动水平
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "figure.walk")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.theme(.primary))
                                        Text("日常活动水平")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color("text_primary"))
                                        Spacer()
                                        if isLoadingActivityLevel {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        }
                                    }
                                    
                                    HStack(spacing: 8) {
                                        ForEach(activityLevelOptions, id: \.self) { option in
                                            Button(action: { activityLevel = option }) {
                                                Text(option)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundStyle(activityLevel == option ? .white : Color("text_primary"))
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(activityLevel == option ? Color.theme(.primary) : Color("input_bg"))
                                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                            }
                                        }
                                    }
                                }
                            }
                        }.cardStyle()
                        
                        // 目标设置卡
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 8) {
                                Image(systemName: "target")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.theme(.primary))
                                Text("目标设置")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color("text_primary"))
                                Spacer()
                            }
                            
                            VStack(spacing: 12) {
                                inputField(label: "目标体重", placeholder: "kg", text: $targetWeight, icon: "target")
                                Divider()
                                
                                // 计划周期选择器
                                HStack(spacing: 12) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "calendar")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.theme(.primary))
                                        Text("计划周期")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color("text_primary"))
                                    }
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 8) {
                                        Button(action: {
                                            if planDuration > minPlanDuration {
                                                planDuration -= 1
                                            }
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundStyle(Color.theme(.primary).opacity(planDuration > minPlanDuration ? 1 : 0.6))
                                        }
                                        
                                        Text("\(planDuration) 周")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(Color("text_primary"))
                                            .frame(minWidth: 50)
                                            .multilineTextAlignment(.center)
                                        
                                        Button(action: { if planDuration < 52 { planDuration += 1 } }) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundStyle(Color.theme(.primary).opacity(planDuration < 52 ? 1 : 0.6))
                                        }
                                    }
                                    .onChange(of: targetWeight) { _, _ in
                                        adjustPlanDuration()
                                    }
                                    .onChange(of: selectedPlanType) { _, _ in
                                        adjustPlanDuration()
                                    }
                                    .onChange(of: startWeight) { _, _ in
                                        adjustPlanDuration()
                                    }
                                }
                            }
                        }.cardStyle()
                        
                        // 减肥方案卡
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 8) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.theme(.primary))
                                Text("减肥方案")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color("text_primary"))
                                Spacer()
                            }
                            
                            VStack(spacing: 10) {
                                ForEach(HealthCurvePlanType.allCases, id: \.self) { type in
                                    planTypeOptionInForm(type)
                                }
                            }
                        }.cardStyle()
                        
                        // 预览卡
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.theme(.primary))
                                Text("预览")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color("text_primary"))
                                Spacer()
                            }
                            
                            VStack(spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("当前BMI")
                                            .font(.caption)
                                            .foregroundStyle(Color("text_secondary"))
                                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                                            if let currentBMIValue = currentBMI {
                                                Text(String(format: "%.1f", currentBMIValue))
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundStyle(bmiStatus.color)
                                            }
                                            Text("kg/m²")
                                                .font(.caption)
                                                .foregroundStyle(Color("text_secondary"))
                                        }
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("目标BMI")
                                            .font(.caption)
                                            .foregroundStyle(Color("text_secondary"))
                                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                                            if let targetBMIValue = targetBMI {
                                                Text(String(format: "%.1f", targetBMIValue))
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundStyle(.green)
                                            }
                                            Text("kg/m²")
                                                .font(.caption)
                                                .foregroundStyle(Color("text_secondary"))
                                        }
                                    }
                                }
                                
                                Divider()
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("需要减肥")
                                            .font(.caption)
                                            .foregroundStyle(Color("text_secondary"))
                                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                                            if let weightDifferenceValue = weightDifference {
                                                Text(String(format: "%.1f", weightDifferenceValue))
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundStyle(Color.theme(.primary))
                                            }
                                           
                                            Text("kg")
                                                .font(.caption)
                                                .foregroundStyle(Color("text_secondary"))
                                        }
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("每周减肥")
                                            .font(.caption)
                                            .foregroundStyle(Color("text_secondary"))
                                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                                            if let weeklyWeightLossValue = weeklyWeightLoss {
                                                Text(String(format: "%.2f", weeklyWeightLossValue))
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundStyle(Color.theme(.primary))
                                            }
                                           
                                            Text("kg")
                                                .font(.caption)
                                                .foregroundStyle(Color("text_secondary"))
                                        }
                                    }
                                }
                            }
                        }.cardStyle()
                        
                        // AI报告卡
                        aiReportCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .onTapGesture {
                        hideKeyboard()
                    }
                }
                .onAppear {
                    loadActivityLevel()
                }
            }.background(Color("background").ignoresSafeArea())
                .navigationTitle("添加计划")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("取消") {
                            dismiss()
                        }
                        .foregroundStyle(Color("text_secondary"))
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 12) {
                            // AI制定计划按钮
                            if validParam() {
                                Button {
                                    showAIPlanView = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("AI制定")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundStyle(Color.theme(.primary))
                                }
                            }
                            
                            Button("保存") {
                                saveHealthCurveManagePlan()
                            }
                            .foregroundStyle(validParam() ? Color.theme(.primary) : Color.theme(.primary).opacity(0.6))
                            .fontWeight(.semibold)
                        }
                    }
                }
                .sheet(isPresented: $showAIPlanView) {
                    AIPlanGeneratorView(
                        startHeight: startHeight,
                        startWeight: startWeight,
                        targetWeight: targetWeight,
                        planDuration: planDuration,
                        planType: selectedPlanType,
                        activityLevel: activityLevel,
                        // 采纳计划回调处理 - 将AI生成的报告保存到本地状态
                        onAdoptPlan: { report in
                            // 用户采纳AI生成的计划后，保存报告数据到aiGeneratedReport
                            aiGeneratedReport = report
                            // 自动关闭AI计划生成器视图，显示已生成的报告
                            showAIPlanView = false
                        }
                    )
                }
                .sheet(isPresented: $showReportPreview) {
                    if let report = aiGeneratedReport {
                        AIReportPreviewView(report: report)
                    }
                }
        }
        
    }
    
    
    // MARK: - AI报告卡片
    private var aiReportCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.theme(.primary))
                Text("AI健康计划")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                Spacer()
            }
            
            if let report = aiGeneratedReport {
                // 已生成报告 - 显示预览卡片
                generatedReportPreview(report)
            } else {
                // 未生成报告 - 显示生成按钮
                generateReportButton
            }
        }.cardStyle()
    }
    
    // MARK: - 生成报告按钮
    private var generateReportButton: some View {
        Button(action: {
            if validParam() {
                showAIPlanView = true
            }
        }) {
            HStack(spacing: 16) {
                // 左侧图标
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.theme(.primary).opacity(0.15),
                                    Color.theme(.primary).opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.theme(.primary),
                                    Color.theme(.primary).opacity(0.7)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                
                // 右侧信息
                VStack(alignment: .leading, spacing: 6) {
                    Text("让AI为您制定专属计划")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color("text_primary"))
                    
                    Text("基于您的身体数据和目标，生成个性化健康方案")
                        .font(.system(size: 13))
                        .foregroundStyle(Color("text_secondary"))
                        .lineLimit(2)
                }
                
                Spacer()
                
                // 右侧箭头
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.theme(.primary))
            }
            .padding(16)
            .glassContainer(.regular.interactive().tint(Color.theme(.primary).opacity(0.15)), cornerRadius: 14)
        }
        .disabled(!validParam())
        .opacity(validParam() ? 1 : 0.6)
    }
    
    // MARK: - 已生成报告预览
    private func generatedReportPreview(_ report: AIGeneratedReport) -> some View {
        Button(action: {
            showReportPreview = true
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
                        Text("健康计划报告")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color("text_primary"))
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.green)
                    }
                    
                    Text("点击查看完整报告")
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
            .glassContainer(.regular.interactive().tint(Color.green.opacity(0.15)), cornerRadius: 14)
        }
    }
    
    // MARK: - 输入字段组件
    private func inputField(label: String, placeholder: String, text: Binding<String>, icon: String) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.theme(.primary))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                TextField(placeholder, text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                
                Text(placeholder)
                    .font(.caption)
                    .foregroundStyle(Color("text_secondary"))
            }
        }
    }
    
    // MARK: - 编辑表单中的方案选择
    private func planTypeOptionInForm(_ type: HealthCurvePlanType) -> some View {
        Button(action: { selectedPlanType = type }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(type.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color("text_primary"))
                        Spacer()
                        Text(type.weeklyLoss)
                            .font(.caption)
                            .foregroundStyle(Color.theme(.primary))
                    }
                    Text(type.description)
                        .font(.caption)
                        .foregroundStyle(Color("text_secondary"))
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: selectedPlanType == type ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(selectedPlanType == type ? Color.theme(.primary) : Color("divider"))
            }
            .padding(12)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    // MARK: - 保存健康曲线计划
    /// 保存健康曲线计划到服务器
    /// 将AI生成的HTML报告内容保存到plan参数中，而不是单独的aiPlanContent字段
    private func saveHealthCurveManagePlan() {
        // 构建计划参数，如果有AI报告则将HTML内容保存到plan字段
        let planContent: String?
        if let report = aiGeneratedReport {
            // 将AI报告的HTML内容保存到plan参数中
            planContent = report.htmlContent
        } else {
            planContent = nil
        }
        
        // 创建计划DTO对象，plan字段包含AI生成的HTML报告
        var plan = HealthCurveManagePlanDTO (
            startHeight: startHeight,
            startWeight: startWeight,
            targetWeight: targetWeight,
            planDuration: planDuration,
            planType: selectedPlanType.rawValue,
            activityLevel: activityLevel,
            plan: planContent  // AI报告HTML保存在plan字段中
        )
        
        // 同时保存会话ID和消息ID，用于后续可能的对话追溯
        if let report = aiGeneratedReport {
            plan.conversationId = report.conversationId
            plan.messageId = report.messageId
        }
        
        // 发送网络请求保存计划
        BgResultNetWork<HealthCurveManagePlanDTO, String>.post(apiUrl(HEALTH_CURVE_SAVE), params: plan)
            .complicationHand({ (id:String?) in
                saveHandle?(id ?? "")
                dismiss()
            })
            .responseDecodable()
    }
    
    private func validParam() -> Bool {
        return startHeight != "" && startWeight != "" && targetWeight != "" && activityLevel != "";
    }
    
    // MARK: - 自动调整计划周期（变动后默认取最小值）
    private func adjustPlanDuration() {
        planDuration = minPlanDuration
    }
    
    // MARK: - 加载日常活动水平
    private func loadActivityLevel() {
        isLoadingActivityLevel = true
        let param = MetaDataGetByCodeParam(metadataCode: "日常活动水平")
        BgResultNetWork<MetaDataGetByCodeParam, UsersMetadataRecordDTO>
            .post(apiUrl(METADATA_GETBYCODE), params: param)
            .complicationHand { (record: UsersMetadataRecordDTO?) in
                isLoadingActivityLevel = false
                guard let metadataValue = record?.metadataValue,
                      let jsonData = metadataValue.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let data = json["data"] as? String else {
                    return
                }
                activityLevel = data
            }
            .errorHandle { _, _ in
                isLoadingActivityLevel = false
            }
            .responseDecodable()
    }
}

#Preview {
    HealthCurveManagePlanFormView(height: "165", weight: "65")
}

// MARK: - AI生成报告数据模型
struct AIGeneratedReport {
    let htmlContent: String
    let conversationId: String
    let messageId: String
}

// MARK: - AI 报告预览视图
/// AIReportPreviewView - 用于显示 AI 生成的健康计划报告详情
/// 功能：
/// - 在 NavigationView 中展示报告内容
/// - WebView 内部已启用滚动，用户可以直接在WebView内滚动查看完整HTML内容
/// - 提供关闭按钮返回上一级视图
struct AIReportPreviewView: View {
    /// 环境变量：用于关闭当前视图
    @Environment(\.dismiss) private var dismiss
    /// 包含 HTML 内容和对话 ID 的生成报告数据模型
    let report: AIGeneratedReport
    
    var body: some View {
        NavigationView {
            // WebView 内部已启用滚动，直接显示即可
            // 不需要外层 ScrollView 和 fixedSize，避免双层滚动冲突
            // 让 WebView 自然占据可用空间，用户在 WebView 内滚动查看内容
            WebView(htmlContent: report.htmlContent)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color("background"))
                .navigationTitle("健康计划报告")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        // 关闭按钮，点击关闭当前 Sheet 视图
                        Button("关闭") {
                            dismiss()
                        }
                        .foregroundStyle(Color("text_secondary"))
                    }
                }
        }
    }
}
