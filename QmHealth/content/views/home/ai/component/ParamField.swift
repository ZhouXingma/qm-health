//
//  ParamField.swift
//  QmHealth
//
//  可配置参数的单行编辑器（按字段语义智能渲染）
//
//  - ParamFieldResolver 根据字段名（如 "temperature"、"reasoningEffort"）
//    映射到 ParamFieldKind，决定 UI 形态。
//  - 支持：概率滑块（0-2）、Token 滑块（256-32K）、枚举选择、布尔、整数、JSON 编辑。
//  - 未知字段按实际值类型降级展示。
//  - 每个已知字段都附带一行"是什么/怎么用"的中文说明，方便用户理解参数含义。
//
//  设计要点：
//  - 不在 View body 中捕获 AnyCodable 内部值的快照（之前出现过崩溃）
//  - 复杂字段（executionConfig / additionalHeaders 等）折叠为 JSON 编辑器
//

import SwiftUI

// MARK: - ParamFieldKind 字段语义

/// 字段语义类型：决定 UI 渲染形态
enum ParamFieldKind: Equatable {
    /// 0-2 浮点滑块（temperature / topP / frequencyPenalty / presencePenalty）
    case probabilitySlider
    /// 0-32000 整数滑块（maxTokens / maxCompletionTokens / thinkingBudget）
    case tokenSlider
    /// 枚举选择（reasoningEffort / toolChoice / responseFormat 等）
    case enumPicker(options: [String])
    /// 布尔开关（parallelToolCalls / reasoningSplit / cacheControl）
    case booleanToggle
    /// 整数输入（seed）
    case integerField
    /// 复杂对象 JSON 编辑（executionConfig / additionalHeaders 等）
    case jsonEditor
    /// 字符串（兜底）
    case stringField
    /// 只读展示（兜底）
    case readOnly
}

// MARK: - ParamFieldDescriptor 字段说明

/// 单个参数的中文说明。title 为 nil 时使用默认 prettyKey；description 为空时该字段不显示说明行
struct ParamFieldDescriptor {
    /// 标题（覆盖默认 camelCase -> Title Case）
    let title: String?
    /// 一句话说明（中文）
    let description: String

    init(title: String? = nil, description: String) {
        self.title = title
        self.description = description
    }
}

/// 集中维护已知字段的展示说明。
///
/// 新增字段时在这里补充；未在此处声明的字段会自动使用 camelCase 标题且不显示说明。
private let fieldDescriptors: [String: ParamFieldDescriptor] = [
    // MARK: 采样与惩罚
    "temperature":       ParamFieldDescriptor(description: "采样温度；0 最确定，2 最随机；值越高越发散"),
    "topP":              ParamFieldDescriptor(description: "核采样阈值；0~1；值越高候选 token 越多"),
    "frequencyPenalty":  ParamFieldDescriptor(description: "频率惩罚；-2~2；正值减少重复用词"),
    "presencePenalty":   ParamFieldDescriptor(description: "存在惩罚；-2~2；正值鼓励新话题"),

    // MARK: Token 上限
    "maxTokens":           ParamFieldDescriptor(description: "单次回复最大 token 数"),
    "maxCompletionTokens": ParamFieldDescriptor(description: "回复 token 上限（OpenAI 新参数名）"),
    "thinkingBudget":      ParamFieldDescriptor(description: "思维链最大 token 数；0 表示不限"),

    // MARK: 推理 / 思维链
    "reasoningEffort": ParamFieldDescriptor(description: "推理努力程度；low 更快、high 更深"),
    "thinking":        ParamFieldDescriptor(title: "Thinking（思维链）", description: "开启后模型先输出思考过程再回答（仅部分模型支持）"),
    "reasoningSplit":  ParamFieldDescriptor(description: "将思考过程与正文分开渲染"),

    // MARK: 输出控制
    "toolChoice":       ParamFieldDescriptor(description: "auto 自动调用 / none 禁用 / required 强制调用"),
    "responseFormat":   ParamFieldDescriptor(description: "json 强制 JSON / text 普通文本"),
    "parallelToolCalls": ParamFieldDescriptor(description: "允许模型在同一次响应中并行调用多个工具"),

    // MARK: 其它
    "seed":         ParamFieldDescriptor(description: "随机种子；相同 seed 可复现结果（设为 null 关闭）"),
    "cacheControl": ParamFieldDescriptor(description: "启用提示缓存以节省费用"),

    // MARK: 复杂对象
    "executionConfig":      ParamFieldDescriptor(description: "执行配置（高级 JSON）"),
    "additionalHeaders":    ParamFieldDescriptor(description: "附加 HTTP 请求头，键值对"),
    "additionalBodyParams": ParamFieldDescriptor(description: "附加请求体参数，键值对"),
    "additionalQueryParams": ParamFieldDescriptor(description: "附加 URL 查询参数，键值对"),
]

// MARK: - ParamFieldResolver 字段名 -> UI 类型映射

enum ParamFieldResolver {

    /// 根据字段名 + 当前值解析出 UI 类型
    static func resolve(key: String, value: AnyCodable?) -> ParamFieldKind {
        switch key {
        // 概率 / 惩罚类（0-2 浮点）
        case "temperature", "topP", "frequencyPenalty", "presencePenalty":
            return .probabilitySlider
        // Token 数（整数，256-32000）
        case "maxTokens", "maxCompletionTokens", "thinkingBudget":
            return .tokenSlider
        // 枚举
        case "reasoningEffort":
            return .enumPicker(options: ["low", "medium", "high"])
        case "toolChoice":
            return .enumPicker(options: ["auto", "none", "required"])
        case "responseFormat":
            return .enumPicker(options: ["json", "text"])
        // thinking 是嵌套对象 { type: "enabled" }，扁平化为 boolean
        case "thinking":
            return .booleanToggle
        // 布尔
        case "parallelToolCalls", "reasoningSplit", "cacheControl":
            return .booleanToggle
        // 整数（seed 是 long）
        case "seed":
            return .integerField
        // 复杂对象 JSON
        case "executionConfig",
             "additionalHeaders",
             "additionalBodyParams",
             "additionalQueryParams":
            return .jsonEditor
        default:
            // 未知字段：按当前值类型推断
            guard let v = value?.value else {
                return .stringField
            }
            if v is Bool { return .booleanToggle }
            if v is Int { return .integerField }
            if v is Double { return .probabilitySlider }
            if v is String { return .stringField }
            if v is [String: AnyCodable] || v is [Any] {
                return .jsonEditor
            }
            return .readOnly
        }
    }
}

// MARK: - ParamField 单行编辑器入口

struct ParamField: View {
    /// 参数名（如 "temperature"）
    let key: String
    /// 当前值
    let value: AnyCodable?
    /// 修改回调：返回新的 AnyCodable
    let onChange: (AnyCodable) -> Void

    var body: some View {
        let descriptor = fieldDescriptors[key]
        let displayName = descriptor?.title ?? prettyKey(key)
        let description = descriptor?.description ?? ""
        let kind = ParamFieldResolver.resolve(key: key, value: value)
        switch kind {
        case .probabilitySlider:
            ProbabilitySliderField(
                key: key,
                displayName: displayName,
                description: description,
                value: value,
                onChange: onChange
            )
        case .tokenSlider:
            TokenSliderField(
                key: key,
                displayName: displayName,
                description: description,
                value: value,
                onChange: onChange
            )
        case .enumPicker(let options):
            EnumPickerField(
                key: key,
                displayName: displayName,
                description: description,
                value: value,
                options: options,
                onChange: onChange
            )
        case .booleanToggle:
            BooleanToggleField(
                key: key,
                displayName: displayName,
                description: description,
                value: value,
                onChange: onChange
            )
        case .integerField:
            IntegerField(
                key: key,
                displayName: displayName,
                description: description,
                value: value,
                onChange: onChange
            )
        case .jsonEditor:
            JsonEditorField(
                key: key,
                displayName: displayName,
                description: description,
                value: value,
                onChange: onChange
            )
        case .stringField:
            StringField(
                key: key,
                displayName: displayName,
                description: description,
                value: value,
                onChange: onChange
            )
        case .readOnly:
            ReadOnlyField(
                key: key,
                displayName: displayName,
                description: description,
                value: value
            )
        }
    }
}

// MARK: - 字段说明行（统一渲染）

/// 标题下方的说明行（11pt 灰字，单行省略）
private struct FieldDescription: View {
    let text: String

    var body: some View {
        if text.isEmpty {
            EmptyView()
        } else {
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(AppColor.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - 字段标题统一样式

/// 标题（key 名转 pretty 形式）
private struct FieldLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(AppColor.textPrimary)
            .lineLimit(1)
    }
}

/// 把 camelCase 拆成空格分隔：responseFormat -> Response Format
private func prettyKey(_ key: String) -> String {
    guard !key.isEmpty else { return key }
    var result = ""
    for (i, ch) in key.enumerated() {
        if i == 0 {
            result.append(ch.uppercased())
        } else if ch.isUppercase {
            result.append(" ")
            result.append(ch)
        } else {
            result.append(ch)
        }
    }
    return result
}

// MARK: - ProbabilitySliderField（0-2 浮点）

private struct ProbabilitySliderField: View {
    let key: String
    let displayName: String
    let description: String
    let value: AnyCodable?
    let onChange: (AnyCodable) -> Void

    @State private var sliderValue: Double = 0.7
    @State private var hasInitialized: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                FieldLabel(text: displayName)
                Spacer()
                Text(String(format: "%.2f", sliderValue))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColor.primary)
            }
            Slider(value: $sliderValue, in: 0...2, step: 0.05) { _ in
                onChange(AnyCodable(sliderValue))
            }
            .tint(AppColor.primary)
            FieldDescription(text: description)
        }
        .onAppear {
            guard !hasInitialized else { return }
            if let d = value?.value as? Double {
                sliderValue = d
            } else if let i = value?.value as? Int {
                sliderValue = Double(i)
            }
            hasInitialized = true
        }
    }
}

// MARK: - TokenSliderField（256-32000 整数）

private struct TokenSliderField: View {
    let key: String
    let displayName: String
    let description: String
    let value: AnyCodable?
    let onChange: (AnyCodable) -> Void

    @State private var sliderValue: Double = 2048
    @State private var hasInitialized: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                FieldLabel(text: displayName)
                Spacer()
                Text("\(Int(sliderValue))")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColor.primary)
            }
            Slider(value: $sliderValue, in: 256...32000, step: 128) { _ in
                onChange(AnyCodable(Int(sliderValue)))
            }
            .tint(AppColor.primary)
            // 快捷档位
            HStack(spacing: 6) {
                ForEach([512, 2048, 4096, 8192, 16384], id: \.self) { preset in
                    Button {
                        sliderValue = Double(preset)
                        onChange(AnyCodable(preset))
                    } label: {
                        Text(formatPreset(preset))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Int(sliderValue) == preset ? .white : AppColor.textSecondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(Int(sliderValue) == preset ? AppColor.primary : AppColor.background)
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            FieldDescription(text: description)
        }
        .onAppear {
            guard !hasInitialized else { return }
            if let i = value?.value as? Int {
                sliderValue = Double(max(256, min(32000, i)))
            } else if let d = value?.value as? Double {
                sliderValue = max(256, min(32000, d))
            }
            hasInitialized = true
        }
    }

    private func formatPreset(_ n: Int) -> String {
        if n >= 1024 {
            return "\(n / 1024)K"
        }
        return "\(n)"
    }
}

// MARK: - EnumPickerField（枚举选择）

private struct EnumPickerField: View {
    let key: String
    let displayName: String
    let description: String
    let value: AnyCodable?
    let options: [String]
    let onChange: (AnyCodable) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                FieldLabel(text: displayName)
                Spacer()
                Menu {
                    ForEach(options, id: \.self) { opt in
                        Button {
                            onChange(AnyCodable(opt))
                        } label: {
                            if currentStringValue == opt {
                                Label(opt, systemImage: "checkmark")
                            } else {
                                Text(opt)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(currentStringValue ?? "未设置")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(currentStringValue == nil ? AppColor.textSecondary : AppColor.textPrimary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(AppColor.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(AppColor.background))
                }
            }
            FieldDescription(text: description)
        }
    }

    private var currentStringValue: String? {
        return value?.value as? String
    }
}

// MARK: - BooleanToggleField（布尔）

private struct BooleanToggleField: View {
    let key: String
    let displayName: String
    let description: String
    let value: AnyCodable?
    let onChange: (AnyCodable) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    FieldLabel(text: displayName)
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(AppColor.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { currentBool },
                    set: { onChange(AnyCodable($0)) }
                ))
                .labelsHidden()
                .tint(AppColor.primary)
            }
        }
    }

    private var currentBool: Bool {
        if let b = value?.value as? Bool { return b }
        return false
    }

    /// 读取 thinking.type == "enabled"
    private var thinkingEnabled: Bool {
        guard let dict = value?.value as? [String: AnyCodable] else {
            // 兼容扁平布尔（之前版本的格式）
            return currentBool
        }
        return dict["type"]?.stringValue == "enabled"
    }
}

// MARK: - IntegerField（整数输入）

private struct IntegerField: View {
    let key: String
    let displayName: String
    let description: String
    let value: AnyCodable?
    let onChange: (AnyCodable) -> Void

    @State private var text: String = ""
    @State private var hasInitialized: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                FieldLabel(text: displayName)
                Spacer()
                TextField("", text: $text)
                    .keyboardType(.numberPad)
                    .font(.system(size: 13, design: .monospaced))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
                    .onChange(of: text) { _, newValue in
                        if newValue.isEmpty { return }
                        if let v = Int(newValue) {
                            onChange(AnyCodable(v))
                        }
                    }
            }
            FieldDescription(text: description)
        }
        .onAppear {
            guard !hasInitialized else { return }
            if let i = value?.value as? Int {
                text = "\(i)"
            } else if let d = value?.value as? Double {
                text = "\(Int(d))"
            }
            hasInitialized = true
        }
    }
}

// MARK: - StringField（字符串）

private struct StringField: View {
    let key: String
    let displayName: String
    let description: String
    let value: AnyCodable?
    let onChange: (AnyCodable) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                FieldLabel(text: displayName)
                    .lineLimit(1)
                Spacer(minLength: 8)
                TextField("", text: Binding(
                    get: { value?.value as? String ?? "" },
                    set: { onChange(AnyCodable($0)) }
                ))
                .font(.system(size: 13, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 160)
            }
            FieldDescription(text: description)
        }
    }
}

// MARK: - JsonEditorField（复杂对象）

/// 复杂对象折叠为 JSON 编辑器：展开后是一个多行 TextField，输入/展示 JSON 字符串
private struct JsonEditorField: View {
    let key: String
    let displayName: String
    let description: String
    let value: AnyCodable?
    let onChange: (AnyCodable) -> Void

    @State private var isExpanded: Bool = false
    @State private var text: String = ""
    @State private var hasInitialized: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    FieldLabel(text: displayName)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColor.textSecondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                TextField("{}", text: $text, axis: .vertical)
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(3...8)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(AppColor.background))
                    .onChange(of: text) { _, newValue in
                        // 解析 JSON，解析成功才回写
                        if let data = newValue.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
                            onChange(AnyCodable(json))
                        }
                    }
            }
            FieldDescription(text: description)
        }
        .onAppear {
            guard !hasInitialized else { return }
            text = serializeValue()
            hasInitialized = true
        }
    }

    /// 把当前 AnyCodable 值序列化成 JSON 字符串作为初始展示
    private func serializeValue() -> String {
        guard let v = value?.value else { return "" }
        // 把 Any 转 AnyCodable 再转 JSON
        let wrapped = AnyCodable(v)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(wrapped),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return ""
    }
}

// MARK: - ReadOnlyField（只读展示）

private struct ReadOnlyField: View {
    let key: String
    let displayName: String
    let description: String
    let value: AnyCodable?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                FieldLabel(text: displayName)
                Spacer(minLength: 8)
                Text(String(describing: value?.value ?? ""))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(AppColor.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }
            FieldDescription(text: description)
        }
    }
}
