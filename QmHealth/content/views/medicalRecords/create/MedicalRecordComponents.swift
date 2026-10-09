import SwiftUI

// MARK: - 通用组件

// 加载遮罩层
struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text(message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.8))
            )
        }
    }
}

// 状态指示器
struct RecordTypeIndicator: View {
    let recordType: RecordType

    var body: some View {
        HStack(spacing: 12) {
            // 左侧图标
            ZStack {
                Circle()
                    .fill(recordType == .visit ? Color.theme(.primary).opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: recordType == .visit ? "checkmark.circle.fill" : "calendar.badge.clock")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(recordType == .visit ? Color.theme(.primary) : .orange)
            }

            // 中间文字
            VStack(alignment: .leading, spacing: 4) {
                Text(recordType == .visit ? "就诊记录" : "预约记录")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color("text_primary"))

                Text(recordType == .visit ? "记录已完成的就诊信息" : "记录未来的预约安排")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text_secondary"))
            }

            Spacer()

            // 右侧标签 + 切换提示图标
            HStack(spacing: 4) {
                Text(recordType == .visit ? "已就诊" : "未就诊")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(recordType == .visit ? Color.theme(.primary) : .orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(recordType == .visit ? Color.theme(.primary).opacity(0.12) : Color.orange.opacity(0.12))
                    )

                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color("text_secondary").opacity(0.7))
            }
        }
        .cardStyle()
    }
}

// 日期时间选择行
struct DateTimePickerRow: View {
    let title: String
    @Binding var date: Date
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color("text_primary"))
            
            Spacer()
            
            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .accentColor(Color.theme(.primary))
        }
        .padding(.vertical, 14)
    }
}

// 文本输入行
struct TextFieldRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let isRequired: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("text_primary"))
                
                if isRequired {
                    Text("*")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            TextField(placeholder, text: $text)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 15))
                .foregroundColor(Color("text_primary"))
        }
        .padding(.vertical, 14)
    }
}

// 多行文本输入行
struct TextEditorRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color("text_primary"))
            
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 15))
                        .foregroundColor(Color("text_secondary").opacity(0.5))
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                
                TextEditor(text: $text)
                    .font(.system(size: 15))
                    .foregroundColor(Color("text_primary"))
                    .frame(minHeight: 90)
                    .scrollContentBackground(.hidden)
            }
        }
        .padding(.vertical,14)
    }
}
