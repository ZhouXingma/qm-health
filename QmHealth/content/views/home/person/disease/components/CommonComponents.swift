//
//  CommonComponents.swift
//  QmHealth
//  通用组件集合
//
//  Created by 周荥马 on 2025/10/2.
//

import SwiftUI

// MARK: - 区域标题
struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.theme(.primary))
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color("text_primary"))
            Spacer()
        }
        .padding(.bottom, 5)
    }
}

// MARK: - 输入框
struct InputField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.theme(.primary))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color("text_primary"))
            }
            
            TextField(placeholder, text: $text)
                .font(.system(size: 14))
                .inputFieldStyle()
        }
    }
}

// MARK: - 日期选择器
struct DatePickerField: View {
    let title: String
    @Binding var date: String?
    let icon: String
    var allowFuture: Bool = false
    @State var selectDate: String = DateUtils.formatDate(Date(), format: DateUtils.DateFormat.ymd)
    var subPopManager: SubPopManager
  
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.theme(.primary))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color("text_primary"))
            }
            
            HStack {
                Text(self.date ?? "请选择日期")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(nil != self.date ? Color("text_primary") : Color("text_secondary"))
                Spacer()
                Button("选择") {
                    KeyBoardUtils.toHideKeyboard()
                    subPopManager.showCustomSubPop(customAction: {
                        self.date = selectDate
                    }) {
                        DateTimePicker(featureDate: allowFuture, initSelectDate: DateUtils.stringToDate(date ?? selectDate, format: DateUtils.DateFormat.ymd)) { date in
                            selectDate = DateUtils.formatDate(date, format: DateUtils.DateFormat.ymd)
                        }
                    }
                }
                .font(.system(size: 14))
                .foregroundStyle(Color.theme(.primary))
            }
            .inputFieldStyle()
        }
    }
}

// MARK: - 选择器
struct PickerField<T: CaseIterable & Hashable>: View where T.AllCases: RandomAccessCollection {
    let title: String
    @Binding var selection: T
    let options: T.AllCases
    let icon: String
    let displayContent: (T) -> AnyView
    
    init(title: String, selection: Binding<T>, options: T.AllCases, icon: String, @ViewBuilder displayContent: @escaping (T) -> some View) {
        self.title = title
        self._selection = selection
        self.options = options
        self.icon = icon
        self.displayContent = { AnyView(displayContent($0)) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.theme(.primary))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color("text_primary"))
            }
            
            Menu {
                ForEach(Array(options), id: \.self) { option in
                    Button(action: {
                        selection = option
                    }) {
                        displayContent(option)
                    }
                }
            } label: {
                HStack {
                    displayContent(selection)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("text_secondary"))
                }
                .inputFieldStyle()
            }
        }
    }
}

// MARK: - 空状态视图
struct EmptyStateView: View {
    let icon: String
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size:40))
                .foregroundStyle(Color("text_secondary"))
            
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Color("text_secondary"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}


// MARK: - 标签栏项
struct TabBarItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? Color.theme(.primary) : Color("text_secondary"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .frame(height: 2)
                        .foregroundStyle(isSelected ? Color.theme(.primary) : Color.clear)
                }
            )
        }
    }
}
