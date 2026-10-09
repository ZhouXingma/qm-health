//
//  DateNavigator.swift
//  QmHealth
//  日期导航组件：左右箭头切换日期，点击日期弹出日历选择
//
//  Created on 2026/6/27.
//

import SwiftUI

struct DateNavigator: View {
    @Binding var date: Date
    var color: Color = Color.theme(.primary)
    var dateFormat: String = DateUtils.DateFormat.ymd_zh
    var onDateChanged: (() -> Void)? = nil

    @State private var showDatePicker = false

    /// 可选最大日期（默认今天）
    private var maxDate: Date {
        Calendar.current.startOfDay(for: Date())
    }

    /// 右箭头是否禁用（已到最大日期）
    private var isRightDisabled: Bool {
        Calendar.current.compare(date, to: maxDate, toGranularity: .day) != .orderedAscending
    }

    var body: some View {
        HStack {
            // 前一日
            Button {
                cycleDate(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(color)
            }

            Spacer()

            // 日期文字（点击弹出日历）
            Button {
                showDatePicker = true
            } label: {
                Text(DateUtils.formatDate(date, format: dateFormat))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color("text_primary"))
            }

            Spacer()

            // 后一日
            Button {
                cycleDate(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isRightDisabled ? Color("text_secondary").opacity(0.3) : color)
            }
            .disabled(isRightDisabled)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: AppRadius.max))
        .sheet(isPresented: $showDatePicker) {
            VStack(spacing: 0) {
                SheetHeader(title: "选择日期")
                DatePicker("", selection: $date, in: ...maxDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(color)
                    .padding()
                    .onChange(of: date) { _, _ in
                        onDateChanged?()
                        showDatePicker = false
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .presentationDetents([.medium])
            .ignoresSafeArea(.all)
        }
    }

    /// 切换到前一天/后一天
    private func cycleDate(_ delta: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: delta, to: date) else { return }
        // 不能超过今天
        let clamped = min(newDate, maxDate)
        withAnimation {
            date = clamped
        }
        onDateChanged?()
    }
}

#Preview {
    @Previewable @State var d = Date()
    return DateNavigator(date: $d)
        .padding()
        .background(Color("background"))
}
