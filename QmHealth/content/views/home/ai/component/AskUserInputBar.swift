//
//  AskUserInputBar.swift
//  QmHealth
//
//  机制 B（ask_user 信息收集）底部交互栏。
//  待回答的 ask_user 不再内联在消息流里，而是取代底部输入框展示；
//  提交后由 AiChatMain 把结果回填到对应的 toolUse，
//  消息流中会以"已回复"的样式出现在原来的位置。
//

import SwiftUI

// MARK: - 跳过的提交约定
//
// 跳过不是"取消"，而是一种回答：
//   单题：value = "跳过"
//   表单：value = { 字段名: "跳过", ... }（未作答/被跳过的字段都写"跳过"）
// 跳过的提交统一用 messageType = "text"。
let ASK_USER_SKIP_VALUE = "跳过"
let ASK_USER_SKIP_MESSAGE_TYPE = "text"

// MARK: - PendingAskUser

/// 当前等待用户回答的 ask_user 交互。
/// 由 AiChatMain 扫描消息流得出：最后出现的那个 result 为空的 ask_user 工具调用。
struct PendingAskUser: Identifiable {
    let messageId: String
    let toolUse: ToolUseBlockMessage
    let input: AskUserToolInput

    /// 用 toolCallId 做标识，保证流式增量刷新时交互栏内部的填写状态不被重置
    var id: String { toolUse.id }
}

// MARK: - AskUserSubmission

/// 一次 ask_user 提交
struct AskUserSubmission {
    let value: AnyCodable
    /// 是否由"跳过"触发，决定提交用的 messageType
    let isSkip: Bool
}

// MARK: - AskUserInputBar

/// ask_user 底部交互栏 —— 取代输入框显示，外观沿用输入框的液态玻璃
struct AskUserInputBar: View {
    let pending: PendingAskUser
    let isSubmitting: Bool
    let onSubmit: (InteractiveHandleBlockMessage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ChatTheme.spacingMd) {
            if pending.input.isSingleQuestion {
                AskUserSingleQuestionBar(
                    input: pending.input,
                    onSubmit: { submission in submit(submission) }
                )
            } else {
                AskUserFormBar(
                    input: pending.input,
                    onSubmit: { submission in submit(submission) }
                )
            }
        }
        .padding(ChatTheme.spacingMd)
        // 先填 clear 再套玻璃，否则玻璃 tint 颜色显示异常
        .background(RoundedRectangle(cornerRadius: ChatTheme.radiusLg).fill(Color.clear))
        .appGlass(.regular, in: RoundedRectangle(cornerRadius: ChatTheme.radiusLg))
        .padding(.horizontal, 10)
        .disabled(isSubmitting)
        .opacity(isSubmitting ? 0.6 : 1)
        .overlay(alignment: .topTrailing) {
            if isSubmitting {
                ProgressView()
                    .scaleEffect(0.7)
                    .padding(ChatTheme.spacingSm)
            }
        }
    }

    private func submit(_ submission: AskUserSubmission) {
        onSubmit(InteractiveHandleBlockMessage(
            messageId: pending.messageId,
            name: pending.toolUse.name,
            toolCallId: pending.toolUse.id,
            messageType: submission.isSkip ? ASK_USER_SKIP_MESSAGE_TYPE : normalMessageType,
            value: submission.value
        ))
    }

    /// 正常作答时的 messageType：单题用交互类型，表单用 fields
    private var normalMessageType: String {
        pending.input.isSingleQuestion ? pending.input.effectiveInteractiveType : "fields"
    }
}

// MARK: - 按钮

/// 跳过按钮：永远可点，"跳过本身就是一种回答"
struct AskUserSkipButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("跳过")
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: ChatTheme.radiusMd)
                        .fill(Color("input_bg"))
                )
                .foregroundStyle(ChatTheme.textPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: ChatTheme.radiusMd)
                        .stroke(ChatTheme.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

/// 主按钮（下一步 / 提交），当前题目未作答时禁用
struct AskUserPrimaryButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(background)
                .foregroundStyle(isEnabled ? Color.white : ChatTheme.textSecondary)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    /// 禁用态不能用整体降透明度：白色文字叠在淡化的渐变上几乎看不清。
    /// 直接用面板内其他控件的中性底色，和"跳过"按钮同一套材质。
    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: ChatTheme.radiusMd)
        if isEnabled {
            shape.fill(ChatTheme.userBubbleGradient)
        } else {
            shape.fill(Color("input_bg"))
        }
    }
}

// MARK: - 进度指示

/// 题目进度圆点：已作答为主色，未作答为浅色，当前题目拉长成胶囊
struct AskUserProgressDots: View {
    let count: Int
    let currentIndex: Int
    let isAnswered: (Int) -> Bool

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(fillColor(index))
                    .frame(width: index == currentIndex ? 20 : 6, height: 6)
                    .animation(.easeInOut(duration: 0.25), value: currentIndex)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("第 \(currentIndex + 1) 题，共 \(count) 题")
    }

    private func fillColor(_ index: Int) -> Color {
        if index == currentIndex {
            return ChatTheme.accent
        }
        return isAnswered(index) ? ChatTheme.accent.opacity(0.55) : ChatTheme.accent.opacity(0.2)
    }
}

// MARK: - 单题交互栏

/// 单题场景：题目 + 输入组件 + 「跳过 / 提交」
struct AskUserSingleQuestionBar: View {
    let input: AskUserToolInput
    let onSubmit: (AskUserSubmission) -> Void

    @State private var textValue: String = ""
    @State private var selectedValue: String = ""
    @State private var selectedValues: Set<String> = []
    @State private var selectedDate: Date = Date()
    @State private var numberValue: String = ""

    private var type: String { input.effectiveInteractiveType }

    var body: some View {
        VStack(alignment: .leading, spacing: ChatTheme.spacingMd) {
            questionHeader(input.question)

            if type == "url" {
                // url 没有可作答的值，只提供跳转和跳过
                URLLinkButton(url: input.defaultValue)
                AskUserSkipButton(action: skip)
            } else {
                inputField
                HStack(spacing: 10) {
                    AskUserSkipButton(action: skip)
                    AskUserPrimaryButton(
                        title: "提交",
                        isEnabled: isAnswered,
                        action: submit
                    )
                }
            }
        }
        .onAppear(perform: prefill)
    }

    private var isAnswered: Bool {
        switch type {
        case "text":        return !textValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case "number":      return !numberValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case "select":      return !selectedValue.isEmpty
        case "multiSelect": return !selectedValues.isEmpty
        default:            return true
        }
    }

    @ViewBuilder
    private var inputField: some View {
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

    private func prefill() {
        guard let defaultValue = input.defaultValue, !defaultValue.isEmpty else { return }
        switch type {
        case "text", "number":
            if type == "number" {
                numberValue = defaultValue
            } else {
                textValue = defaultValue
            }
        case "select":
            selectedValue = defaultValue
        case "dateTime":
            if let date = askUserParseDate(defaultValue, type: input.dateTimeType ?? "datetime") {
                selectedDate = date
            }
        default:
            break
        }
    }

    private func skip() {
        onSubmit(AskUserSubmission(value: AnyCodable(ASK_USER_SKIP_VALUE), isSkip: true))
    }

    private func submit() {
        let value: AnyCodable
        switch type {
        case "text":        value = AnyCodable(textValue)
        case "number":      value = Double(numberValue).map { AnyCodable($0) } ?? AnyCodable(numberValue)
        case "select":      value = AnyCodable(selectedValue)
        case "multiSelect": value = AnyCodable(Array(selectedValues))
        case "dateTime":    value = AnyCodable(askUserFormatDate(selectedDate, type: input.dateTimeType ?? "datetime"))
        default:            value = AnyCodable(textValue)
        }
        onSubmit(AskUserSubmission(value: value, isSkip: false))
    }
}

// MARK: - 表单交互栏（多题）

/// 多题表单：一页一题，底部「跳过 / 下一步」，最后一题为「跳过 / 提交」。
/// 跳过只是跳过当前这题；如果已经是最后一题，跳过之后直接提交
/// （已作答的字段保留答案，被跳过的字段提交为"跳过"）。
///
/// 这里没有用 TabView 分页：paged TabView 无法可靠地禁止左右滑动，
/// 而滑动过去会绕过"必答才能下一步"的约束。改成只渲染当前题 + 自己控制切换动画。
struct AskUserFormBar: View {
    let input: AskUserToolInput
    let onSubmit: (AskUserSubmission) -> Void

    private var fields: [AskUserField] { input.fields ?? [] }

    @State private var index: Int = 0
    @State private var states: [String: AskUserFieldState] = [:]
    /// 切题方向，决定滑动动画的朝向
    @State private var goingForward: Bool = true

    private var isLast: Bool { index >= fields.count - 1 }
    private var currentField: AskUserField? { fields.indices.contains(index) ? fields[index] : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: ChatTheme.spacingMd) {
            navigationRow

            questionHeader(input.question)

            // 内容区随题目自适应高度，超出部分在切题动画中被裁掉
            ZStack(alignment: .topLeading) {
                if let field = currentField {
                    inputView(for: field)
                        .id(field.name)
                        .transition(pageTransition)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .clipped()

            HStack(spacing: 10) {
                AskUserSkipButton(action: skipCurrent)
                AskUserPrimaryButton(
                    title: isLast ? "提交" : "下一步",
                    isEnabled: currentField.map { isAnswered($0) } ?? false,
                    action: isLast ? { submitForm() } : { goNext() }
                )
            }
        }
        .onAppear(perform: prefill)
    }

    private var pageTransition: AnyTransition {
        let edge: (in: Edge, out: Edge) = goingForward ? (.trailing, .leading) : (.leading, .trailing)
        return .asymmetric(
            insertion: .move(edge: edge.in).combined(with: .opacity),
            removal: .move(edge: edge.out).combined(with: .opacity)
        )
    }

    /// 顶部：返回上一题（非首题时） + 进度圆点
    private var navigationRow: some View {
        HStack(spacing: ChatTheme.spacingSm) {
            if index > 0 {
                Button {
                    goingForward = false
                    withAnimation(.easeInOut(duration: 0.2)) { index -= 1 }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                        Text("上一题")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(ChatTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            AskUserProgressDots(
                count: fields.count,
                currentIndex: index,
                isAnswered: { fields.indices.contains($0) && isAnswered(fields[$0]) }
            )
        }
    }

    /// 当前题的输入组件。
    /// AskUserFieldInputView 自己会渲染字段名、必填星号和单位，这里不要再画一遍。
    private func inputView(for field: AskUserField) -> some View {
        AskUserFieldInputView(
            field: field,
            value: Binding(
                get: { states[field.name]?.text ?? "" },
                set: { newValue in
                    var state = states[field.name] ?? AskUserFieldState()
                    state.text = newValue
                    states[field.name] = state
                }
            ),
            onMultiSelectChanged: { values in
                var state = states[field.name] ?? AskUserFieldState()
                state.multi = values
                states[field.name] = state
            }
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 作答状态

    private func isAnswered(_ field: AskUserField) -> Bool {
        (states[field.name] ?? AskUserFieldState()).isAnswered(field)
    }

    /// 组装整张表单的提交值：已作答的字段用答案，其余写"跳过"
    private func assembledValue() -> AnyCodable {
        var dict: [String: AnyCodable] = [:]
        for field in fields {
            let state = states[field.name] ?? AskUserFieldState()
            dict[field.name] = state.isAnswered(field)
                ? state.value(field)
                : AnyCodable(ASK_USER_SKIP_VALUE)
        }
        return AnyCodable(dict)
    }

    // MARK: 操作

    private func goNext() {
        guard !isLast else { return }
        goingForward = true
        withAnimation(.easeInOut(duration: 0.2)) { index += 1 }
    }

    /// 跳过当前题：清掉这一题的作答（"跳过"是明确的回答），
    /// 非最后一题则翻到下一题，最后一题直接提交
    private func skipCurrent() {
        guard let field = currentField else { return }
        states[field.name] = AskUserFieldState()

        if isLast {
            onSubmit(AskUserSubmission(value: assembledValue(), isSkip: true))
        } else {
            goingForward = true
            withAnimation(.easeInOut(duration: 0.2)) { index += 1 }
        }
    }

    private func submitForm() {
        onSubmit(AskUserSubmission(value: assembledValue(), isSkip: false))
    }

    private func prefill() {
        guard states.isEmpty else { return }
        var initial: [String: AskUserFieldState] = [:]
        for field in fields {
            var state = AskUserFieldState()
            if let defaultValue = field.defaultValue, !defaultValue.isEmpty {
                switch field.effectiveType {
                case "dateTime":
                    let date = askUserParseDate(defaultValue, type: field.dateTimeType ?? "datetime") ?? Date()
                    state.text = askUserFormatDate(date, type: field.dateTimeType ?? "datetime")
                case "select":
                    state.text = defaultValue
                case "multiSelect":
                    state.multi = Set(defaultValue.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) })
                default:
                    state.text = defaultValue
                }
            } else if field.effectiveType == "dateTime" {
                // 日期时间选择器始终有一个可见的当前值，直接作为默认答案
                state.text = askUserFormatDate(Date(), type: field.dateTimeType ?? "datetime")
            }
            initial[field.name] = state
        }
        states = initial
    }
}

// MARK: - 表单字段的填写状态

/// 一个表单字段的填写状态。取值为 value 时不区分"未作答"与"被跳过"，
/// 未作答的字段在提交时统一写成"跳过"。
///
/// 字段值的存放位置跟随 `AskUserFieldInputView` 的回写方式：
/// text / number / select / dateTime 都通过 value 绑定写进 text，
/// 只有 multiSelect 走 onMultiSelectChanged 单独存 multi。
struct AskUserFieldState {
    /// text / number 的输入内容、select 的选中值、dateTime 的格式化结果
    var text: String = ""
    /// multiSelect 选中的值
    var multi: Set<String> = []

    func isAnswered(_ field: AskUserField) -> Bool {
        switch field.effectiveType {
        case "text", "number":
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case "multiSelect":
            return !multi.isEmpty
        case "dateTime":
            return !text.isEmpty
        default:
            // select 及未知类型：控件本身不带值时才需要用户填写
            return !text.isEmpty
        }
    }

    func value(_ field: AskUserField) -> AnyCodable {
        switch field.effectiveType {
        case "number":
            return Double(text).map { AnyCodable($0) } ?? AnyCodable(text)
        case "multiSelect":
            return AnyCodable(Array(multi))
        default:
            return AnyCodable(text)
        }
    }
}

// MARK: - 日期格式化辅助

func askUserFormatDate(_ date: Date, type: String) -> String {
    let formatter = DateFormatter()
    switch type {
    case "date": formatter.dateFormat = "yyyy-MM-dd"
    case "time": formatter.dateFormat = "HH:mm:ss"
    default:     formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }
    return formatter.string(from: date)
}

func askUserParseDate(_ dateString: String, type: String) -> Date? {
    let formatter = DateFormatter()
    switch type {
    case "date": formatter.dateFormat = "yyyy-MM-dd"
    case "time": formatter.dateFormat = "HH:mm:ss"
    default:     formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }
    return formatter.date(from: dateString)
}
