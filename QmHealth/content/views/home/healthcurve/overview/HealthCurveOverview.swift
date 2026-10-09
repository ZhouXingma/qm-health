import SwiftUI

struct HealthCurveOverview: View {
    @State private var bmiTargetText: String  = "目标范围 18.5 - 24.0"
    // MARK: - 数据
    @State private var heightCm: String = ""
    @State private var heightTrend: Trend? = nil
    @State private var heightDate: Date? = nil
    
    @State private var weightKg: String = ""
    @State private var weightTrend: Trend? = nil
    @State private var weightDate: Date? = nil
    
    @State private var waistCm: String = ""
    @State private var waistTrend: Trend? = nil
    @State private var waistDate: Date? = nil
    
    @State private var hipCm: String = ""
    @State private var hipTrend: Trend? = nil
    @State private var hipDate: Date? = nil
    
    
    @State private var showBMIInfo = false
    @State private var showWHRInfo = false
    
    // BMI数值
    @State private var bmi:Double? = nil
    @State private var whr:Double? = nil
    
    // 显示指标详情
    @State private var showHealthIndicatorDetail:Bool = false
    @State private var showHealthIndicatorCode:String = ""
    @State private var showHealthIndicatorLastedValue:String = ""
    
    
    
    
    // MARK: - 计算属性
    // BMI状态
    private var bmiStatus: (text: String, color: Color)? {
        if let bmiValue = bmi {
           bimStatusAndColor(bmiValue: bmiValue)
        } else {
            nil
        }
    }
   // 腰臀比状态
    private var whrStatus: (text: String,color:Color)? {
        if let whrValue = whr {
            return whrStatusAndColor(whrValue: whrValue);
        } else {
            return nil
        }
    }
    
    // MARK: - UI
    var body: some View {
        VStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    overviewCard()
                    metricsGrid()
                    ratioCard()
                    tipsCard()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }.refreshable {
                initData()
            }
        }
        .background(Color("background").ignoresSafeArea())
        .sheet(isPresented: $showBMIInfo) { bmiInfoSheet }
        .sheet(isPresented: $showWHRInfo) { whrInfoSheet }
        .sheet(isPresented: $showHealthIndicatorDetail) {
            HealthIndicatorDetail(code: $showHealthIndicatorCode, lastedValue: $showHealthIndicatorLastedValue)
        }
        .onAppear() {
            initData()
        }
       
    }
    

    
    // MARK: - 概览卡（BMI：分段色带 + 指针）
    private func overviewCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("体重指数 BMI", systemImage: "scalemass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                Spacer()
                if let bmiStatusInfo = bmiStatus {
                    Chip(text: bmiStatusInfo.text, color: bmiStatusInfo.color)
                        .font(.system(size: 14, weight: .semibold))
                }
            }

            HStack(alignment: .firstTextBaseline) {
                if let bmiValue = bmi,let bmiStatusInfo = bmiStatus {
                    Text(String(format: "%.1f", bmiValue))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(bmiStatusInfo.color)
                } else {
                    Text("")
                        .font(.system(size: 32, weight: .bold))
                }
                Spacer()
                Button {
                    showBMIInfo = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                        Text("说明")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.theme(.primary))
                }
            }

            // 分段色带 + 指针（与 WHR 保持一致：指针位于色带上）
            VStack(spacing: 6) {
                GeometryReader { proxy in
                    let width = proxy.frame(in: .local).size.width
                    ZStack(alignment: .leading) {
                        HStack(spacing: 0) {
                            Rectangle().fill(Color.blue.opacity(0.7))
                                .frame(width: width * segmentWidth(.under), height: 10)
                            Rectangle().fill(Color.green.opacity(0.85))
                                .frame(width: width * segmentWidth(.normal), height: 10)
                            Rectangle().fill(Color.orange.opacity(0.9))
                                .frame(width: width * segmentWidth(.over), height: 10)
                            Rectangle().fill(Color.red.opacity(0.9))
                                .frame(width: width * segmentWidth(.obese), height: 10)
                        }
                        .mask(Capsule())
                        if let bmiValue = bmi,let bmiStatusInfo = bmiStatus {
                            let x = CGFloat(bmiPositionX(bmi: bmiValue, width: width))
                            Circle()
                                .fill(bmiStatusInfo.color)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .offset(x: max(0, min(x - 6, width - 12)))
                        }
                    }
                }
                .frame(height: 16)
                HStack(spacing: 16) {
                    legend(color: .blue, text: "偏瘦")
                    legend(color: .green, text: "正常")
                    legend(color: .orange, text: "超重")
                    legend(color: .red, text: "肥胖")
                    Spacer()
                    Text(bmiTargetText)
                        .font(.caption2)
                        .foregroundStyle(Color("text_secondary"))
                }
                .font(.caption2)
                .foregroundStyle(Color("text_secondary"))
            }
        }.cardStyle()
    }
    
    // MARK: - 指标网格（去掉副标题说明）
    private func metricsGrid() -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            MetricTile(value: $heightCm, trend: $heightTrend, lastUpdateDate: $heightDate, icon: getHealthIndicatorIcon("height").iconName, title: "身高", unit: "cm") {
                self.showHealthIndicatorDetail = true
                self.showHealthIndicatorCode = "height"
                self.showHealthIndicatorLastedValue = heightCm
            }
            MetricTile(value: $weightKg, trend: $weightTrend, lastUpdateDate: $weightDate, icon: getHealthIndicatorIcon("weight").iconName, title: "体重",unit: "kg") {
                self.showHealthIndicatorDetail = true
                self.showHealthIndicatorCode = "weight"
                self.showHealthIndicatorLastedValue = weightKg
            }
            MetricTile(value: $waistCm, trend: $waistTrend, lastUpdateDate: $waistDate, icon: getHealthIndicatorIcon("waist").iconName, title: "腰围", unit: "cm") {
                self.showHealthIndicatorDetail = true
                self.showHealthIndicatorCode = "waist"
                self.showHealthIndicatorLastedValue = waistCm
            }
            MetricTile(value: $hipCm, trend: $hipTrend, lastUpdateDate: $hipDate, icon: getHealthIndicatorIcon("hip").iconName, title: "臀围", unit: "cm") {
                self.showHealthIndicatorDetail = true
                self.showHealthIndicatorCode = "hip"
                self.showHealthIndicatorLastedValue = hipCm
            }
        }
    }
    
    // MARK: - 比例卡（腰臀比 + 说明弹窗）
    private func ratioCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("腰臀比 WHR", systemImage: "figure.arms.open")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                Spacer()
                if let whrStatusInfo = whrStatus {
                    Chip(text: whrStatusInfo.text, color: whrStatusInfo.color)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            
            HStack(alignment: .firstTextBaseline) {
                if let whrValue = whr, let whrStatusInfo = whrStatus  {
                    Text(whrValue == 0 ? "--" : String(format: "%.2f", whrValue))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(whrStatusInfo.color)
                } else {
                    Text("--")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.blue)
                }
                
                Text("WHR")
                    .font(.footnote)
                    .foregroundStyle(Color("text_secondary"))
                Spacer()
                Button {
                    showWHRInfo = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                        Text("说明")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.theme(.primary))
                }
            }
            
            GeometryReader { proxy in
                let width = proxy.frame(in: .local).size.width
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        Rectangle().fill(Color.green.opacity(0.85))
                            .frame(width: width * 0.9, height: 10)
                        Rectangle().fill(Color.orange.opacity(0.9))
                            .frame(width: width * 0.1, height: 10)
                    }.mask(Capsule())
                    if let whrValue = whr, let whrStatusInfo = whrStatus {
                        let x = CGFloat(min(max(whrValue, 0), 1)) / 1 * width
                        Circle()
                            .fill(whrStatusInfo.color)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .offset(x: max(0, min(x - 6, width - 12)))
                    }
                }
            }
            .frame(height: 16)

        }.cardStyle()
    }

    // MARK: - 指标说明（保留简短提示）
    private func tipsCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.theme(.primary))
                Text("健康提示")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color("text_primary"))
                Spacer()
            }
            VStack(alignment: .leading, spacing: 8) {
                bullet("BMI 为快速筛查指标，建议结合体脂率、血压、血脂等综合评估。")
                bullet("腰围可反映内脏脂肪；固定时间、同方法测量便于对比。")
                bullet("腰臀比(Waist-to-Hip Ratio) > 0.90 风险增高。")
                bullet("趋势仅用箭头指示：上升/下降/平稳。")
            }
            .font(.caption)
            .foregroundStyle(Color("text_secondary"))
            .lineSpacing(2)
        }.cardStyle()
    }

    
    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color("text_secondary"))
                .frame(width: 4, height: 4)
                .padding(.top, 7)
            Text(text)
        }
    }
    
    private var cardBackground: some ShapeStyle {
        Color("content_bg")
    }
    
    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }
    
    
    
    private enum BMISegment { case under, normal, over, obese }
    
    // BMI 可视化映射：范围 15...35
    private func bmiPositionX(bmi:Double, width: CGFloat) -> CGFloat {
        let minV: Double = 15, maxV: Double = 35
        let clamped = min(max(bmi, minV), maxV)
        let pct = (clamped - minV) / (maxV - minV)
        return CGFloat(pct) * width
    }
    
    private func segmentWidth(_ seg: BMISegment) -> CGFloat {
        // <18.5, 18.5-24, 24-28, >=28
        let total: Double = 35 - 15 // 20
        switch seg {
        case .under: return CGFloat((18.5 - 15) / total)   // 3.5/20
        case .normal: return CGFloat((24.0 - 18.5) / total) // 5.5/20
        case .over: return CGFloat((28.0 - 24.0) / total)   // 4/20
        case .obese: return CGFloat((35.0 - 28.0) / total)  // 7/20
        }
    }
    
    // MARK: - 说明弹窗内容
    private var bmiInfoSheet: some View {
        InfoSheetContainer(title: "BMI 指南") {
            VStack(alignment: .leading, spacing: 10) {
                Text("BMI（Body Mass Index）= 体重(kg) ÷ 身高(m)²")
                Text("常用分级区间：")
                VStack(alignment: .leading, spacing: 6) {
                    Text("• < 18.5：偏瘦").foregroundStyle(Color.blue)
                    Text("• 18.5 - 23.9：正常").foregroundStyle(Color.green)
                    Text("• 24.0 - 27.9：超重").foregroundStyle(Color.orange)
                    Text("• ≥ 28.0：肥胖").foregroundStyle(Color.red)
                }
                Text("说明：BMI 仅用于快速筛查，无法区分肌肉与脂肪含量。建议结合体脂率、腰围、血压、血脂等综合评估。")
                    .foregroundStyle(Color("text_secondary"))
                    .font(.footnote)
                Divider().background(Color("divider"))
                if let bmiValue = bmi, let bmiStatusInfo = bmiStatus {
                    Text("当前 BMI：\(String(format: "%.1f", bmiValue))（\(bmiStatusInfo.text)）")
                }
                Text("建议目标范围：18.5 - 24.0")
                    .foregroundStyle(Color("text_secondary"))
                    .font(.footnote)
            }
            .font(.subheadline)
        }
    }
    
    private var whrInfoSheet: some View {
        InfoSheetContainer(title: "腰臀比（WHR）说明") {
            VStack(alignment: .leading, spacing: 10) {
                Text("WHR = 腰围 ÷ 臀围")
                Text("示例：腰围 82cm、臀围 95cm，则 WHR = 82 ÷ 95 ≈ 0.86")
                Text("判读参考：")
                VStack(alignment: .leading, spacing: 6) {
                    Text("• ≤ 0.90：正常").foregroundStyle(Color.green)
                    Text("• > 0.90：偏高").foregroundStyle(Color.orange)
                }
                Text("说明：WHR 反映脂肪分布与腹型肥胖风险；测量时松紧适中，建议在同一时间段复测以便对比。")
                    .foregroundStyle(Color("text_secondary"))
                    .font(.footnote)
                Divider().background(Color("divider"))
                if let whrValue = whr, let whrStatusInfo = whrStatus {
                    Text("当前 WHR：\(whrValue == 0 ? "--" : String(format: "%.2f", whrValue))（\(whrStatusInfo.text)）")
                }
            }
            .font(.subheadline)
        }
    }
    
   
    
    // 通用信息弹窗容器
    fileprivate struct InfoSheetContainer<Content: View>: View {
        var title: String
        @ViewBuilder var content: Content
        
        @Environment(\.dismiss) private var dismiss
        
        var body: some View {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        content
                    }
                    .padding(16)
                }
                .background(Color("background").ignoresSafeArea())
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") { dismiss() }
                    }
                }
            }
        }
    }
    
    
    // MARK: - 辅助方法
    /// 初始化数据
    private func initData() {
      loadData()
    }
    /// 加载数据
    private func loadData() {
        let param = UsersHealthIndicatorLastedStatusParam(
            indicatorCodes: ["height","weight","waist","hip"]
        )
        BgResultNetWork<UsersHealthIndicatorLastedStatusParam, [String:UsersHealthIndicatorLastedStatusDTO]>.post(apiUrl(HEALTH_INDICATOR_LAST_STATUS), params: param)
            .complicationHand { (r:[String:UsersHealthIndicatorLastedStatusDTO]?) in
                if let result = r {
                    let heightDto = result["height"];
                    let weightDto = result["weight"];
                    let waistDto = result["waist"];
                    let hipDto = result["hip"];
                    showHeight(heightDto);
                    showWeight(weightDto)
                    showWaist(waistDto)
                    showHip(hipDto)
                }
            }.finalHandleFunc{ _ in
                computerBmi();
                computerWhr();
            }.responseDecodable()
    }
    /// 显示身高
    private func showHeight(_ valueOption : UsersHealthIndicatorLastedStatusDTO?) {
        if let value = valueOption {
            heightCm = value.indicatorValue
            heightDate = value.measureTime
            heightTrend = Trend.getByCode(code: value.stableStatus)
        }
    }
    /// 显示体重
    private func showWeight(_ valueOption : UsersHealthIndicatorLastedStatusDTO?) {
        if let value = valueOption {
            weightKg = value.indicatorValue
            weightDate = value.measureTime
            weightTrend = Trend.getByCode(code: value.stableStatus)
        } else {
            weightKg = ""
            weightDate = nil
            weightTrend = nil
        }
    }
    /// 显示腰围
    private func showWaist(_ valueOption : UsersHealthIndicatorLastedStatusDTO?) {
        if let value = valueOption {
            waistCm = value.indicatorValue
            waistDate = value.measureTime
            waistTrend = Trend.getByCode(code: value.stableStatus)
        } else {
            waistCm = ""
            waistDate = nil
            waistTrend = nil
        }
    }
    /// 显示臀围
    private func showHip(_ valueOption : UsersHealthIndicatorLastedStatusDTO?) {
        if let value = valueOption {
            hipCm = value.indicatorValue
            hipDate = value.measureTime
            hipTrend = Trend.getByCode(code: value.stableStatus)
        } else {
            hipCm = ""
            hipDate = nil
            hipTrend = nil
        }
    }
    
    private func computerBmi() {
        let heightOpt = Double(heightCm)
        let weightOpt = Double(weightKg)
        if let height = heightOpt, let weight = weightOpt {
            self.bmi = computerBmiValue(height:height,weight:weight)
        } else {
            bmi = nil
        }
    }
    
    private func computerWhr() {
        let waistOpt = Double(waistCm)
        let hipOpt = Double(hipCm)
        if let waist = waistOpt, let hip = hipOpt {
            if hip <= 0  {
                whr = nil
                return
            }
            let whr = (waist / hip).rounded(toPlaces: 2)
            self.whr = whr
        } else {
            self.whr = nil
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月d日"
        return f.string(from: date)
    }
    private func formattedDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }
    
    
}



#Preview {
    HealthCurveOverview()
        .preferredColorScheme(.light)
}
