//
//  ThemeManager.swift
//  QmHealth
//
//  Created on 2026/1/24.
//

import SwiftUI

/// 应用可选择的主题色(参考苹果设计风格)
enum AppThemeColor: Int, CaseIterable, Identifiable {
    case classicOrange = 0
    case blue = 1
    case mint = 2
    case green = 3
    case purple = 4

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .classicOrange: return "经典橙"
        case .blue: return "苹果蓝"
        case .mint: return "薄荷绿"
        case .green: return "苹果绿"
        case .purple: return "葡萄紫"
        }
    }

    // MARK: - 主色
    var primaryLight: String {
        switch self {
        case .classicOrange: return "F98C53"
        case .blue: return "007AFF"
        case .mint: return "1DB6A4"
        case .green: return "0FA96B"
        case .purple: return "7A5AF0"
        }
    }
    var primaryDark: String {
        switch self {
        case .classicOrange: return "F76B22"
        case .blue: return "0A84FF"
        case .mint: return "4AD0BF"
        case .green: return "34C489"
        case .purple: return "9E84F5"
        }
    }

    // MARK: - 辅助色(渐变浅端/衬底)
    var secondaryLight: String {
        switch self {
        case .classicOrange: return "FCCEB6"
        case .blue: return "BFDBFF"
        case .mint: return "B5EAE1"
        case .green: return "C9F0DC"
        case .purple: return "E0D6FF"
        }
    }
    var secondaryDark: String {
        switch self {
        case .classicOrange: return "FBAD84"
        case .blue: return "1B3A5C"
        case .mint: return "157E70"
        case .green: return "145A41"
        case .purple: return "272052"
        }
    }

    // MARK: - 图表色
    var chart1Light: String {
        switch self {
        case .classicOrange: return "D2E0AA"
        case .blue: return "9CCBFF"
        case .mint: return "63DDC8"
        case .green: return "73E0A3"
        case .purple: return "B197FF"
        }
    }
    var chart1Dark: String {
        switch self {
        case .classicOrange: return "BED285"
        case .blue: return "3B7FD0"
        case .mint: return "4CBF9F"
        case .green: return "3FBE80"
        case .purple: return "8A6CF5"
        }
    }
}

/// 主题色令牌,供 Color.theme(_:) 解析
enum ThemeToken {
    case primary
    case secondary
    case chart1
    case chart2
    case chart3
    case chart4
}

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @AppStorage("appThemeMode") var themeMode: Int = 0 // 0: 跟随系统, 1: 浅色, 2: 深色

    /// 当前主题色,变化时全局应用
    @Published var appearanceTheme: AppThemeColor {
        didSet {
            UserDefaults.standard.set(appearanceTheme.rawValue, forKey: "appThemeColor")
        }
    }

    init() {
        appearanceTheme = AppThemeColor(rawValue: UserDefaults.standard.integer(forKey: "appThemeColor")) ?? .classicOrange
    }

    func setTheme(_ theme: AppThemeColor) {
        appearanceTheme = theme
    }

    var colorScheme: ColorScheme? {
        switch themeMode {
        case 1:
            return .light
        case 2:
            return .dark
        default:
            return nil // 跟随系统
        }
    }
}

// MARK: - UIColor / Color 动态主题色

extension UIColor {
    convenience init(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}

extension AppThemeColor {
    /// 亮色主色(色卡预览用,不随当前主题变化)
    var previewPrimary: Color {
        Color(uiColor: UIColor(hexString: primaryLight))
    }
    /// 亮色辅助色(色卡预览用)
    var previewSecondary: Color {
        Color(uiColor: UIColor(hexString: secondaryLight))
    }
}

extension UIColor {
    /// 依据当前主题与 trait 亮暗生成动态色,随模式自动切换
    static func theme(_ token: ThemeToken) -> UIColor {
        UIColor { trait in
            let theme = ThemeManager.shared.appearanceTheme
            let dark = trait.userInterfaceStyle == .dark
            let hex: String
            switch token {
            case .primary:
                hex = dark ? theme.primaryDark : theme.primaryLight
            case .secondary:
                hex = dark ? theme.secondaryDark : theme.secondaryLight
            case .chart1:
                hex = dark ? theme.chart1Dark : theme.chart1Light
            case .chart2:
                hex = dark ? "4D8FE0" : "63AEF8"
            case .chart3:
                hex = dark ? "8A6CF5" : "B197FF"
            case .chart4:
                hex = dark ? "E89A42" : "FFB25E"
            }
            return UIColor(hexString: hex)
        }
    }
}

extension Color {
    /// 主题色:主色 mainPrimary、辅助色 mainSecondary、图表系列 color1-4
    static func theme(_ token: ThemeToken) -> Color {
        Color(UIColor.theme(token))
    }
}