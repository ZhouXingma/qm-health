//
//  CalendarView.swift
//  AppComponent
//
//  Created by 周荥马 on 2025/11/4.
//

import SwiftUI


// MARK: - 主组件
struct CalendarView: View {
    @State private var selectTab = 1
    // 选择的时间
    @State private var selectDayItem: DayItem = buildDayItem(date: Date())
    @State private var yearMothArray:[YearMoth] = [buildYearMoth(), buildYearMoth(), buildYearMoth().next()]
    // 是否显示年月选择弹窗
    @State private var showYearMonthPicker = false
    // 标记的日期（用于显示小红点）
    var markedDates: Set<String> = []
    // 日期选择回调
    var onDateSelected: ((DayItem) -> Void)?
    // 月份变化回调（用于加载新月份的数据）
    var onMonthChanged: ((Int, Int) -> Void)?
    // 是否允许选择未来月份
    var allowFutureMonths: Bool
    
    private let week = [ "日", "一", "二", "三", "四", "五", "六"]
    
    init(allowFutureMonths: Bool = false, onDateSelected: ((DayItem) -> Void)? = nil, onMonthChanged: ((Int, Int) -> Void)? = nil, markedDates: Set<String> = []) {
        let thisMoth = buildYearMoth();
        self.allowFutureMonths = allowFutureMonths
        self.onDateSelected = onDateSelected
        self.onMonthChanged = onMonthChanged
        self.markedDates = markedDates
        if allowFutureMonths {
            _yearMothArray =  State(initialValue:[thisMoth.pre(), thisMoth, thisMoth.next()])
            _selectTab = State(initialValue: 1)
        } else {
            _yearMothArray = State(initialValue:[thisMoth.pre().pre(), thisMoth.pre(), thisMoth])
            _selectTab = State(initialValue: 2)
        }
    }
    
    // 直接跳转到指定年月（用于年月选择器）
    func jumpTo(year: Int, month: Int) {
        var target = YearMoth(year: year, month: month)
        // 未开启未来月份时，不允许跳转到未来月份
        if !allowFutureMonths && isFutureMonth(year: target.year, month: target.month) {
            target = buildYearMoth()
        }
        withAnimation(.none) {
            yearMothArray = [target.pre(), target, target.next()]
            selectTab = 1
        }
    }
    
    func changeYearMothArray(tagIndex:Int) {
        if tagIndex == 0 {
            // 往前
            yearMothArray[0] = yearMothArray[0].pre()
            yearMothArray[1] = yearMothArray[1].pre()
            yearMothArray[2] = yearMothArray[2].pre()
        } else if tagIndex == 2 {
            yearMothArray[0] = yearMothArray[0].next()
            yearMothArray[1] = yearMothArray[1].next()
            yearMothArray[2] = yearMothArray[2].next()
        }
    }
    
    
    // 判断某个年月是否是未来月份
    func isFutureMonth(year: Int, month: Int) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        let currentYear = calendar.component(.year, from: today)
        let currentMonth = calendar.component(.month, from: today)
        
        if year > currentYear {
            return true
        } else if year == currentYear && month > currentMonth {
            return true
        }
        return false
    }
    
    
    // 判断是否可以切换到下一个月
    var canGoToNextMonth: Bool {
        if allowFutureMonths {
            return true
        }
        // 检查 tag(2) 是否是未来月份
        return !isCurrentMonth(year: yearMothArray[selectTab].year, month: yearMothArray[selectTab].month)
    }
    /// 判断传入的年和月是否为当前月
    func isCurrentMonth(year: Int, month: Int) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        let currentYear = calendar.component(.year, from: today)
        let currentMonth = calendar.component(.month, from: today)
        return year == currentYear && month == currentMonth
    }
    
    // 计算当前月份的行数
    func getRowsForMonth(year: Int, month: Int) -> Int {
        let calendar = Calendar.current
        guard let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
            return 6 // 默认返回最大行数
        }
        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1
        guard let range = calendar.range(of: .day, in: .month, for: firstDay) else {
            return 6
        }
        let daysInMonth = range.count
        let totalCells = firstWeekday + daysInMonth
        return Int(ceil(Double(totalCells) / 7.0))
    }
    
    // 当前实际展示的年月（不管通过按钮、滑动还是重新居中，都以此为唯一事实来源）
    var displayedYearMonthKey: String {
        "\(yearMothArray[selectTab].year)-\(numberFormat(yearMothArray[selectTab].month))"
    }
    
    // 计算组件总高度
    var calculatedHeight: CGFloat {
        let rows = getRowsForMonth(year: yearMothArray[selectTab].year, month: yearMothArray[selectTab].month)
        // 月份标题栏高度：24(字体) + 16(top padding) + 32(按钮高度) ≈ 72，实际测量约60
        let headerHeight: CGFloat = 60
        // 星期标题高度：14(字体) + 一些间距 ≈ 30
        let weekHeaderHeight: CGFloat = 30
        // VStack spacing (月份标题和星期标题之间)
        let vStackSpacing: CGFloat = 16
        // 日历主体：行数 * 单元格高度48 + (行数-1) * 行间距8 + bottom padding 8
        // 简化：rows * 48 + (rows - 1) * 8 + 8 = rows * 56
        let calendarHeight = CGFloat(rows) * 56
        // 总高度
        return headerHeight + weekHeaderHeight + vStackSpacing + calendarHeight
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // 月份标题栏
            HStack {
                Button {
                    showYearMonthPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Text("\(stringFormat(yearMothArray[selectTab].year)).\(numberFormat(yearMothArray[selectTab].month))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.theme(.primary), Color.theme(.secondary)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.theme(.primary))
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                
                Spacer()
                
                // 月份切换按钮
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectTab = 0
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.theme(.primary))
                            .frame(width: 28, height: 28)
                            .appGlass(
                                Glass.clear.interactive().tint(Color.theme(.primary).opacity(0.25)),
                                in: Circle()
                            ) {
                                Circle().fill(Color.theme(.primary).opacity(0.12))
                            }
                    }
                    
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectTab = 2
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(canGoToNextMonth ? Color.theme(.primary) : Color("text_secondary"))
                            .frame(width: 28, height: 28)
                            .appGlass(
                                Glass.clear.interactive().tint(canGoToNextMonth ? Color.theme(.primary).opacity(0.25) : Color("divider").opacity(0.4)),
                                in: Circle()
                            ) {
                                Circle().fill(canGoToNextMonth ? Color.theme(.primary).opacity(0.12) : Color("divider").opacity(0.4))
                            }
                    }
                    .disabled(!canGoToNextMonth)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // 星期标题
            HStack(spacing: 0) {
                ForEach(week, id: \.self) { weekday in
                    Text(weekday)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color("text_secondary"))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            
            // 日历主体
            TabView(selection: $selectTab) {
                ClaendarMonthTabView(
                    selectYear: yearMothArray[0].year,
                    selectMonth: yearMothArray[0].month,
                    selectDayItem: $selectDayItem,
                    markedDates: markedDates,
                    onDateSelected: onDateSelected
                ).tag(0)
                ClaendarMonthTabView(
                    selectYear: yearMothArray[1].year,
                    selectMonth: yearMothArray[1].month,
                    selectDayItem: $selectDayItem,
                    markedDates: markedDates,
                    onDateSelected: onDateSelected
                ).tag(1)
                ClaendarMonthTabView(
                    selectYear: yearMothArray[2].year,
                    selectMonth: yearMothArray[2].month,
                    selectDayItem: $selectDayItem,
                    markedDates: markedDates,
                    onDateSelected: onDateSelected
                ).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: selectTab) { oldvalue,newValue in
                // 延迟少量时间，确保分页手势完成再跳回中间，避免 80% 进度就触发
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 350_000_000) // 150ms
                    guard selectTab == newValue else { return } // 手势未定型时不处理
                    switch newValue {
                    case 0:
                        withAnimation(.none) {  changeYearMothArray(tagIndex: 0); selectTab = 1 }
                    case 2:
                        if !allowFutureMonths && isCurrentMonth(year: yearMothArray[2].year, month: yearMothArray[2].month) {
                            withAnimation(.none) { selectTab = 2 }
                        } else {
                            withAnimation(.none) { changeYearMothArray(tagIndex: 2); selectTab = 1 }
                        }
                    default:
                        break
                    }
                }
            }
            // 监听"实际显示的年月"，不管是按钮切换、手势滑动、还是边界锁定分支，
            // 只要展示月份真正变化就会触发一次，避免在某个分支里漏加回调
            .onChange(of: displayedYearMonthKey) { _, _ in
                onMonthChanged?(yearMothArray[selectTab].year, yearMothArray[selectTab].month)
            }
            
        }
       
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .frame(height: 340)

        .glassContainer(.regular.interactive(), cornerRadius: 16)
        .padding(.horizontal, 4)
        .onAppear() {
            
        }
        .sheet(isPresented: $showYearMonthPicker) {
            YearMonthPickerSheet(
                initialYear: yearMothArray[selectTab].year,
                initialMonth: yearMothArray[selectTab].month,
                allowFutureMonths: allowFutureMonths
            ) { year, month in
                jumpTo(year: year, month: month)
            }
        }
    }
}



// MARK: - 年月选择弹窗
struct YearMonthPickerSheet: View {
    @State var selectedYear: Int
    @State var selectedMonth: Int
    var allowFutureMonths: Bool
    var onConfirm: (Int, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let currentYear = Calendar.current.component(.year, from: Date())
    private let currentMonth = Calendar.current.component(.month, from: Date())
    
    init(initialYear: Int, initialMonth: Int, allowFutureMonths: Bool, onConfirm: @escaping (Int, Int) -> Void) {
        _selectedYear = State(initialValue: initialYear)
        _selectedMonth = State(initialValue: initialMonth)
        self.allowFutureMonths = allowFutureMonths
        self.onConfirm = onConfirm
    }
    
    // 可选择的年份范围：往前 10 年，往后到当前年（若允许未来月份则可以更晚）
    private var years: [Int] {
        let maxYear = allowFutureMonths ? currentYear + 1 : currentYear
        return Array((maxYear - 10)...maxYear)
    }
    
    // 当前选中年份下可选的月份：若是今年且不允许未来月份，只到当前月
    private var availableMonths: [Int] {
        if allowFutureMonths || selectedYear < currentYear {
            return Array(1...12)
        } else if selectedYear == currentYear {
            return Array(1...currentMonth)
        } else {
            return Array(1...12)
        }
    }
    
    var body: some View {
        NavigationView {
            HStack(spacing: 0) {
                // 年份选择
                Picker("年", selection: $selectedYear) {
                    ForEach(years, id: \.self) { year in
                        Text("\(year)年").tag(year)
                    }
                }
                .pickerStyle(.wheel)
                
                // 月份选择：只展示当前所选年份下可选的月份
                Picker("月", selection: $selectedMonth) {
                    ForEach(availableMonths, id: \.self) { month in
                        Text("\(numberFormat(month))月").tag(month)
                    }
                }
                .pickerStyle(.wheel)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .navigationTitle("选择年月")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }.foregroundColor(Color("text_secondary"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定") {
                        onConfirm(selectedYear, selectedMonth)
                        dismiss()
                    }.foregroundColor(Color.theme(.primary))
                }
            }
            .onChange(of: selectedYear) { _, newYear in
                // 切换年份后，若当前选中的月份在新年份下不可选（比如切到今年但月份是未来月），
                // 自动修正为该年份下最大的可选月份
                let maxAvailable = (allowFutureMonths || newYear < currentYear) ? 12 : currentMonth
                if selectedMonth > maxAvailable {
                    selectedMonth = maxAvailable
                }
            }
        }
        .presentationDetents([.height(320)])
    }
}

struct ClaendarMonthTabView: View {
    // 当前这个组件所在的年份
    var selectYear = Calendar.current.component(.year, from: Date())
    // 当前这个组件所在的月份
    var selectMonth = Calendar.current.component(.month, from: Date())
    // 选择的日期
    @Binding var selectDayItem:DayItem
    // 标记的日期
    var markedDates: Set<String> = []
    // 日期选择回调
    var onDateSelected: ((DayItem) -> Void)?
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 0) {
            ForEach(0..<getFirstWeekday(), id: \.self) { item in
                Color.clear
                    .frame(height: 36)
            }
            ForEach(getDaysInMonth(), id: \.date) { day in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        changeSelectDate(day)
                    }
                } label: {
                    VStack(alignment: .center, spacing: 2) {
                        ZStack {
                            // 选中状态背景
                            if selectDayItem.indexStr() == day.indexStr() {
                                Circle()
                                    .fill(Color.clear)
                                    .appGlass(
                                        Glass.regular.interactive().tint(Color.theme(.primary)),
                                        in: Circle()
                                    ) {
                                        Circle().fill(
                                            LinearGradient(
                                                colors: [Color.theme(.primary), Color.theme(.secondary)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .shadow(color: Color.theme(.primary).opacity(0.3), radius: 4, x: 0, y: 2)
                                    }
                            }
                            // 今天的背景
                            else if day.isToday {
                                Circle()
                                    .fill(Color.clear)
                                    .appGlass(
                                        Glass.clear.interactive().tint(Color.theme(.primary).opacity(0.3)),
                                        in: Circle()
                                    ) {
                                        Circle()
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [Color.theme(.primary), Color.theme(.secondary)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1.5
                                            )
                                    }
                            }

                            // 日期文字
                            Text("\(day.day)")
                                .font(.system(size: 14, weight: selectDayItem.indexStr() == day.indexStr() ? .bold : .medium))
                                .foregroundStyle(
                                    selectDayItem.indexStr() == day.indexStr()
                                        ? .white
                                        : day.isToday
                                            ? Color.theme(.primary)
                                            : Color("text_primary")
                                )
                        }
                        .frame(width: 32, height: 32)
                        .frame(maxWidth: .infinity)
                        .contentShape(Circle())
                        
                        // 标记小红点
                        if markedDates.contains(day.indexStr()) {
                            Circle()
                                .fill(Color("warning"))
                                .frame(width: 4, height: 4)
                        } else {
                            Color.clear
                                .frame(width: 4, height: 4)
                        }
                    }
                    .frame(height: 40)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }.frame(maxHeight:.infinity, alignment: .top)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
    
    func changeSelectDate(_ day: DayItem) {
        selectDayItem = day
        onDateSelected?(day)
    }
    
    // 计算这个月第一天是星期几
    func getFirstWeekday() -> Int {
        let calendar = Calendar.current
        let firstDay = calendar.date(from: DateComponents(year: selectYear, month: selectMonth, day: 1))!
        let weekday = calendar.component(.weekday, from: firstDay)
        return weekday - 1
        
    }
    // 获取这个月所有日期的数组 
    func getDaysInMonth() -> [DayItem] {
        let calendar = Calendar.current
        let today = Date()
        
        // 获取这个月的第一天
        guard let firstDay = calendar.date(from: DateComponents(year: selectYear, month: selectMonth, day: 1)) else {
            return []
        }
        
        // 获取这个月的天数范围
        guard let range = calendar.range(of: .day, in: .month, for: firstDay) else {
            return []
        }
        
        // 获取这个月的所有日期
        var days: [DayItem] = []
        
        for day in range {
            guard let date = calendar.date(from: DateComponents(year: selectYear, month: selectMonth, day: day)) else {
                continue
            }
            let dayItem = buildDayItem(date: date, today: today, calendar: calendar)
            days.append(dayItem)
        }
        
        return days
    }
    
    
}

struct DayItem {
    // 日期
    var date: Date
    // 年
    var year: Int
    // 月
    var month: Int
    // 日
    var day: Int
    // 星期几
    var weekday: Int
    // 是否是今天
    var isToday: Bool
    
    func indexStr() -> String {
        return "\(stringFormat(year))-\(numberFormat(month))-\(numberFormat(day))"
    }
}


struct YearMoth {
    // 年
    var year: Int
    // 月
    var month: Int
    
    func pre() -> YearMoth {
        let preYear = month - 1 < 1 ? year - 1: year
        let preMonth = month - 1 < 1 ? 12 : month - 1
        return YearMoth(year: preYear, month: preMonth)
    }
    
    func next() -> YearMoth {
        let nextYear = month + 1 > 12 ? year + 1 : year
        let nextMonth = month + 1 > 12 ? 1 : month + 1
        return YearMoth(year: nextYear, month: nextMonth)
    }
}

func buildYearMoth(today:Date = Date()) -> YearMoth {
    let calendar = Calendar.current
    let year = calendar.component(.year, from: Date())
    var month = calendar.component(.month, from: Date())
    return YearMoth(year: year, month: month)
}

func buildDayItem(date:Date, today:Date = Date(), calendar:Calendar = Calendar.current) -> DayItem {
    let year = calendar.component(.year, from: date)
    let month = calendar.component(.month, from: date)
    let dayOfMonth = calendar.component(.day, from: date)
    let weekday = calendar.component(.weekday, from: date) - 1 // 转换为0-6（周日为0）
    let isToday = calendar.isDate(date, inSameDayAs: today)
    
    let dayItem = DayItem(
        date: date,
        year: year,
        month: month,
        day: dayOfMonth,
        weekday: weekday,
        isToday: isToday
    )
    return dayItem
}

func stringFormat(_ number: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .none
    return formatter.string(from: number as NSNumber) ?? ""
}

func numberFormat(_ number: Int) -> String {
    if number < 10 {
        return "0\(number)"
    }
    return "\(number)"
}


// MARK: - 按钮样式
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    CalendarView()
        .frame(maxWidth: .infinity)
        .preferredColorScheme(.light)
        .padding()
        .background(Color(.systemGroupedBackground))
}
