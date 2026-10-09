//
//  OcrRecognize.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/8/17.
//

import Foundation

// OCR 识别请求参数
class OcrRecognizeParam : Codable {
    // 文件ID列表
    var fileIds: [String]
    // 固定文案（写死，不许改动）
    var question: String

    init(fileIds: [String], question: String) {
        self.fileIds = fileIds
        self.question = question
    }
}

// OCR 识别结果（单个报告）
class OcrRecognizeResultDTO : Codable {
    var isHealthIndicator: Bool?
    var fileContyentType: String?
    var success: Bool?
    var ocrInfo: OcrRecognizeInfoDTO?
}

// OCR 识别信息
class OcrRecognizeInfoDTO : Codable {
    var date: String?
    var hospitalName: String?
    var doctorName: String?
    var name: String?
    var data: [OcrIndicatorDTO]?
}

// OCR 识别出的单个指标
class OcrIndicatorDTO : Codable {
    var code: String?
    var name: String?
    var value: String?
    var unit: String?
    var normal: String?
    var tag: String?
}
