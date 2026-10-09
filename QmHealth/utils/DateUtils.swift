//
//  CalendarUtil.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/6/3.
//

import Foundation

class DateUtils {
    
    // MARK: - 获取当前日期时间
    
    /// 获取当前日期时间
    public static func getCurrentDate() -> Date {
        return Date()
    }
    
    /// 获取当前年份
    public static func getCurrentYear() -> Int {
        let calendar = Calendar.current
        return calendar.component(.year, from: Date())
    }
    
    /// 获取当前月份
    public static func getCurrentMonth() -> Int {
        let calendar = Calendar.current
        return calendar.component(.month, from: Date())
    }
    
    /// 获取当前日
    public static func getCurrentDay() -> Int {
        let calendar = Calendar.current
        return calendar.component(.day, from: Date())
    }
    
    /// 获取当前小时
    public static func getCurrentHour() -> Int {
        let calendar = Calendar.current
        return calendar.component(.hour, from: Date())
    }
    
    /// 获取当前分钟
    public static func getCurrentMinute() -> Int {
        let calendar = Calendar.current
        return calendar.component(.minute, from: Date())
    }
    
    /// 获取当前秒
    public static func getCurrentSecond() -> Int {
        let calendar = Calendar.current
        return calendar.component(.second, from: Date())
    }
    /// 获取当前时间的最后时间
    public static func getEndDay(date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date;
    }
    /// 获取当前时间的开始时间
    public static func getStartDay(date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: 0, minute: 0, second: 0, of: date) ?? date;
    }
    
    // MARK: - 日期组件获取
    
    /// 从日期获取年份
    public static func getYear(from date: Date) -> Int {
        let calendar = Calendar.current
        return calendar.component(.year, from: date)
    }
    
    /// 从日期获取月份
    public static func getMonth(from date: Date) -> Int {
        let calendar = Calendar.current
        return calendar.component(.month, from: date)
    }
    
    /// 从日期获取日
    public static func getDay(from date: Date) -> Int {
        let calendar = Calendar.current
        return calendar.component(.day, from: date)
    }
    
    /// 从日期获取小时
    public static func getHour(from date: Date) -> Int {
        let calendar = Calendar.current
        return calendar.component(.hour, from: date)
    }
    
    /// 从日期获取分钟
    public static func getMinute(from date: Date) -> Int {
        let calendar = Calendar.current
        return calendar.component(.minute, from: date)
    }
    
    /// 从日期获取秒
    public static func getSecond(from date: Date) -> Int {
        let calendar = Calendar.current
        return calendar.component(.second, from: date)
    }
    
    // MARK: - 日期增减操作
    
    /// 增加年
    public static func addYears(to date: Date, years: Int) -> Date? {
        var dateComponents = DateComponents()
        dateComponents.year = years
        let calendar = Calendar.current
        return calendar.date(byAdding: dateComponents, to: date)
    }
    
    /// 增加月
    public static func addMonths(to date: Date, months: Int) -> Date? {
        var dateComponents = DateComponents()
        dateComponents.month = months
        let calendar = Calendar.current
        return calendar.date(byAdding: dateComponents, to: date)
    }
    
    /// 增加周
    public static func addWeeks(to date: Date, weeks: Int) -> Date? {
        var dateComponents = DateComponents()
        dateComponents.weekOfYear = weeks
        let calendar = Calendar.current
        return calendar.date(byAdding: dateComponents, to: date)
    }
    
    /// 增加日
    public static func addDays(to date: Date, days: Int) -> Date? {
        var dateComponents = DateComponents()
        dateComponents.day = days
        let calendar = Calendar.current
        return calendar.date(byAdding: dateComponents, to: date)
    }
    
    /// 增加小时
    public static func addHours(to date: Date, hours: Int) -> Date? {
        var dateComponents = DateComponents()
        dateComponents.hour = hours
        let calendar = Calendar.current
        return calendar.date(byAdding: dateComponents, to: date)
    }
    
    /// 增加分钟
    public static func addMinutes(to date: Date, minutes: Int) -> Date? {
        var dateComponents = DateComponents()
        dateComponents.minute = minutes
        let calendar = Calendar.current
        return calendar.date(byAdding: dateComponents, to: date)
    }
    
    /// 增加秒
    public static func addSeconds(to date: Date, seconds: Int) -> Date? {
        var dateComponents = DateComponents()
        dateComponents.second = seconds
        let calendar = Calendar.current
        return calendar.date(byAdding: dateComponents, to: date)
    }
    
    // MARK: - 日期格式化
    
    /// 自定义格式化日期
    public static func formatDate(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    
    /// 常用日期格式
    public struct DateFormat {
        public static let ymdhms = "yyyy-MM-dd HH:mm:ss"
        public static let ymdhmssss = "yyyy-MM-dd HH:mm:ss.SSS"
        public static let ymd = "yyyy-MM-dd"
        public static let hms = "HH:mm:ss"
        public static let hm = "HH:mm"
        public static let yyyymm = "yyyy-MM"
        public static let mmdd = "MM-dd"
        public static let ymd_zh = "yyyy年MM月dd日"
        public static let ymdhms_zh = "yyyy年MM月dd日 HH时mm分ss秒"
        public static let ymd_r = "yyyy/MM/dd"
        public static let ymd_d = "yyyy.MM.dd"
        public static let yyyymmdd = "yyyyMMdd"
        public static let yyyyMMddHHmmss = "yyyyMMddHHmmss"
    }
    
    // MARK: - 日期比较
    
    /// 比较两个日期是否是同一天
    public static func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        let calendar = Calendar.current
        let components1 = calendar.dateComponents([.year, .month, .day], from: date1)
        let components2 = calendar.dateComponents([.year, .month, .day], from: date2)
        return components1.year == components2.year && 
               components1.month == components2.month && 
               components1.day == components2.day
    }
    
    /// 比较两个日期是否是同一月
    public static func isSameMonth(_ date1: Date, _ date2: Date) -> Bool {
        let calendar = Calendar.current
        let components1 = calendar.dateComponents([.year, .month], from: date1)
        let components2 = calendar.dateComponents([.year, .month], from: date2)
        return components1.year == components2.year && components1.month == components2.month
    }
    
    /// 比较两个日期是否是同一年
    public static func isSameYear(_ date1: Date, _ date2: Date) -> Bool {
        let calendar = Calendar.current
        let components1 = calendar.dateComponents([.year], from: date1)
        let components2 = calendar.dateComponents([.year], from: date2)
        return components1.year == components2.year
    }
    
    /// 计算两个日期之间的天数差
    public static func daysBetween(_ start: Date, _ end: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: start, to: end)
        return components.day ?? 0
    }
    
    /// 计算两个日期之间的月数差
    public static func monthsBetween(_ start: Date, _ end: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: start, to: end)
        return components.month ?? 0
    }
    
    /// 计算两个日期之间的年数差
    public static func yearsBetween(_ start: Date, _ end: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: start, to: end)
        return components.year ?? 0
    }
    
    // MARK: - 日期转换
    
    /// 字符串转日期
    public static func stringToDate(_ string: String, format: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.date(from: string)
    }
    
    /// 时间戳(秒)转日期
    public static func timestampToDate(_ timestamp: TimeInterval) -> Date {
        return Date(timeIntervalSince1970: timestamp)
    }
    
    /// 时间戳(毫秒)转日期
    public static func timestampToDate(_ timestamp: Int64) -> Date {
        // 将Int64转换为Double，因为timeIntervalSince1970需要Double类型的时间间隔
        let timeInterval = Double(timestamp/1000)
        // 使用timeIntervalSince1970初始化Date对象
        let date = Date(timeIntervalSince1970: timeInterval)
        return date;
    }

    /// 日期转时间戳(毫秒)
    public static func dateToTimestamp(_ date: Date) -> Int64 {
        // 触发滚动更新 - 使用内容变化
        let secondsTimestamp = date.timeIntervalSince1970
        let millisecondsTimestamp = Int64(secondsTimestamp * 1000)
        return millisecondsTimestamp;
    }
    
    // MARK: - 特殊日期获取
    
    /// 获取指定日期所在月的第一天
    public static func firstDayOfMonth(for date: Date) -> Date? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components)
    }
    
    /// 获取指定日期所在月的最后一天
    public static func lastDayOfMonth(for date: Date) -> Date? {
        let calendar = Calendar.current
        var components = DateComponents()
        components.month = 1
        components.day = -1
        guard let firstDayNextMonth = calendar.date(byAdding: components, to: firstDayOfMonth(for: date)!) else {
            return nil
        }
        return firstDayNextMonth
    }
    
    /// 获取指定日期所在周的第一天（周日为第一天）
    public static func firstDayOfWeek(for date: Date) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        components.weekday = 1 // 1 表示周日
        return calendar.date(from: components)
    }
    
    /// 获取指定日期所在周的最后一天（周六为最后一天）
    public static func lastDayOfWeek(for date: Date) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        components.weekday = 7 // 7 表示周六
        return calendar.date(from: components)
    }
    
    /// 获取指定日期所在年的第一天
    public static func firstDayOfYear(for date: Date) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year], from: date)
        components.month = 1
        components.day = 1
        return calendar.date(from: components)
    }
    
    /// 获取指定日期所在年的最后一天
    public static func lastDayOfYear(for date: Date) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year], from: date)
        components.month = 12
        components.day = 31
        return calendar.date(from: components)
    }
}
