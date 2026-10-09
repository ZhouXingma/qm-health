//
//  AIAskUserResponseView.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/2/10.
//

import SwiftUI

// MARK: - AIAskUserResponseView - 显示用户对 ask_user 工具的回复
struct AIAskUserResponseView: View {
    let toolUse: ToolUseBlockMessage
    let result: String
    
    @State private var askUserInput: AskUserToolInput?
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏 - 整个区域可点击折叠
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    ChatStatusDot(status: .done, size: 7)
                    
                    Text("用户回复")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(ChatTheme.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(ChatTheme.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, ChatTheme.spacingMd)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // 内容区域 - 展开时显示
            if isExpanded {
                Divider()
                    .background(ChatTheme.hairline)
                    .padding(.horizontal, ChatTheme.spacingMd)
                
                VStack(alignment: .leading, spacing: 8) {
                    // 显示问题标题
                    if let input = askUserInput {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("问题")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(ChatTheme.textSecondary.opacity(0.7))
                                .textCase(.uppercase)
                            
                            Text(input.question)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(ChatTheme.textPrimary)
                                .lineSpacing(2)
                        }
                    }
                    
                    // 显示用户的回复内容
                    VStack(alignment: .leading, spacing: 3) {
                        Text("用户回复")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(ChatTheme.textSecondary.opacity(0.7))
                            .textCase(.uppercase)
                        
                        // 🔑 关键修复：多级降级策略确保总能正确渲染
                        // 使用 Group 来包裹条件渲染，确保 ViewBuilder 正确工作
                        // 1. 优先使用主解析结果（askUserInput）
                        // 2. 如果主解析失败，尝试备用解析（tryParseFallbackInput）
                        // 3. 如果所有解析都失败，显示原始值
                        Group {
                            if let input = askUserInput {
                                // 主解析成功，根据问题类型渲染
                                if !input.isSingleQuestion {
                                    // 多字段场景：解析 result JSON，逐字段展示 label + 可读值
                                    multiFieldResponseView(result, input: input)
                                } else {
                                    // 单问题场景：根据交互类型渲染对应组件
                                    singleResponseView(result, for: input)
                                }
                            } else if let fallbackInput = tryParseFallbackInput() {
                                // 备用解析成功，同样根据类型渲染
                                // 使用 let _ = print() 避免在 ViewBuilder 中直接调用 print
                                if !fallbackInput.isSingleQuestion {
                                    let _ = print("✅ 备用解析成功（多字段），使用 fallbackInput 渲染")
                                    multiFieldResponseView(result, input: fallbackInput)
                                } else {
                                    let _ = print("✅ 备用解析成功（单问题），使用 fallbackInput 渲染")
                                    singleResponseView(result, for: fallbackInput)
                                }
                            } else {
                                // 所有解析都失败，最后的降级方案：显示原始 result 值
                                let _ = print("⚠️ 所有解析都失败，显示原始 result")
                                Text(result)
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(ChatTheme.textPrimary)
                                    .lineSpacing(2)
                                    .padding(7)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color("input_bg").opacity(0.3))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                .padding(.horizontal, ChatTheme.spacingMd)
                .padding(.vertical, ChatTheme.spacingSm)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: ChatTheme.radiusMd)
                .fill(ChatTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChatTheme.radiusMd)
                .stroke(ChatTheme.hairline, lineWidth: 1)
        )
        .onAppear {
            // 视图出现时尝试解析 ask_user 工具的输入参数
            askUserInput = toolUse.parseAsAskUserInput()
            if askUserInput != nil {
                print("✅ AIAskUserResponseView 解析成功")
            } else {
                print("⚠️ AIAskUserResponseView 主解析失败，后续将尝试备用解析")
            }
        }
    }
    
    // MARK: - 备用输入解析
    /// 如果主解析失败，尝试从 toolUse 的多个属性解析
    private func tryParseFallbackInput() -> AskUserToolInput? {
        // 如果 askUserInput 已经成功解析，就不需要备用了
        if askUserInput != nil { return askUserInput }
        
        do {
            let decoder = JSONDecoder()
            
            // 方案 1：从 input.dictValue 解析（完整对象）
            if let dictValue = toolUse.input.dictValue, !dictValue.isEmpty {
                let jsonData = try JSONSerialization.data(withJSONObject: dictValue)
                if let parsed = try? decoder.decode(AskUserToolInput.self, from: jsonData) {
                    return parsed
                }
            }
            
            // 方案 2：从 input.stringValue 解析（JSON 字符串）
            if let stringValue = toolUse.input.stringValue, !stringValue.isEmpty,
               let data = stringValue.data(using: .utf8) {
                if let parsed = try? decoder.decode(AskUserToolInput.self, from: data) {
                    return parsed
                }
            }
            
            // 方案 3：从 content 解析（流式传输的 JSON 字符串）
            if let contentStr = toolUse.content, !contentStr.isEmpty,
               let data = contentStr.data(using: .utf8) {
                if let parsed = try? decoder.decode(AskUserToolInput.self, from: data) {
                    return parsed
                }
            }
            
            return nil
        } catch {
            print("❌ Fallback AskUserToolInput parsing failed: \(error)")
            return nil
        }
    }
    
    // MARK: - 多字段回复展示
    @ViewBuilder
    private func multiFieldResponseView(_ value: String, input: AskUserToolInput) -> some View {
        // 尝试把 result 解析为 [String: Any] 字典
        let dict: [String: Any] = parseResultDict(value)
        let fields = input.fields ?? []
        
        if dict.isEmpty || fields.isEmpty {
            VStack {
                Text("\(dict)")
                Text("\(fields)")
                // 解析失败，降级展示原始文本
                Text(value)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(ChatTheme.textPrimary)
                    .lineSpacing(2)
                    .padding(10)
                    .background(Color("input_bg").opacity(0.5))
                    .cornerRadius(8)
            }
            
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(fields, id: \.name) { field in
                    if let rawVal = dict[field.name] {
                        fieldValueView(rawVal: rawVal, field: field)
                    }
                }
            }
        }
    }
    
    // MARK: - 单个字段值的差异化展示
    @ViewBuilder
    private func fieldValueView(rawVal: Any, field: AskUserField) -> some View {
        let strVal = String(describing: rawVal)
        
        switch field.effectiveType {
        case "select":
            // 单选：映射 option label，用 chip 展示
            let label = field.options?.first(where: { $0.value == strVal })?.label ?? strVal
            fieldResponseRow(label: field.label) {
                responseChip(label: label)
            }
            
        case "multiSelect":
            // 多选：解析 JSON 数组或逗号分隔，每个值用 chip 展示
            let selectedValues: [String] = {
                if let arr = rawVal as? [Any] {
                    return arr.map { String(describing: $0) }
                }
                if let data = strVal.data(using: .utf8),
                   let arr = try? JSONSerialization.jsonObject(with: data) as? [String] {
                    return arr
                }
                return strVal.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            }()
            if !selectedValues.isEmpty {
                fieldResponseRow(label: field.label) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(selectedValues, id: \.self) { sv in
                            let chipLabel = field.options?.first(where: { $0.value == sv })?.label ?? sv
                            responseChip(label: chipLabel)
                        }
                    }
                }
            }
            
        case "dateTime":
            // 日期时间：日历图标 + 值
            if !strVal.isEmpty {
                fieldResponseRow(label: field.label) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(ChatTheme.accent)
                        Text(strVal)
                            .font(.system(size: 11))
                            .foregroundColor(ChatTheme.textPrimary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ChatTheme.accent.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(ChatTheme.accent.opacity(0.2), lineWidth: 1)
                    )
                }
            }
            
        default:
            // text / number / url 等：纯文本展示，附带 unit 后缀
            let displayVal: String = {
                if let unit = field.unit, !unit.isEmpty {
                    return "\(strVal) \(unit)"
                }
                return strVal
            }()
            if !displayVal.isEmpty {
                fieldResponseRow(label: field.label) {
                    Text(displayVal)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(ChatTheme.textPrimary)
                        .lineSpacing(2)
                        .padding(7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color("input_bg").opacity(0.3))
                        .cornerRadius(6)
                }
            }
        }
    }
    
    // MARK: - 单问题回复展示
    @ViewBuilder
    private func singleResponseView(_ value: String, for input: AskUserToolInput) -> some View {
        switch input.effectiveInteractiveType {
        case "select":
            // 🔑 关键：先解析 JSON 字符串（如果是的话），然后从 options 中查找 value 对应的 label
            let actualValue = parseJsonStringValue(value)
            let label = input.options?.first(where: { $0.value == actualValue })?.label ?? actualValue
            responseChip(label: label)
            
        case "multiSelect":
            let selectedValues: [String] = {
                // 优先尝试解析 JSON 数组格式，如 ["A","B","C"]
                if let data = value.data(using: .utf8),
                   let arr = try? JSONSerialization.jsonObject(with: data) as? [String] {
                    return arr
                }
                // 降级：逗号分割
                return value.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            }()
            VStack(alignment: .leading, spacing: 5) {
                ForEach(selectedValues, id: \.self) { sv in
                    // 🔑 关键：从 options 中查找每个 value 对应的 label
                    let label = input.options?.first(where: { $0.value == sv })?.label ?? sv
                    responseChip(label: label)
                }
            }
            
        case "dateTime":
            // 日期时间也需要解析 JSON 字符串
            let actualValue = parseJsonStringValue(value)
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(ChatTheme.accent)
                Text(actualValue)
                    .font(.system(size: 11))
                    .foregroundColor(ChatTheme.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(ChatTheme.accent.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(ChatTheme.accent.opacity(0.2), lineWidth: 1)
            )
            
        default:
            // 其他类型也需要解析 JSON 字符串
            let actualValue = parseJsonStringValue(value)
            Text(actualValue)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(ChatTheme.textPrimary)
                .lineSpacing(2)
                .padding(7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color("input_bg").opacity(0.3))
                .cornerRadius(6)
        }
    }
    
    // MARK: - 单个字段行（ViewBuilder 内容版）
    @ViewBuilder
    private func fieldResponseRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Color("text_secondary").opacity(0.7))
                .textCase(.uppercase)
            content()
        }
    }
    
    // MARK: - 选项标签
    @ViewBuilder
    private func responseChip(label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(ChatTheme.accent)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(ChatTheme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(ChatTheme.accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(ChatTheme.accent.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - 工具方法
    
    /// 解析可能是 JSON 编码的字符串值
    /// 例如：将 "\"yes\"" 解析为 "yes"，或直接返回 "yes"
    private func parseJsonStringValue(_ value: String) -> String {
        // 如果是 JSON 字符串（例如 "\"yes\""），尝试解码
        if let data = value.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(String.self, from: data) {
            return decoded
        }
        // 否则直接返回原值
        return value
    }
    
    /// 把 result 字符串解析为字典
    /// 支持两种格式：
    /// 1. 标准 JSON：{"key":"value"}
    /// 2. Swift description 格式：["key": "value", "key2": "value2"]
    private func parseResultDict(_ value: String) -> [String: Any] {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        
        // 1. 标准 JSON 对象
        if trimmed.hasPrefix("{"),
           let data = trimmed.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return dict
        }
        
        // 2. Swift description 格式：["key": "value", ...]
        // 转换为合法 JSON：把外层 [ ] 换成 { }，把 ": " 保留，处理引号
        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
            // 去掉首尾方括号，换成花括号
            let inner = String(trimmed.dropFirst().dropLast())
            let jsonString = "{\(inner)}"
            if let data = jsonString.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return dict
            }
        }
        
        print("❌ parseResultDict failed for: \(value)")
        return [:]
    }
}
