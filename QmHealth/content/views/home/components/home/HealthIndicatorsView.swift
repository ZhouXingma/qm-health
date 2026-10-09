//
//  HealthIndicatorsView.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/9/15.
//

import SwiftUI

struct HealthIndicatorsView: View {
    // 首页刷新事件总线
    @EnvironmentObject var refreshBus: HomeRefreshBus
    @State private var bloodPressureData: (systolic: HealthIndicatorInfoDTO?, diastolic: HealthIndicatorInfoDTO?) = (nil, nil)
    @State private var heartRateData: HealthIndicatorInfoDTO?
    @State private var bloodSugarData: HealthIndicatorInfoDTO?
    @State private var waistData: HealthIndicatorInfoDTO?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // 详情页面状态
    @State private var showDetailSheet = false
    @State private var selectedIndicatorCode: String = ""
    
    var systolicStr:String {
        if let systolic = bloodPressureData.systolic?.indicatorValue {
            return systolic;
        }
        return "-";
    }
    var diastolicStr:String {
        if let diastolic = bloodPressureData.diastolic?.indicatorValue {
            return diastolic;
        }
        return "-";
    }
    var pulseStr:String {
        if let pulse = heartRateData?.indicatorValue {
            return pulse;
        }
        return "-"
    }
    var bloodSugarStr: String {
        if let sugar = bloodSugarData?.indicatorValue {
            return sugar;
        }
        return "-"
    }
    var waistStr : String {
        if let waistValue = waistData?.indicatorValue {
            return waistValue;
        }
        return "-"
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.theme(.primary))
                Text("健康指标")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                Spacer()
                NavigationLink {
                    HealthIndicatorMain()
                } label: {
                    Text("查看更多")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.theme(.primary))
                }
            }
            
            if isLoading {
                VStack {
                    ProgressView()
                        .tint(Color.theme(.primary))
                }
                .frame(height: 100)
            } else if let error = errorMessage {
                VStack {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.red)
                }
                .frame(height: 100)
            } else {
                // 健康指标网格
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    // 血压
                    Button(action: {
                        selectedIndicatorCode = "systolic"
                        showDetailSheet = true
                    }) {
                        HealthIndicatorCardBloodPressure (
                            icon: "heart.fill",
                            title: "血压",
                            systolic: systolicStr,
                            diastolic: diastolicStr,
                            unit: "mmHg",
                            systolicStatus: HealthStatus.getHealthStatus(indicatorStatus: bloodPressureData.systolic?.indicatorStatus),
                            diastolicStatus: HealthStatus.getHealthStatus(indicatorStatus: bloodPressureData.diastolic?.indicatorStatus),
                            color: Color.red,
                            otherLabel: getDataTimeLabel(bloodPressureData.systolic?.otherLabel),
                            measureTime: bloodPressureData.systolic?.measureTime,
                            systolicReferenceRange: bloodPressureData.systolic?.referenceRange,
                            diastolicReferenceRange: bloodPressureData.diastolic?.referenceRange
                        )
                    }
                    .buttonStyle(CardPressButtonStyle())

                    // 心率
                    Button(action: {
                        selectedIndicatorCode = "pulse_rate"
                        showDetailSheet = true
                    }) {
                        HealthIndicatorCard(
                            icon: "waveform.path.ecg",
                            title: "心率",
                            value: pulseStr,
                            unit: "次/分",
                            status: HealthStatus.getHealthStatus(indicatorStatus: heartRateData?.indicatorStatus),
                            color: Color.pink,
                            otherLabel: nil,
                            measureTime: heartRateData?.measureTime,
                            referenceRange: heartRateData?.referenceRange
                        )
                    }
                    .buttonStyle(CardPressButtonStyle())

                    // 血糖
                    Button(action: {
                        selectedIndicatorCode = "blood_sugar"
                        showDetailSheet = true
                    }) {
                        HealthIndicatorCard(
                            icon: "drop.fill",
                            title: "血糖",
                            value: bloodSugarStr,
                            unit: "mmol/L",
                            status: HealthStatus.getHealthStatus(indicatorStatus: bloodSugarData?.indicatorStatus),
                            color: Color.theme(.primary),
                            otherLabel: getDataTimeLabel(bloodSugarData?.otherLabel),
                            measureTime: bloodSugarData?.measureTime,
                            referenceRange: bloodSugarData?.referenceRange
                        )
                    }
                    .buttonStyle(CardPressButtonStyle())

                    // 腰围
                    Button(action: {
                        selectedIndicatorCode = "waist"
                        showDetailSheet = true
                    }) {
                        HealthIndicatorCard(
                            icon: "figure.walk",
                            title: "腰围",
                            value: waistStr,
                            unit: "cm",
                            status: HealthStatus.getHealthStatus(indicatorStatus: waistData?.indicatorStatus),
                            color: Color.green,
                            otherLabel: nil,
                            measureTime: waistData?.measureTime,
                            referenceRange: waistData?.referenceRange
                        )
                    }
                    .buttonStyle(CardPressButtonStyle())
                    
                }
            }
        }
        .cardStyle()
        .onAppear {
            loadHealthIndicators()
        }
        .onChange(of: refreshBus.refreshTrigger) { _, _ in
            loadHealthIndicators()
        }
        .sheet(isPresented: $showDetailSheet) {
            HealthIndicatorDetail(code: $selectedIndicatorCode, lastedValue: .constant(""))
        }
    }
    
    // MARK: - 数据加载
    private func loadHealthIndicators() {
        isLoading = true
        errorMessage = nil
        // 先清空旧账户的指标，避免接口返回 nil 时仍展示上一个账号的血压/心率/血糖/腰围
        bloodPressureData = (nil, nil)
        heartRateData = nil
        bloodSugarData = nil
        waistData = nil

        let params = UsersHealthIndicatorLastParam(
            indicatorCodes: ["systolic", "diastolic", "pulse_rate", "blood_sugar", "waist"]
        )
        
        BgResultNetWork<UsersHealthIndicatorLastParam, [String: HealthIndicatorInfoDTO]>.post(
            apiUrl(HEALTH_INDICATOR_LAST),
            params: params
        )
        .complicationHand { (data: [String: HealthIndicatorInfoDTO]?) in
            DispatchQueue.main.async {
                if let indicators = data {
                    // 处理血压（需要同时获取 systolic 和 diastolic）
                    if let systolic = indicators["systolic"],
                       let diastolic = indicators["diastolic"] {
                        bloodPressureData = (systolic, diastolic)
                    }
                    
                    // 处理心率
                    if let pulse = indicators["pulse_rate"] {
                        heartRateData = pulse
                    }
                    
                    // 处理血糖
                    if let sugar = indicators["blood_sugar"] {
                        bloodSugarData = sugar
                    }
                    
                    // 处理腰围
                    if let waistValue = indicators["waist"] {
                        waistData = waistValue
                    }
                }
                isLoading = false
            }
        }
        .errorHandle { (result, error) in
            DispatchQueue.main.async {
                errorMessage = "加载健康指标失败"
                isLoading = false
            }
        }
        .responseDecodable()
    }
}

#Preview {
    HealthIndicatorsView()
}
