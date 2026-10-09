//
//  MonthNavigator.swift
//  QmHealth
//  月份导航组件
//

import SwiftUI

struct MonthNavigator: View {
    @Binding var date: Date
    var color: Color = Color.theme(.primary)
    var onDateChanged: (() -> Void)? = nil

    @State private var showPicker = false
    @State private var pickYear: Int = Calendar.current.component(.year, from: Date())
    @State private var pickMonth: Int = Calendar.current.component(.month, from: Date())

    private let calendar = Calendar.current

    private var monthText: String {
        let f = DateFormatter(); f.dateFormat = "yyyy年MM月"; return f.string(from: date)
    }

    /// 当前年月
    private var nowYear: Int { calendar.component(.year, from: Date()) }
    private var nowMonth: Int { calendar.component(.month, from: Date()) }

    /// 年选择器范围：2006年 ~ 今年
    private var yearRange: ClosedRange<Int> {
        2006...nowYear
    }

    /// 月选择器范围：选中今年时只能到当月
    private var monthRange: ClosedRange<Int> {
        pickYear < nowYear ? 1...12 : 1...nowMonth
    }

    /// 右箭头是否禁用（已到当月）
    private var isRightDisabled: Bool {
        let dateYear = calendar.component(.year, from: date)
        let dateMonth = calendar.component(.month, from: date)
        return dateYear >= nowYear && dateMonth >= nowMonth
    }

    var body: some View {
        HStack {
            Button { cycleMonth(-1) } label: {
                Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold)).foregroundStyle(color)
            }
            Spacer()
            Button { prepareAndShow() } label: {
                Text(monthText).font(.system(size: 15, weight: .medium)).foregroundStyle(Color("text_primary"))
            }
            Spacer()
            Button { cycleMonth(1) } label: {
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
                    SheetHeader(title: "选择月份")
                    HStack(spacing: 0) {
                        Picker("年", selection: $pickYear) {
                            ForEach(yearRange, id: \.self) { y in Text("\(y)年").tag(y) }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: pickYear) { _, newYear in
                            // 切换年份时，如果月份超范围则截断
                            let maxM = newYear < nowYear ? 12 : nowMonth
                            if pickMonth > maxM { pickMonth = maxM }
                            commitMonth()
                        }
                        Picker("月", selection: $pickMonth) {
                            ForEach(monthRange, id: \.self) { m in Text("\(m)月").tag(m) }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: pickMonth) { _, _ in commitMonth() }
                    }
                    .frame(height: 200)
                }
            }
            .presentationDetents([.height(260)])
            .ignoresSafeArea(.all)
        }
    }

    private func prepareAndShow() {
        pickYear = calendar.component(.year, from: date)
        pickMonth = calendar.component(.month, from: date)
        // 确保打开的初始值不超范围
        let maxM = pickYear < nowYear ? 12 : nowMonth
        if pickMonth > maxM { pickMonth = maxM }
        showPicker = true
    }

    private func commitMonth() {
        var comps = DateComponents(); comps.year = pickYear; comps.month = pickMonth; comps.day = 1
        guard let d = calendar.date(from: comps) else { return }
        date = d
        onDateChanged?()
    }

    private func cycleMonth(_ delta: Int) {
        guard let d = calendar.date(byAdding: .month, value: delta, to: date) else { return }
        // 不能超过当月
        var maxComps = DateComponents(); maxComps.year = nowYear; maxComps.month = nowMonth; maxComps.day = 1
        guard let maxDate = calendar.date(from: maxComps) else { return }
        let clamped = d > maxDate ? maxDate : d
        withAnimation { date = clamped }
        onDateChanged?()
    }
}

#Preview {
    @Previewable @State var d = Date()
    return MonthNavigator(date: $d).padding().background(Color("background"))
}
