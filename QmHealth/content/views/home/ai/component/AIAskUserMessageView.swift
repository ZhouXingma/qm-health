//
//  AIAskUserMessageView.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/2/10.
//

import SwiftUI
import Combine

// MARK: - AIAskUserMessageView - ask_user 工具的交互界面
struct AIAskUserMessageView: View {
    let messageId: String
    let toolUse: ToolUseBlockMessage
    let onSubmit: ((InteractiveHandleBlockMessage) -> Void)?

    @State private var askUserInput: AskUserToolInput?
    @State private var isLoading: Bool = false
    @State private var hasSubmitted: Bool = false  // 标记是否已提交，防止重复点击

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if hasSubmitted {
                // 已提交，显示提交中的占位视图
                submittingView
            } else if let input = askUserInput {
                // 解析成功，根据问题类型渲染对应的表单
                if input.isSingleQuestion {
                    // 单问题场景：显示单个输入组件
                    AskUserSingleQuestionView(input: input, toolUse: toolUse, onSubmit: handleSubmit)
                } else {
                    // 多字段场景：显示完整表单
                    AskUserMultiFieldFormView(input: input, toolUse: toolUse, onSubmit: handleSubmit)
                }
            } else {
                // 解析失败或还在加载中，显示加载提示
                loadingView
            }
        }
        .onAppear {
            // 视图出现时立即尝试解析输入参数
            askUserInput = toolUse.parseAsAskUserInput()
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            // 只有在解析失败时才继续轮询（流式传输场景下 content 可能延迟到达）
            guard askUserInput == nil else { return }
            
            // 尝试重新解析，解析成功后停止轮询
            let newInput = toolUse.parseAsAskUserInput()
            if newInput != nil {
                askUserInput = newInput
            }
        }
    }

    private var loadingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.75, anchor: .center)
            Text("加载交互表单中…")
                .font(.system(size: 13))
                .foregroundColor(ChatTheme.textSecondary)
        }
        .padding(ChatTheme.spacingMd)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: ChatTheme.radiusMd).fill(ChatTheme.surface))
    }

    /// 已提交的占位视图，显示提交中状态
    private var submittingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.75, anchor: .center)
            Text("提交中，请稍候…")
                .font(.system(size: 13))
                .foregroundColor(ChatTheme.textSecondary)
        }
        .padding(ChatTheme.spacingMd)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: ChatTheme.radiusMd).fill(ChatTheme.accent.opacity(0.08)))
    }

    /// 处理用户提交的回复
    private func handleSubmit(_ response: AskUserResponse) {
        // 立即标记为已提交，防止重复点击
        hasSubmitted = true
        
        // 构建交互处理消息
        let interactiveHandle = InteractiveHandleBlockMessage(
            messageId: messageId,
            name: toolUse.name,
            toolCallId: toolUse.id,
            messageType: getMessageType(),
            value: response.toAnyCodable()
        )
        
        // 调用提交回调
        onSubmit?(interactiveHandle)
    }

    private func getMessageType() -> String {
        guard let input = askUserInput else { return "ask_user" }
        if !input.isSingleQuestion { return "fields" }
        return input.effectiveInteractiveType
    }
}

// MARK: - 共享外观：ask_user 卡片背景与问题标题
@ViewBuilder
func questionHeader(_ question: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
        Image(systemName: "quote.bubble.fill")
            .font(.system(size: 13))
            .foregroundStyle(ChatTheme.accent)
            .padding(.top, 2)
        Text(question)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(ChatTheme.textPrimary)
            .lineLimit(4)
    }
}

var askUserCardBackground: some View {
    RoundedRectangle(cornerRadius: ChatTheme.radiusMd)
        .fill(ChatTheme.accent.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: ChatTheme.radiusMd)
                .stroke(ChatTheme.accent.opacity(0.18), lineWidth: 1)
        )
}

// MARK: - AskUserSingleQuestionView - 单问题场景
struct AskUserSingleQuestionView: View {
    let input: AskUserToolInput
    let toolUse: ToolUseBlockMessage
    let onSubmit: (AskUserResponse) -> Void

    @State private var textValue: String = ""
    @State private var selectedValue: String = ""
    @State private var selectedValues: Set<String> = []
    @State private var selectedDate: Date = Date()
    @State private var numberValue: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            questionHeader(input.question)

            if input.effectiveInteractiveType == "url" {
                URLLinkButton(url: input.defaultValue)
            } else {
                inputField(for: input.effectiveInteractiveType)
                SimpleSubmitButton(action: submitResponse)
            }
        }
        .padding(ChatTheme.spacingLg)
        .background(askUserCardBackground)
    }

    @ViewBuilder
    private func inputField(for type: String) -> some View {
        switch type {
        case "text":
            TextInputField(value: $textValue, placeholder: "请输入内容")
        case "number":
            TextInputField(value: $numberValue, placeholder: "请输入数字", keyboardType: .decimalPad)
        case "select":
            SelectButtonsField(options: input.options ?? [], selectedValue: $selectedValue)
        case "multiSelect":
            MultiSelectButtonsField(options: input.options ?? [], selectedValues: $selectedValues)
        case "dateTime":
            DateTimePickerField(selectedDate: $selectedDate, dateTimeType: input.dateTimeType ?? "datetime")
        default:
            TextInputField(value: $textValue, placeholder: "请输入内容")
        }
    }

    private func submitResponse() {
        let value: AnyCodable
        switch input.effectiveInteractiveType {
        case "text":        value = AnyCodable(textValue)
        case "number":
            if let num = Double(numberValue) {
                value = AnyCodable(num)
            } else {
                value = AnyCodable(numberValue)
            }
        case "select":      value = AnyCodable(selectedValue)
        case "multiSelect": value = AnyCodable(Array(selectedValues))
        case "dateTime":    value = AnyCodable(formatDate(selectedDate, type: input.dateTimeType ?? "datetime"))
        default:            value = AnyCodable(textValue)
        }
        onSubmit(AskUserResponse(value: value))
    }

    private func formatDate(_ date: Date, type: String) -> String {
        let formatter = DateFormatter()
        switch type {
        case "date":     formatter.dateFormat = "yyyy-MM-dd"
        case "time":     formatter.dateFormat = "HH:mm:ss"
        default:         formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        }
        return formatter.string(from: date)
    }
}

// MARK: - AskUserMultiFieldFormView - 多字段表单场景
struct AskUserMultiFieldFormView: View {
    let input: AskUserToolInput
    let toolUse: ToolUseBlockMessage
    let onSubmit: (AskUserResponse) -> Void

    /// 最终提交的值，multiSelect 存 [String] 数组，number 提交时转 Double，其他存字符串
    @State private var fieldValues: [String: AnyCodable] = [:]
    /// 输入框显示用的字符串，与 fieldValues 解耦，避免 AnyCodable 类型转换干扰输入
    @State private var displayValues: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            questionHeader(input.question)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(input.fields ?? [], id: \.name) { field in
                    AskUserFieldInputView(
                        field: field,
                        value: Binding(
                            get: { displayValues[field.name] ?? "" },
                            set: {
                                displayValues[field.name] = $0
                                // number 提交时再转，这里先存字符串
                                fieldValues[field.name] = AnyCodable($0)
                            }
                        ),
                        onMultiSelectChanged: { values in
                            let arr = Array(values)
                            fieldValues[field.name] = AnyCodable(arr)
                            displayValues[field.name] = arr.joined(separator: ",")
                        }
                    )
                }
            }

            SimpleSubmitButton(action: submitForm)
        }
        .padding(ChatTheme.spacingLg)
        .background(askUserCardBackground)
        .onAppear {
            for field in input.fields ?? [] {
                let dv = field.defaultValue ?? ""
                displayValues[field.name] = dv
                fieldValues[field.name] = AnyCodable(dv)
            }
        }
    }

    private func submitForm() {
        // number 字段在提交时做字符串 → Double 转换
        var result = fieldValues
        for field in input.fields ?? [] where field.effectiveType == "number" {
            let raw = displayValues[field.name] ?? ""
            if let num = Double(raw) {
                result[field.name] = AnyCodable(num)
            }
        }
        onSubmit(AskUserResponse(fieldValues: result))
    }
}

// MARK: - AskUserFieldInputView - 单个字段的输入组件
struct AskUserFieldInputView: View {
    let field: AskUserField
    @Binding var value: String
    var onMultiSelectChanged: ((Set<String>) -> Void)? = nil

    @State private var selectedDate: Date = Date()
    @State private var selectedValues: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel
            inputField(for: field.effectiveType)
            unitLabel
        }
        .onAppear {
            if field.effectiveType == "dateTime",
               let defaultValue = field.defaultValue,
               !defaultValue.isEmpty,
               let date = parseDate(defaultValue, type: field.dateTimeType ?? "datetime") {
                selectedDate = date
            }
        }
    }

    private var fieldLabel: some View {
        HStack(spacing: 4) {
            Text(field.label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ChatTheme.textPrimary)
            if field.isRequired {
                Text("*")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ChatTheme.danger)
            }
        }
    }

    @ViewBuilder
    private var unitLabel: some View {
        if let unit = field.unit, !unit.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(ChatTheme.textSecondary)
                Text("单位: \(unit)")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(ChatTheme.textSecondary)
            }
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private func inputField(for type: String) -> some View {
        switch type {
        case "text":
            TextInputField(value: $value, placeholder: field.placeholder ?? "请输入")
        case "number":
            TextInputField(value: $value, placeholder: field.placeholder ?? "请输入数字", keyboardType: .decimalPad)
        case "select":
            SelectButtonsField(options: field.options ?? [], selectedValue: $value)
        case "multiSelect":
            MultiSelectButtonsFieldWithSync(
                options: field.options ?? [],
                selectedValues: $selectedValues,
                onValuesChanged: { values in
                    // 同步字符串 value 供显示用，同时通知父级存储数组
                    value = Array(values).joined(separator: ",")
                    onMultiSelectChanged?(values)
                }
            )
        case "dateTime":
            DateTimePickerFieldWithSync(
                selectedDate: $selectedDate,
                dateTimeType: field.dateTimeType ?? "datetime",
                onDateChanged: { date in
                    value = formatDateForField(date, type: field.dateTimeType ?? "datetime")
                }
            )
        case "url":
            URLLinkButton(url: field.defaultValue)
        default:
            TextInputField(value: $value, placeholder: field.placeholder ?? "请输入")
        }
    }

    private func formatDateForField(_ date: Date, type: String) -> String {
        let formatter = DateFormatter()
        switch type {
        case "date":  formatter.dateFormat = "yyyy-MM-dd"
        case "time":  formatter.dateFormat = "HH:mm:ss"
        default:      formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        }
        return formatter.string(from: date)
    }

    private func parseDate(_ dateString: String, type: String) -> Date? {
        let formatter = DateFormatter()
        switch type {
        case "date":  formatter.dateFormat = "yyyy-MM-dd"
        case "time":  formatter.dateFormat = "HH:mm:ss"
        default:      formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        }
        return formatter.date(from: dateString)
    }
}

// MARK: - TextInputField - 文本输入框
struct TextInputField: View {
    @Binding var value: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        TextField(placeholder, text: $value)
            .font(.system(size: 14, weight: .regular))
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color("input_bg"))
            .cornerRadius(ChatTheme.radiusSm)
            .overlay(
                RoundedRectangle(cornerRadius: ChatTheme.radiusSm)
                    .stroke(ChatTheme.hairline, lineWidth: 1.2)
            )
            .keyboardType(keyboardType)
    }
}

// MARK: - OptionRow - 通用选项行（单选/多选共用）
private struct OptionRow: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    private var bgColor: Color { isSelected ? ChatTheme.accent : Color("input_bg") }
    private var fgColor: Color { isSelected ? .white : ChatTheme.textPrimary }
    private var iconColor: Color { isSelected ? .white : ChatTheme.textSecondary }
    private var iconName: String { isSelected ? "checkmark.circle.fill" : "circle" }
    private var borderColor: Color { isSelected ? Color.clear : ChatTheme.hairline }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(fgColor)
                Spacer()
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bgColor)
            .cornerRadius(ChatTheme.radiusSm)
            .overlay(
                RoundedRectangle(cornerRadius: ChatTheme.radiusSm)
                    .stroke(borderColor, lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SelectButtonsField - 单选按钮组
struct SelectButtonsField: View {
    let options: [AskUserOption]
    @Binding var selectedValue: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(options, id: \.value) { option in
                OptionRow(
                    label: option.label,
                    isSelected: selectedValue == option.value,
                    onTap: { selectedValue = option.value }
                )
            }
        }
    }
}

// MARK: - MultiSelectButtonsField - 多选按钮组
struct MultiSelectButtonsField: View {
    let options: [AskUserOption]
    @Binding var selectedValues: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(options, id: \.value) { option in
                OptionRow(
                    label: option.label,
                    isSelected: selectedValues.contains(option.value),
                    onTap: {
                        if selectedValues.contains(option.value) {
                            selectedValues.remove(option.value)
                        } else {
                            selectedValues.insert(option.value)
                        }
                    }
                )
            }
        }
    }
}

// MARK: - MultiSelectButtonsFieldWithSync - 多选按钮组（带值同步）
struct MultiSelectButtonsFieldWithSync: View {
    let options: [AskUserOption]
    @Binding var selectedValues: Set<String>
    let onValuesChanged: (Set<String>) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(options, id: \.value) { option in
                OptionRow(
                    label: option.label,
                    isSelected: selectedValues.contains(option.value),
                    onTap: {
                        if selectedValues.contains(option.value) {
                            selectedValues.remove(option.value)
                        } else {
                            selectedValues.insert(option.value)
                        }
                        onValuesChanged(selectedValues)
                    }
                )
            }
        }
    }
}

// MARK: - DateTimePickerField - 日期时间选择器
struct DateTimePickerField: View {
    @Binding var selectedDate: Date
    let dateTimeType: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DatePicker(
                "选择日期时间",
                selection: $selectedDate,
                displayedComponents: displayedComponents
            )
            .font(.system(size: 14, weight: .regular))
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color("input_bg"))
            .cornerRadius(ChatTheme.radiusSm)
            .overlay(
                RoundedRectangle(cornerRadius: ChatTheme.radiusSm)
                    .stroke(ChatTheme.hairline, lineWidth: 1.2)
            )
            .datePickerStyle(.compact)

            selectedDateLabel
        }
    }

    private var displayedComponents: DatePicker.Components {
        switch dateTimeType {
        case "date": return .date
        case "time": return .hourAndMinute
        default:     return [.date, .hourAndMinute]
        }
    }

    private var selectedDateLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(ChatTheme.accent)
            Text("已选择: \(formattedDate)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ChatTheme.textSecondary)
        }
        .padding(.horizontal, 10)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        switch dateTimeType {
        case "date": formatter.dateFormat = "yyyy-MM-dd"
        case "time": formatter.dateFormat = "HH:mm:ss"
        default:     formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        }
        return formatter.string(from: selectedDate)
    }
}

// MARK: - DateTimePickerFieldWithSync - 日期时间选择器（带值同步）
struct DateTimePickerFieldWithSync: View {
    @Binding var selectedDate: Date
    let dateTimeType: String
    let onDateChanged: (Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DatePicker(
                "选择日期时间",
                selection: $selectedDate,
                displayedComponents: displayedComponents
            )
            .font(.system(size: 14, weight: .regular))
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color("input_bg"))
            .cornerRadius(ChatTheme.radiusSm)
            .overlay(
                RoundedRectangle(cornerRadius: ChatTheme.radiusSm)
                    .stroke(ChatTheme.hairline, lineWidth: 1.2)
            )
            .datePickerStyle(.compact)
            .onChange(of: selectedDate) { newDate in
                onDateChanged(newDate)
            }

            selectedDateLabel
        }
    }

    private var displayedComponents: DatePicker.Components {
        switch dateTimeType {
        case "date": return .date
        case "time": return .hourAndMinute
        default:     return [.date, .hourAndMinute]
        }
    }

    private var selectedDateLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(ChatTheme.accent)
            Text("已选择: \(formattedDate)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ChatTheme.textSecondary)
        }
        .padding(.horizontal, 10)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        switch dateTimeType {
        case "date": formatter.dateFormat = "yyyy-MM-dd"
        case "time": formatter.dateFormat = "HH:mm:ss"
        default:     formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        }
        return formatter.string(from: selectedDate)
    }
}

// MARK: - URLLinkButton - URL 跳转按钮
struct URLLinkButton: View {
    let url: String?

    var body: some View {
        Button(action: openURL) {
            HStack(spacing: 10) {
                Image(systemName: "safari.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text("点击跳转")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(ChatTheme.accent)
            .foregroundColor(.white)
            .cornerRadius(ChatTheme.radiusSm)
            .shadow(color: ChatTheme.accent.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .disabled(url == nil || url?.isEmpty == true)
    }

    private func openURL() {
        guard let urlString = url,
              !urlString.isEmpty,
              let link = URL(string: urlString) else { return }
        UIApplication.shared.open(link)
    }
}

// MARK: - SimpleSubmitButton - 简单提交按钮（无加载状态）
struct SimpleSubmitButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("提交")
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(ChatTheme.userBubbleGradient)
                .foregroundColor(.white)
                .cornerRadius(ChatTheme.radiusSm)
                .shadow(color: ChatTheme.accent.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - SubmitButton - 提交按钮（带加载状态，已弃用）
struct SubmitButton: View {
    @Binding var isLoading: Bool
    let action: () -> Void

    private var submitGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [Color.theme(.primary), Color.theme(.primary).opacity(0.9)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Button(action: action) {
            buttonLabel
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(submitGradient)
                .foregroundColor(.white)
                .cornerRadius(10)
                .shadow(color: Color.theme(.primary).opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .disabled(isLoading)
    }

    private var buttonLabel: some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.75, anchor: .center)
                    .tint(.white)
            }
            Text(isLoading ? "提交中..." : "提交")
                .font(.system(size: 15, weight: .semibold))
        }
    }
}

// MARK: - SelectField - 单选下拉框（已弃用，保留以兼容）
struct SelectField: View {
    let options: [AskUserOption]
    @Binding var selectedValue: String

    var body: some View {
        Menu {
            ForEach(options, id: \.value) { option in
                Button(action: { selectedValue = option.value }) {
                    HStack {
                        Text(option.label)
                        if selectedValue == option.value {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            menuLabel
        }
    }

    private var menuLabel: some View {
        let displayText: String
        if selectedValue.isEmpty {
            displayText = "请选择"
        } else {
            displayText = options.first(where: { $0.value == selectedValue })?.label ?? selectedValue
        }
        return HStack {
            Text(displayText)
                .font(.system(size: 13))
                .foregroundColor(selectedValue.isEmpty ? Color("text_secondary") : Color("text_primary"))
            Spacer()
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color("text_secondary"))
        }
        .padding(10)
        .background(Color("input_bg"))
        .cornerRadius(8)
    }
}

// MARK: - MultiSelectField - 多选框（已弃用，保留以兼容）
struct MultiSelectField: View {
    let options: [AskUserOption]
    @Binding var selectedValues: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(options, id: \.value) { option in
                MultiSelectLegacyRow(
                    option: option,
                    isSelected: selectedValues.contains(option.value),
                    onTap: {
                        if selectedValues.contains(option.value) {
                            selectedValues.remove(option.value)
                        } else {
                            selectedValues.insert(option.value)
                        }
                    }
                )
            }
        }
    }
}

private struct MultiSelectLegacyRow: View {
    let option: AskUserOption
    let isSelected: Bool
    let onTap: () -> Void

    private var iconName: String { isSelected ? "checkmark.square.fill" : "square" }
    private var iconColor: Color { isSelected ? Color.theme(.primary) : Color("text_secondary") }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
                Text(option.label)
                    .font(.system(size: 13))
                    .foregroundColor(Color("text_primary"))
                Spacer()
            }
            .padding(10)
            .background(Color("input_bg").opacity(0.5))
            .cornerRadius(8)
        }
    }
}

// MARK: - DateTimeField - 日期时间选择器（已弃用，保留以兼容）
struct DateTimeField: View {
    @Binding var selectedDate: Date
    let dateTimeType: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DatePicker(
                "选择日期时间",
                selection: $selectedDate,
                displayedComponents: displayedComponents
            )
            .font(.system(size: 13))
            .datePickerStyle(.compact)
        }
        .padding(10)
        .background(Color("input_bg"))
        .cornerRadius(8)
    }

    private var displayedComponents: DatePicker.Components {
        switch dateTimeType {
        case "date": return .date
        case "time": return .hourAndMinute
        default:     return [.date, .hourAndMinute]
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        AIAskUserMessageView(
            messageId: "123",
            toolUse: ToolUseBlockMessage(
                id: "call_123",
                name: "ask_user",
                input: AnyCodable([
                    "question": "请选择您的性别",
                    "interactiveType": "select",
                    "options": [
                        ["label": "男", "value": "male"],
                        ["label": "女", "value": "female"]
                    ]
                ])
            ),
            onSubmit: { interactiveHandle in
                print("User submitted: \(interactiveHandle)")
            }
        )
        Spacer()
    }
    .padding()
    .background(Color("background"))
}
