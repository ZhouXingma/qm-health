//
//  HealthIndicatorDetail.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/11/4.
//

import SwiftUI

struct HealthIndicatorDetail: View {
    @Binding var code:String;
    @Binding var lastedValue:String;
    @State private var indicatorName: String = ""
    @State private var unit: String = ""
    @State private  var resultType: Int32 = 1
    @StateObject private var config = UsersHealthIndicatorConfigurationInfo()
    private let indicatorCodeReplace:[String:String] = ["bloodPressure":"systolic"]
    
    var body: some View {
        VStack {
            if resultType == HealthIndicatorResultType.Quantitative.rawValue {
                if config.model == "normal" {
                    NormalHealthIndicatorDetail(
                        code: self.code,
                        indicatorName: self.indicatorName,
                        lastedValue: self.lastedValue,
                        unit: self.unit,
                        resultType: self.resultType,
                        config: config)
                } else if config.model == "bloodPressure" {
                    BloodPressureIndicatorDetail(
                        code: self.code,
                        indicatorName: self.indicatorName,
                        lastedValue: self.lastedValue,
                        unit: self.unit,
                        resultType: self.resultType,
                        config: config)
                }
            } else if resultType == HealthIndicatorResultType.Qualitative.rawValue {
                QualitativeHealthIndicatorDetail(
                    code: self.code,
                    indicatorName: self.indicatorName,
                    lastedValue: self.lastedValue,
                    unit: self.unit,
                    resultType: self.resultType,
                    config: config
                )
            } else if resultType == HealthIndicatorResultType.Description.rawValue {
                DescriptiveHealthIndicatorDetail(
                    code: self.code,
                    indicatorName: self.indicatorName,
                    lastedValue: self.lastedValue,
                    unit: self.unit,
                    resultType: self.resultType,
                    config: config
                )
            }
        }.background(Color("background"))
        .withGlobalPop()
        .onAppear {
            loadData()
        }.onChange(of: code) { oldValue, newValue in
            loadData()
        }
    }
    
   
}


// MARK: - 辅助方法
extension HealthIndicatorDetail {
    // 加载数据
    func loadData() {
        let findCode = indicatorCodeReplace[code] ?? code
        let params = [
            "indicatorCode": findCode
        ]
        BgResultNetWork<[String:String], UsersHealthIndicatorConfigurationDTO>.post(apiUrl(HEALTH_INFICATOR_CONFIG), params: params)
            .complicationHand {(configOption:UsersHealthIndicatorConfigurationDTO?)  in
                DispatchQueue.main.async {
                    if let configInfo = configOption {
                        self.indicatorName = configInfo.indicatorName ?? "";
                        self.unit = configInfo.unit ?? "";
                        self.resultType = configInfo.resultType ?? 1;
                        
                        if let config = configInfo.config {
                            self.config.from(dto: config)
                        }
                    }
                }
            }
            .responseDecodable()
    }
}

#Preview {
    @Previewable @State var code: String = "height"
    @Previewable @State var lastedValue: String = ""
    return HealthIndicatorDetail(code: $code, lastedValue: $lastedValue)
}
