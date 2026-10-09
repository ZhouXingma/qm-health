//
//  DateTimePicker.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/6/21.
//

import SwiftUI

struct DateTimePicker: View {
    var featureDate = false;
    var initSelectDate:Date? = nil;
    var selectDateChange: ((Date) -> Void)? = nil;
    @State private var selectYear:Int = DateUtils.getCurrentYear();
    @State private var selectMonth:Int = DateUtils.getCurrentMonth();
    @State private var selectDay:Int = DateUtils.getCurrentDay();
    // 年月日选择-年
    @State private var yearArray:[Int] = Array(DateUtils.getCurrentYear()-150...DateUtils.getCurrentYear())
    // 年月日选择-月
    @State private var monthArray:[Int] = Array(1...12)
    // 年月日选择-日
    @State private var dayArray:[Int] = Array(1...28)
    
    var body: some View {
        HStack {
            Picker("年", selection: $selectYear) {
                ForEach(yearArray, id: \.self) { item in
                    Text(String(item))
                }
            }
            .pickerStyle(.wheel)
            Picker("月", selection: $selectMonth) {
                ForEach(monthArray, id: \.self) { item in
                    Text(String(item))
                }
            }
            .pickerStyle(.wheel)
            Picker("日", selection: $selectDay) {
                ForEach(dayArray, id: \.self) { item in
                    Text(String(item))
                }
            }
            .pickerStyle(.wheel)
        }.onAppear() {
            initData()
            changeSelect()
        }.onChange(of: selectYear) { oldValue, newValue in
            initArray()
            changeSelect()
        }.onChange(of: selectMonth) { oldValue, newValue in
            initArray()
            changeSelect()
        }.onChange(of: selectDay) { oldValue, newValue in
            changeSelect()
        }
        
    }
    // 初始化数据
    func initData() {
        if nil != initSelectDate {
            let calender = Calendar.current.dateComponents([.year,.month,.day], from: initSelectDate ?? Date());
            if nil != calender.year {
                self.selectYear = calender.year!;
            }
            if nil != calender.month {
                self.selectMonth = calender.month!;
            }
            if nil != calender.day {
                self.selectDay = calender.day!;
            }
        }
        initArray()
    }
    // 初始化时间数组
    func initArray() {
        if !featureDate {
            yearArray = Array(DateUtils.getCurrentYear()-150...DateUtils.getCurrentYear())
        } else {
            yearArray = Array(DateUtils.getCurrentYear()-150...DateUtils.getCurrentYear()+150)
        }
        if selectYear == DateUtils.getCurrentYear() {
            if !featureDate {
                monthArray =  Array(1...DateUtils.getCurrentMonth());
                if selectMonth > DateUtils.getCurrentMonth() {
                    selectMonth = DateUtils.getCurrentMonth()
                }
            } else {
                monthArray =  Array(1...12);
            }
            if !featureDate && selectMonth == DateUtils.getCurrentMonth() {
                dayArray =  Array(1...DateUtils.getCurrentDay());
                if selectDay > DateUtils.getCurrentDay() {
                    selectDay = DateUtils.getCurrentDay()
                }
            } else {
                let dayEnd = getSelectMonthLastDayValue()
                dayArray =  Array(1...dayEnd);
                if selectDay > dayEnd {
                    selectDay = dayEnd
                }
            }
        }  else {
            monthArray = Array(1...12);
            let dayEnd = getSelectMonthLastDayValue()
            dayArray =  Array(1...dayEnd);
            if selectDay > dayEnd {
                selectDay = dayEnd
            }
        }
    }
    
    // 选择变化的事件
    func changeSelect() {
        if nil == selectDateChange {
            return;
        }
        let date = getSelectDate();
        selectDateChange!(date);
    }
    
    // 获取选择的月的最后一天
    func getSelectMonthLastDayValue() -> Int {
        let selctDate = getSelectMonthFirstDay();
        let monthLastDay = DateUtils.lastDayOfMonth(for: selctDate) ?? Date()
        let calendar = Calendar.current.dateComponents([.year, .month, .day], from: monthLastDay);
        let day = calendar.day;
        return day ?? 1;
    }
    
    // 获取选择的月的第一天
    func getSelectMonthFirstDay() -> Date {
        var dateStr = String(self.selectYear);
        if (self.selectMonth < 10) {
            dateStr += String("-0\(self.selectMonth)");
        } else {
            dateStr += String("-\(self.selectMonth)");
        }
        dateStr += "-01";
        return DateUtils.stringToDate(dateStr, format: DateUtils.DateFormat.ymd) ?? Date();
    }
    // 获取选择的时间字符串 yyyy-MM-dd格式
    func getSelectDateStr() -> String {
        var dateStr = String(self.selectYear);
        if (self.selectMonth < 10) {
            dateStr += String("-0\(self.selectMonth)");
        } else {
            dateStr += String("-\(self.selectMonth)");
        }
        if (self.selectDay < 10) {
            dateStr += String("-0\(self.selectDay)");
        } else {
            dateStr += String("-\(self.selectDay)");
        }
        return dateStr;
    }
    // 获取选择的时间
    func getSelectDate() -> Date {
        let dateStr = getSelectDateStr();
        return DateUtils.stringToDate(dateStr, format: DateUtils.DateFormat.ymd) ?? Date();
    }
}
