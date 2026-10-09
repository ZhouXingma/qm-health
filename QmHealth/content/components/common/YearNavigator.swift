//
//  YearNavigator.swift
//  QmHealth
//  年份导航组件
//

import SwiftUI

struct YearNavigator: View {
    @Binding var date: Date
    var color: Color = Color.theme(.primary)
    var onDateChanged: (() -> Void)? = nil

    @State private var showPicker = false
    @State private var pickYear: Int = Calendar.current.component(.year, from: Date())

    private let calendar = Calendar.current

    private var yearText: String {
        let f = DateFormatter(); f.dateFormat = "yyyy年"; return f.string(from: date)
    }

    /// 当前年份
    private var nowYear: Int { calendar.component(.year, from: Date()) }

    /// 年选择器范围：2006年 ~ 今年
    private var yearRange: ClosedRange<Int> {
        2006...nowYear
    }

    /// 右箭头是否禁用（已到今年）
    private var isRightDisabled: Bool {
        calendar.component(.year, from: date) >= nowYear
    }

    var body: some View {
        HStack {
            Button { cycleYear(-1) } label: {
                Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold)).foregroundStyle(color)
            }
            Spacer()
            Button { prepareAndShow() } label: {
                Text(yearText).font(.system(size: 15, weight: .medium)).foregroundStyle(Color("text_primary"))
            }
            Spacer()
            Button { cycleYear(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isRightDisabled ? Color("text_secondary").opacity(0.3) : color)
            }
            .disabled(isRightDisabled)
        }
        .padding(.vertical, 10).padding(.horizontal, 16)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: AppRadius.max))
        .sheet(isPresented: $showPicker) {
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    SheetHeader(title: "选择年份")
                    Picker("年", selection: $pickYear) {
                        ForEach(yearRange, id: \.self) { y in Text("\(y)年").tag(y) }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 200)
                    .onChange(of: pickYear) { _, _ in commitYear() }
                }
            }.presentationDetents([.height(250)])
                .ignoresSafeArea(.all)
            
        }
    }

    private func prepareAndShow() {
        pickYear = calendar.component(.year, from: date)
        showPicker = true
    }

    private func commitYear() {
        var comps = DateComponents(); comps.year = pickYear; comps.month = 1; comps.day = 1
        guard let d = calendar.date(from: comps) else { return }
        date = d
        onDateChanged?()
    }

    private func cycleYear(_ delta: Int) {
        guard let d = calendar.date(byAdding: .year, value: delta, to: date) else { return }
        // 不能超过今年
        let dateYear = calendar.component(.year, from: d)
        if dateYear > nowYear {
            var comps = DateComponents(); comps.year = nowYear; comps.month = 1; comps.day = 1
            guard let clamped = calendar.date(from: comps) else { return }
            withAnimation { date = clamped }
        } else {
            withAnimation { date = d }
        }
        onDateChanged?()
    }
}

#Preview {
    @Previewable @State var d = Date()
    return YearNavigator(date: $d).padding().background(Color("background"))
}
