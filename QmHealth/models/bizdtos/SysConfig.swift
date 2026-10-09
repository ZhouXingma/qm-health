//
//  SysConfig.swift
//  QmHealth
//
//  AI 模型配置相关模型与常量：
//  - SysConfigDTO：系统级默认配置（/public/sys/config/listbycode 返回），用于模型下拉默认值
//  - UsersModelConfig：用户级 AI 模型配置（/api/users/modelconfig/*），用于实际生效的配置
//

import Foundation
import SwiftUI

// MARK: - 模型用途枚举（对应 Rust ModelPurpose：1=主模型，2=OCR）

enum AIModelPurpose: Int, CaseIterable, Identifiable {
    case main = 1
    case ocr = 2

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .main: return "主智能体"
        case .ocr: return "OCR 识别"
        }
    }

    var subtitle: String {
        switch self {
        case .main: return "AI 聊天主模型（必填）"
        case .ocr: return "用于图片文字识别（如模型支持多模态可不设置）"
        }
    }

    var icon: String {
        switch self {
        case .main: return "person.crop.circle.badge.checkmark"
        case .ocr: return "text.viewfinder"
        }
    }
}

// MARK: - 模型类型（对应 Rust model_type 常量）

enum AIModelType: String, CaseIterable, Identifiable {
    case deepseek
    case openai
    case glm
    case kimi
    case minimax

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .deepseek: return "DeepSeek"
        case .openai: return "OpenAI"
        case .glm: return "智谱 GLM"
        case .kimi: return "月之暗面 KIMI"
        case .minimax: return "MiniMax"
        }
    }

    var icon: String {
        switch self {
        case .deepseek: return "bolt.fill"
        case .openai: return "sparkles"
        case .glm: return "leaf.fill"
        case .kimi: return "moon.stars.fill"
        case .minimax: return "person.crop.circle.badge.checkmark"
        }
    }

    var tintColorName: String {
        switch self {
        case .deepseek: return "blue"
        case .openai: return "green"
        case .glm: return "purple"
        case .kimi: return "indigo"
        case .minimax: return "orange"
        }
    }

    /// SwiftUI 颜色：直接返回 Color，避免 Color(name) 找不到资源报错
    var color: Color {
        switch self {
        case .deepseek: return .blue
        case .openai: return .green
        case .glm: return .purple
        case .kimi: return .indigo
        case .minimax: return .orange
        }
    }
}

// MARK: - SysConfigDTO - 系统公共配置（listbycode 单条）

/// 后端 SysConfig 单条记录。对应 /public/sys/config/listbycode 返回 data 数组的元素。
///
/// 仅用于：在编辑页打开时拉默认 baseUrl / 可选模型列表 / 默认 configParams，
/// 不会写入后端。用户实际生效的配置走 UsersModelConfig 接口。
class SysConfigDTO: Codable {
    var pkId: Int?
    var code: String?
    var codeDesc: String?
    var subCode: String?
    var subCodeDesc: String?
    var config: String?
    var jsonConfig: SysConfigJsonConfig?
    var orderNumber: Int?
    var enabled: Int?
    var remarks: String?
    var gmtCreated: String?
    var gmtModified: String?

    init(pkId: Int? = nil,
         code: String? = nil,
         codeDesc: String? = nil,
         subCode: String? = nil,
         subCodeDesc: String? = nil,
         config: String? = nil,
         jsonConfig: SysConfigJsonConfig? = nil,
         orderNumber: Int? = nil,
         enabled: Int? = nil,
         remarks: String? = nil,
         gmtCreated: String? = nil,
         gmtModified: String? = nil) {
        self.pkId = pkId
        self.code = code
        self.codeDesc = codeDesc
        self.subCode = subCode
        self.subCodeDesc = subCodeDesc
        self.config = config
        self.jsonConfig = jsonConfig
        self.orderNumber = orderNumber
        self.enabled = enabled
        self.remarks = remarks
        self.gmtCreated = gmtCreated
        self.gmtModified = gmtModified
    }
}

// MARK: - SysConfigJsonConfig

class SysConfigJsonConfig: Codable {
    var canSelectModels: [String]?
    var configParams: [String: AnyCodable]?

    init(canSelectModels: [String]? = nil,
         configParams: [String: AnyCodable]? = nil) {
        self.canSelectModels = canSelectModels
        self.configParams = configParams
    }
}

// MARK: - SysConfigListByCodeRequest

struct SysConfigListByCodeRequest: Encodable {
    let code: String

    init(code: String) {
        self.code = code
    }
}

// MARK: - UsersModelConfigDTO（对应后端 UsersModelConfigDTO）

/// 用户级 AI 模型配置 DTO。对应后端 /api/users/modelconfig/list 返回的元素。
class UsersModelConfigDTO: Codable {
    var id: String?
    var userId: String?
    var modelType: String?
    var modelName: String?
    var baseUrl: String?
    var apiKey: String?
    var purpose: Int?
    var purposeDesc: String?
    var isMultimodal: Int?
    var enabled: Int?
    var extraConfig: AnyCodable?
    var remarks: String?
    var gmtCreated: String?
    var gmtModified: String?

    init(id: String? = nil,
         userId: String? = nil,
         modelType: String? = nil,
         modelName: String? = nil,
         baseUrl: String? = nil,
         apiKey: String? = nil,
         purpose: Int? = nil,
         purposeDesc: String? = nil,
         isMultimodal: Int? = nil,
         enabled: Int? = nil,
         extraConfig: AnyCodable? = nil,
         remarks: String? = nil,
         gmtCreated: String? = nil,
         gmtModified: String? = nil) {
        self.id = id
        self.userId = userId
        self.modelType = modelType
        self.modelName = modelName
        self.baseUrl = baseUrl
        self.apiKey = apiKey
        self.purpose = purpose
        self.purposeDesc = purposeDesc
        self.isMultimodal = isMultimodal
        self.enabled = enabled
        self.extraConfig = extraConfig
        self.remarks = remarks
        self.gmtCreated = gmtCreated
        self.gmtModified = gmtModified
    }

    /// 是否启用
    var isEnabled: Bool { (enabled ?? 1) == 1 }

    /// 是否支持多模态
    var isMultimodalFlag: Bool { (isMultimodal ?? 0) == 1 }

    /// 用途枚举
    var purposeEnum: AIModelPurpose? {
        guard let p = purpose else { return nil }
        return AIModelPurpose(rawValue: p)
    }

    /// 模型类型枚举
    var modelTypeEnum: AIModelType? {
        guard let t = modelType else { return nil }
        return AIModelType(rawValue: t)
    }
}

// MARK: - 新增请求 DTO

struct UsersModelConfigAddDTO: Encodable {
    var modelType: String
    var modelName: String
    var baseUrl: String
    var apiKey: String
    var purpose: Int
    var isMultimodal: Int?
    var enabled: Int?
    var extraConfig: AnyCodable?
    var remarks: String?

    init(modelType: String,
         modelName: String,
         baseUrl: String,
         apiKey: String,
         purpose: Int,
         isMultimodal: Int? = 0,
         enabled: Int? = 1,
         extraConfig: AnyCodable? = nil,
         remarks: String? = nil) {
        self.modelType = modelType
        self.modelName = modelName
        self.baseUrl = baseUrl
        self.apiKey = apiKey
        self.purpose = purpose
        self.isMultimodal = isMultimodal
        self.enabled = enabled
        self.extraConfig = extraConfig
        self.remarks = remarks
    }
}

// MARK: - 更新请求 DTO

struct UsersModelConfigUpdateDTO: Encodable {
    var id: String
    var modelType: String?
    var modelName: String?
    var baseUrl: String?
    var apiKey: String?
    var purpose: Int?
    var isMultimodal: Int?
    var enabled: Int?
    var extraConfig: AnyCodable?
    var remarks: String?

    init(id: String,
         modelType: String? = nil,
         modelName: String? = nil,
         baseUrl: String? = nil,
         apiKey: String? = nil,
         purpose: Int? = nil,
         isMultimodal: Int? = nil,
         enabled: Int? = nil,
         extraConfig: AnyCodable? = nil,
         remarks: String? = nil) {
        self.id = id
        self.modelType = modelType
        self.modelName = modelName
        self.baseUrl = baseUrl
        self.apiKey = apiKey
        self.purpose = purpose
        self.isMultimodal = isMultimodal
        self.enabled = enabled
        self.extraConfig = extraConfig
        self.remarks = remarks
    }
}

// MARK: - 删除请求 DTO

struct UsersModelConfigDeleteDTO: Encodable {
    let id: String

    init(id: String) {
        self.id = id
    }
}

// MARK: - 单条查询请求 DTO

struct UsersModelConfigIdQueryDTO: Encodable {
    let id: String

    init(id: String) {
        self.id = id
    }
}

// MARK: - 编辑表单 ViewModel（编辑/新增共用）

/// 编辑页表单数据，编辑/新增共用。提交时按"是否已有 id"区分 add vs update。
final class AIModelConfigEditForm: ObservableObject {
    /// 业务 id（新增时为 nil）
    @Published var id: String?
    /// 模型类型（subCode）
    @Published var modelType: String = AIModelType.deepseek.rawValue
    /// 模型名称
    @Published var modelName: String = ""
    /// 请求地址
    @Published var baseUrl: String = ""
    /// API Token
    @Published var apiKey: String = ""
    /// 用途：1=主模型，2=OCR
    @Published var purpose: Int = AIModelPurpose.main.rawValue
    /// 是否多模态
    @Published var isMultimodal: Bool = false
    /// 是否启用
    @Published var enabled: Bool = true
    /// 备注
    @Published var remarks: String = ""
    /// 可配置参数（来自默认 configParams，可编辑）
    @Published var configParams: [String: AnyCodable] = [:]

    /// 从 DTO 加载（编辑模式）
    init(dto: UsersModelConfigDTO? = nil) {
        if let dto = dto {
            self.id = dto.id
            self.modelType = dto.modelType ?? AIModelType.deepseek.rawValue
            self.modelName = dto.modelName ?? ""
            self.baseUrl = dto.baseUrl ?? ""
            self.apiKey = dto.apiKey ?? ""
            self.purpose = dto.purpose ?? AIModelPurpose.main.rawValue
            self.isMultimodal = dto.isMultimodalFlag
            self.enabled = dto.isEnabled
            self.remarks = dto.remarks ?? ""
        }
    }

    /// 加载系统默认 baseUrl / canSelectModels / configParams（不覆盖用户已填值）
    func applyDefault(dto: SysConfigDTO, canSelectModels: [String]) {
        if self.baseUrl.trimmingCharacters(in: .whitespaces).isEmpty {
            self.baseUrl = dto.config ?? ""
        }
        if self.modelName.trimmingCharacters(in: .whitespaces).isEmpty,
           let first = canSelectModels.first {
            self.modelName = first
        }
        // 仅当用户尚未编辑过 configParams 时填入默认值（编辑已有配置时不覆盖）
        if self.configParams.isEmpty,
           let defaults = dto.jsonConfig?.configParams {
            self.configParams = defaults
        }
    }

    /// 校验必填字段
    func validate() -> String? {
        if modelType.trimmingCharacters(in: .whitespaces).isEmpty {
            return "请选择模型类型"
        }
        if modelName.trimmingCharacters(in: .whitespaces).isEmpty {
            return "请填写模型名称"
        }
        if baseUrl.trimmingCharacters(in: .whitespaces).isEmpty {
            return "请填写请求地址"
        }
        if apiKey.trimmingCharacters(in: .whitespaces).isEmpty {
            return "请填写 API Token"
        }
        if AIModelPurpose(rawValue: purpose) == nil {
            return "请选择用途"
        }
        return nil
    }

    /// 是否编辑模式（已有 id）
    var isEdit: Bool { id != nil && !(id?.isEmpty ?? true) }
}

// MARK: - 常量

/// 用户级 AI 配置常量
enum AIConfigConst {
    /// listbycode 接口使用的 code
    static let code = "AI_VENDORS"
}
