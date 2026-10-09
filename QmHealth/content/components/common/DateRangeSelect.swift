// 时间范围选择
//  DateRangeSelect.swift
//  AppComponent
//
//  Created by 周荥马 on 2025/11/10.
//

import SwiftUI

struct DateRangeSelect: View {
    // 是否显示日期单位
    var showDateUnit = true
    // 开始时间
    @Binding var startDate: Date
    // 结束时间
    @Binding var endDate: Date
    // 单位
    @Binding var unitCode:Int
    // 颜色
    @State var color:Color = Color.black
    // 前一个时间按钮是否允许点击
    @State private var preButtonEnable = true
    // 后一个时间按钮是否允许点击
    @State private var nextButtonEnable = false
    // 显示切换时间单位的sheet
    @State private var showPicker = false

    private let calendar = Calendar.current
    // 今天结束时间
    private let todayEndOfDay: Date = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: Date()) ?? Date()
    
    init(showDateUnit: Bool = true, startDate: Binding<Date>, endDate: Binding<Date>, unitCode: Binding<Int>, color: Color) {
        self.showDateUnit = showDateUnit
        self.color = color
        _startDate = startDate
        _endDate = endDate
        _unitCode = unitCode
    }
    
    
    var body: some View {
        HStack {
            HStack {
                // 前一个时间段
                Button {
                    preHandle()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(preButtonEnable ? color : color.opacity(0.3))
                }
                .disabled(!preButtonEnable)
                
                Spacer()
                // 时间显示
                if unitCode == 5 {
                    HStack {
                        Text("\(startDate, formatter: DateRangeSelect.dateFormatter)")
                            .fontWeight(.medium)
                        Text("00:00 ~ 23:59")
                    }.fontWeight(.medium)
                        .font(.system(size: 14))
                } else {
                    Text("\(startDate, formatter: DateRangeSelect.dateFormatter)")
                        .fontWeight(.medium)
                        .font(.system(size: 14))
                    Text("~")
                    Text("\(endDate, formatter: DateRangeSelect.dateFormatter)")
                        .fontWeight(.medium)
                        .font(.system(size: 14))
                }
                
                Spacer()
                
                // 后一个时间段
                Button {
                    nextHandle()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(nextButtonEnable ? color : color.opacity(0.3))
                }
                .disabled(!nextButtonEnable)
            }
            .padding(10)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
            // 是否显示时间单位
            if showDateUnit {
                Button {
                   showPicker.toggle()
                } label: {
                   HStack {
                       Text("\(getUnitText(unitCode))")
                           .font(.system(size: 14))
                           .fontWeight(.bold)
                           .foregroundStyle(color)
                   }
                   .padding(.horizontal, AppSpacing.regular)
                   .padding(.vertical, AppSpacing.regular)
                   .appGlass(.regular.interactive(), in: Circle()) {
                       Circle().fill(Color.clear)
                   }
                }
                .actionSheet(isPresented: $showPicker) {
                   ActionSheet(
                       title: Text("时间范围"),
                       buttons: [
                           .default(Text("年")) { changeUnit(1) },
                           .default(Text("季")) { changeUnit(2) },
                           .default(Text("月")) { changeUnit(3) },
                           .default(Text("周")) { changeUnit(4) },
                           .default(Text("日")) { changeUnit(5) },
                           .cancel()
                       ]
                   )
                }
            }
        }
        .onChange(of: unitCode) { _, _ in
            changeRangeByUnit()
        }
    }
    
    // MARK: - 辅助方法
    func changeUnit(_ unitCode: Int) {
        self.unitCode = unitCode
    }
    
    func getUnitText(_ unitCode: Int) -> String {
        switch unitCode {
        case 1: return "年"
        case 2: return "季"
        case 3: return "月"
        case 4: return "周"
        case 5: return "日"
        default:
            return "年"
        }
    }
    
    private static func endOfDay(for date: Date) -> Date {
        let calendar = Calendar.current;
        return calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
    }
    
    private static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
    
    // MARK: - Navigation Handlers
    
    func preHandle() {
        guard let newRange = DateRangeSelect.calculateRange(for: unitCode, direction: .backward, from: startDate) else { return }
        startDate = newRange.start
        endDate = newRange.end
        preButtonEnable = true // 可继续往前（除非你设最小限制）
        nextButtonEnable = endDate < todayEndOfDay
    }
    
    func nextHandle() {
        guard let newRange = DateRangeSelect.calculateRange(for: unitCode, direction: .forward, from: startDate) else { return }
        startDate = newRange.start
        endDate = newRange.end
        nextButtonEnable = endDate < todayEndOfDay
        preButtonEnable = true
    }
    
    // MARK: - Date Range Calculation
    enum Direction {
        case forward, backward
    }
    /// 更改了单位
    private func changeRangeByUnit() {
        guard let newRange = DateRangeSelect.calculateRange(for: unitCode, direction: nil, from: Date()) else { return }
        startDate = newRange.start
        endDate = newRange.end
    }

    public static func calculateRange(for unit: Int, direction: Direction?, from referenceDate: Date) -> (start: Date, end: Date)? {
        let calendar = Calendar.current;
        let now = Date();
        let todyEndDate = endOfDay(for: now)
        // 前后滚动
        let offset = direction == nil ? 0 : direction == .forward ? 1 : -1
        
        switch unit {
        case 1: // 年
            guard let targetYearDate = calendar.date(byAdding: .year, value: offset, to: referenceDate) else { return nil }
            let components = calendar.dateComponents([.year], from: targetYearDate)
            guard let start = calendar.date(from: components) else { return nil }
            guard let yearEnd = calendar.date(byAdding: .year, value: 1, to: start),
                  let end = calendar.date(byAdding: .day, value: -1, to: yearEnd) else { return nil }
            let endOfDay = endOfDay(for: end)
            return (DateUtils.getStartDay(date: start) , min(endOfDay, todyEndDate))
            
        case 2: // 季
            let monthOffset = offset * 3
            guard let targetDate = calendar.date(byAdding: .month, value: monthOffset, to: referenceDate) else { return nil }
            let year = calendar.component(.year, from: targetDate)
            let month = calendar.component(.month, from: targetDate)
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            guard let start = calendar.date(from: DateComponents(year: year, month: quarterStartMonth, day: 1)) else { return nil }
            guard let quarterEnd = calendar.date(byAdding: .month, value: 3, to: start),
                  let end = calendar.date(byAdding: .day, value: -1, to: quarterEnd) else { return nil }
            let endOfDay = endOfDay(for: end)
            return (DateUtils.getStartDay(date: start), min(endOfDay, todyEndDate))
            
        case 3: // 月
            guard let targetDate = calendar.date(byAdding: .month, value: offset, to: referenceDate) else { return nil }
            let comps = calendar.dateComponents([.year, .month], from: targetDate)
            guard let start = calendar.date(from: comps) else { return nil }
            guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: start),
                  let end = calendar.date(byAdding: .day, value: -1, to: monthEnd) else { return nil }
            let endOfDay = endOfDay(for: end)
            return (DateUtils.getStartDay(date: start), min(endOfDay, todyEndDate))
            
        case 4: // 周（周日为开始）
            guard let targetDate = calendar.date(byAdding: .weekOfYear, value: offset, to: referenceDate) else { return nil }
            let weekday = calendar.component(.weekday, from: targetDate)
            let daysToMonday = (weekday - 1 + 7) % 7 // Sunday=1, Monday=2 → adjust to Monday=0
            guard let start = calendar.date(byAdding: .day, value: -daysToMonday, to: targetDate) else { return nil }
            guard let end = calendar.date(byAdding: .day, value: 6, to: start) else { return nil }
            let endOfDay = endOfDay(for: end)
            return (DateUtils.getStartDay(date: start), min(endOfDay, todyEndDate))
            
        case 5: // 日
            guard let targetDate = calendar.date(byAdding: .day, value: offset, to: referenceDate) else { return nil }
            let start = calendar.startOfDay(for: targetDate)
            let endOfDay = self.endOfDay(for: start)
            return (DateUtils.getStartDay(date: start), min(endOfDay, todyEndDate))
            
        default:
            return nil
        }
    }
    
    
   
}

#Preview {
    @Previewable @State var startDate = DateUtils.getStartDay(date: Date())
    @Previewable @State var endDate = DateUtils.getEndDay(date: Date())
    @Previewable @State var dateUnitCode = 5
    
    DateRangeSelect(showDateUnit: true, startDate: $startDate, endDate: $endDate, unitCode: $dateUnitCode, color: Color.black);
}
