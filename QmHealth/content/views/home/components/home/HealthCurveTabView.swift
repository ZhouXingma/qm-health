//
//  LossWeightTabView.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/9/15.
//

import SwiftUI

struct HealthCurveTabView: View {
    // 首页刷新事件总线
    @EnvironmentObject var refreshBus: HomeRefreshBus
    // 开始体重
    @State private var startWeight:String = "";
    // 目标体重
    @State private var targetWeight:String = "";
    // 当前体重
    @State private var currentWeight:String = "";
    // 当前身高
    @State private var currentHeight:String = "";
    // 计划状态
    @State private var planStatus:Int16?;
    // 当前bmi
    private var currentBMI: String {
        guard let weight = Double(currentWeight), let height = Double(currentHeight), height > 0 else { return "" }
        
        let bmi =  computerBmiValue(height: height, weight: weight)
        return String(format: "%.1f", bmi);
    }
    @State private var progress:Double = 0
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
        VStack(alignment: .center) {
            HStack(alignment:.center) {
                Image(systemName: "gauge.with.needle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.theme(.primary))
                Text("健康曲线")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))

                // 状态显示（液态玻璃胶囊）
                if !statusDisplay.text.isEmpty {
                    Text(statusDisplay.text)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(statusDisplay.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .glassPillColor(.regular.interactive(), statusDisplay.color.opacity(0.15))
                }

                Spacer()
                NavigationLink {
                    WeightManagerDetail()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.theme(.primary))
                        .frame(width: 28, height: 28)
                        .glassPill()
                }
            }
            ZStack(alignment: .center) {
                HStack(alignment:.bottom)  {
                    SemicircleProgress(colors: [.color2,.color1],progress: $progress)
                        .frame(height: 160)
                        .offset(y: 35)
                }.frame(height: 100)
                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
                        Text("初始体重")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.color1)
                        Text("\(startWeight)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.color1)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("目标体重")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.color2)
                        Text("\(targetWeight)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.color2)
                    }
                }.frame(height: 10)
            }.frame(height: 80)
            HStack {
                Spacer()
                VStack(alignment: .center) {
                    Text("\(currentHeight)")
                        .font(.system(size:18, weight: .bold))
                        .foregroundStyle(Color.theme(.primary))
                    Text("身高(cm)")
                        .font(.system(size:12, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                }.frame(width: 80)
                Spacer()
                VStack {
                    Text("\(currentWeight)")
                        .font(.system(size:18, weight: .bold))
                        .foregroundStyle(Color.theme(.primary))
                    Text("体重(kg)")
                        .font(.system(size:12, weight: .bold))
                        .foregroundStyle(.secondary)
                }.frame(width: 80)
                Spacer()
                VStack {
                    Text(currentBMI)
                        .font(.system(size:18, weight: .bold))
                        .foregroundStyle(Color.theme(.primary))
                    Text("BMI")
                        .font(.system(size:12, weight: .bold))
                        .foregroundStyle(.secondary)
                }.frame(width: 80)
                Spacer()
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .cardStyle()
            .onAppear {
                initData()
            }
            .onChange(of: refreshBus.refreshTrigger) { _, _ in
                initData()
            }
    }
    // 初始化数据
    func initData() {
        loadData();
    }
    // 加载数据
    func loadData() {
        // 先清空旧账户的 state，避免接口返回 nil 时仍展示上一个账号的身高体重/计划
        self.startWeight = ""
        self.targetWeight = ""
        self.currentWeight = ""
        self.currentHeight = ""
        self.planStatus = nil
        self.progress = 0

        BgResultNetWork<Empty, HealthCurveManagePlanDTO>.post(apiUrl(HEALTH_CURVE_GET), params: Empty())
            .complicationHand({ (r:HealthCurveManagePlanDTO?) in
                if let result = r {
                    self.startWeight = result.startWeight ?? "";
                    self.targetWeight = result.targetWeight ?? "";
                    self.planStatus = result.statusCode
                    calculateProgress()
                }
            })
            .responseDecodable()
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
                    calculateProgress()
                }
            }.finalHandleFunc{ _ in
                
            }.responseDecodable()
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
    // 计算进度
    func calculateProgress() {
        guard
            let current = Double(self.currentWeight),
            let start = Double(self.startWeight),
            let target = Double(self.targetWeight)
        else {
            self.progress = 0; // 任一字符串无法转为数字
            return;
        }

        let totalChange = target - start

        if totalChange == 0 {
            // 起始体重等于目标体重，视为目标已完成
            self.progress = 1.0;
            return;
        }

        let progress: Double
        if totalChange > 0 {
            // 增重场景：目标 > 起始
            progress = (current - start) / totalChange
        } else {
            // 减重场景：目标 < 起始
            progress = (start - current) / (start - target)
        }

        // 保留两位小数：先乘100，四舍五入，再除以100
        let roundedProgress = (progress * 100).rounded() / 100
        self.progress = roundedProgress
    }
}

#Preview {
    HealthCurveTabView()
}
