//
//  AskUserTool.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/2/10.
//

import Foundation

// MARK: - AskUserToolInput - ask_user 工具的输入参数
/// 对应 Java 中的 HitlTool.ASK_USER schema
struct AskUserToolInput: Codable {
    /// 要向用户呈现的提示文案；多字段表单时作为整体的引导语
    let question: String
    
    /// 单问题场景的交互组件类型: text(纯文本，默认) | select(单选) | multiSelect(多选) | dateTime(日期时间) | url(链接)
    /// 多字段场景下用 fields 描述，本字段可忽略
    let interactiveType: String?
    
    /// 选项列表，select/multiSelect/url 类型时填写；text/dateTime 不需要
    let options: [AskUserOption]?
    
    /// dateTime 组件子类型: date(仅日期) | time(仅时间) | datetime(日期+时间)
    let dateTimeType: String?
    
    /// dateTime 组件的默认值（可选，ISO 格式）
    let defaultValue: String?
    
    /// 多字段表单：一次收集多个信息时使用；用户会在同一张表单里依次填写、一起提交
    let fields: [AskUserField]?
    
    enum CodingKeys: String, CodingKey {
        case question
        case interactiveType
        case options
        case dateTimeType
        case defaultValue
        case fields
    }
    
    init(
        question: String,
        interactiveType: String? = nil,
        options: [AskUserOption]? = nil,
        dateTimeType: String? = nil,
        defaultValue: String? = nil,
        fields: [AskUserField]? = nil
    ) {
        self.question = question
        self.interactiveType = interactiveType
        self.options = options
        self.dateTimeType = dateTimeType
        self.defaultValue = defaultValue
        self.fields = fields
    }
    
    /// 判断是否为单问题场景
    var isSingleQuestion: Bool {
        return fields == nil || fields?.isEmpty ?? true
    }
    
    /// 获取有效的交互类型（默认为 text）
    var effectiveInteractiveType: String {
        return interactiveType ?? "text"
    }
}

// MARK: - AskUserOption - 选项项
struct AskUserOption: Codable, Identifiable {
    let label: String
    let value: String
    
    var id: String { value }
    
    enum CodingKeys: String, CodingKey {
        case label
        case value
    }
    
    init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}

// MARK: - AskUserField - 多字段表单中的单个字段
struct AskUserField: Codable, Identifiable {
    /// 字段标识（驼峰命名，例如 heightCm、weightKg）
    let name: String
    
    /// 展示给用户的问题/字段名，例如 身高、体重
    let label: String
    
    /// 字段输入组件类型: text(单行文本，默认) | number(数字) | select | multiSelect | dateTime | url
    let type: String?
    
    /// 输入框占位提示（可选），例如 "请输入厘米数"
    let placeholder: String?
    
    /// 单位后缀（可选），例如 cm、kg、岁
    let unit: String?
    
    /// 是否必填，默认 true
    let required: Bool?
    
    /// 仅 select/multiSelect 时填写；候选项列表
    let options: [AskUserOption]?
    
    /// 仅 dateTime 时填写
    let dateTimeType: String?
    
    /// 预填默认值（可选）
    let defaultValue: String?
    
    var id: String { name }
    
    enum CodingKeys: String, CodingKey {
        case name
        case label
        case type
        case placeholder
        case unit
        case required
        case options
        case dateTimeType
        case defaultValue
    }
    
    init(
        name: String,
        label: String,
        type: String? = nil,
        placeholder: String? = nil,
        unit: String? = nil,
        required: Bool? = nil,
        options: [AskUserOption]? = nil,
        dateTimeType: String? = nil,
        defaultValue: String? = nil
    ) {
        self.name = name
        self.label = label
        self.type = type
        self.placeholder = placeholder
        self.unit = unit
        self.required = required
        self.options = options
        self.dateTimeType = dateTimeType
        self.defaultValue = defaultValue
    }
    
    /// 获取有效的字段类型（默认为 text）
    var effectiveType: String {
        return type ?? "text"
    }
    
    /// 是否为必填（默认为 true）
    var isRequired: Bool {
        return required ?? true
    }
}

// MARK: - AskUserResponse - 用户回复的数据结构
/// 用于将用户的回复转换为 InteractiveHandleBlockMessage
struct AskUserResponse: Codable {
    /// 单问题场景：用户的回复值（支持 String、[String]、Double 等类型）
    var value: AnyCodable?
    
    /// 多字段场景：用户填写的多个字段值（value 支持 String、[String] 等类型）
    var fieldValues: [String: AnyCodable]?
    
    init(value: AnyCodable? = nil, fieldValues: [String: AnyCodable]? = nil) {
        self.value = value
        self.fieldValues = fieldValues
    }
    
    /// 转换为 AnyCodable 用于 InteractiveHandleBlockMessage
    func toAnyCodable() -> AnyCodable {
        if let fieldValues = fieldValues {
            // 保留 AnyCodable 包装，避免 [String: Any] 中 [String] 数组无法被 JSONEncoder 正确编码
            return AnyCodable(fieldValues)
        } else if let value = value {
            return value
        }
        return AnyCodable([:])
    }
}

// MARK: - InteractiveType - 交互类型枚举
enum InteractiveType: String, CaseIterable {
    case text = "text"
    case select = "select"
    case multiSelect = "multiSelect"
    case dateTime = "dateTime"
    case url = "url"
    case number = "number"
    
    var displayName: String {
        switch self {
        case .text:
            return "文本"
        case .select:
            return "单选"
        case .multiSelect:
            return "多选"
        case .dateTime:
            return "日期时间"
        case .url:
            return "链接"
        case .number:
            return "数字"
        }
    }
}

// MARK: - DateTimeType - 日期时间类型枚举
enum DateTimeType: String, CaseIterable {
    case date = "date"
    case time = "time"
    case datetime = "datetime"
    
    var displayName: String {
        switch self {
        case .date:
            return "日期"
        case .time:
            return "时间"
        case .datetime:
            return "日期时间"
        }
    }
}

// MARK: - ToolUseBlockMessage 扩展 - 用于识别 ask_user 工具
extension ToolUseBlockMessage {
    /// 判断是否为 ask_user 工具
    var isAskUserTool: Bool {
        return name == "ask_user"
    }
    
    /// 尝试解析为 AskUserToolInput
    /// 支持三种情况：
    /// 1. 完整的 input 字典对象（非流式，最常见）
    /// 2. input 的字符串值（JSON 字符串格式）
    /// 3. 流式传输的 content 字符串（需要从 JSON 字符串解析）
    func parseAsAskUserInput() -> AskUserToolInput? {
        guard isAskUserTool else { 
            print("⚠️ parseAsAskUserInput: 不是 ask_user 工具，name=\(name)")
            return nil 
        }
        
        do {
            let decoder = JSONDecoder()
            
            // 方案 1：优先尝试从 input.dictValue 解析（完整的字典对象）
            if let dictValue = input.dictValue, !dictValue.isEmpty {
                print("📝 parseAsAskUserInput: 从 input.dictValue 解析")
                let jsonData = try JSONSerialization.data(withJSONObject: dictValue)
                let parsed = try decoder.decode(AskUserToolInput.self, from: jsonData)
                print("✅ parseAsAskUserInput 成功: question=\(parsed.question), type=\(parsed.effectiveInteractiveType)")
                return parsed
            }
            
            // 方案 2：尝试从 input.stringValue 解析（JSON 字符串）
            if let stringValue = input.stringValue, !stringValue.isEmpty {
                print("📝 parseAsAskUserInput: 从 input.stringValue 解析")
                if let data = stringValue.data(using: .utf8) {
                    let parsed = try decoder.decode(AskUserToolInput.self, from: data)
                    print("✅ parseAsAskUserInput 成功: question=\(parsed.question), type=\(parsed.effectiveInteractiveType)")
                    return parsed
                }
            }
            
            // 方案 3：如果 input 为空，尝试从 content 解析（流式传输）
            if let contentStr = content, !contentStr.isEmpty {
                print("📝 parseAsAskUserInput: 从 content 解析，length=\(contentStr.count)")
                if let contentData = contentStr.data(using: .utf8) {
                    let parsed = try decoder.decode(AskUserToolInput.self, from: contentData)
                    print("✅ parseAsAskUserInput 成功: question=\(parsed.question), type=\(parsed.effectiveInteractiveType)")
                    return parsed
                }
            }
            
            print("⚠️ parseAsAskUserInput: 所有解析方案都失败，input=\(input), content=\(content ?? "nil")")
            return nil
        } catch {
            print("❌ parseAsAskUserInput 解析失败: \(error)")
            print("   input.dictValue=\(input.dictValue ?? [:])")
            print("   input.stringValue=\(input.stringValue ?? "nil")")
            print("   content=\(content ?? "nil")")
            return nil
        }
    }
}

// MARK: - InteractiveHandleBlockMessage 扩展 - 序列化用户回复
extension InteractiveHandleBlockMessage {
    /// 把用户回复 value 序列化为 JSON 字符串
    /// - 字典：返回标准 JSON 对象字符串，如 {"key":"value"}
    /// - 数组：返回标准 JSON 数组字符串
    /// - 字符串/数字/布尔：返回原始描述
    /// 用于存入 ToolUseBlockMessage.result，保留结构以便 AIAskUserResponseView 解析
    func resultStringForToolUse() -> String {
        // 优先用 JSONEncoder 编码 AnyCodable，保证所有嵌套类型都能正确序列化
        if let data = try? JSONEncoder().encode(value),
           let str = String(data: data, encoding: .utf8) {
            print("📦 resultStringForToolUse: \(str)")
            return str
        }
        // 降级：标量直接返回字符串描述
        let raw = value.value
        if let s = raw as? String { return s }
        return String(describing: raw)
    }
}
