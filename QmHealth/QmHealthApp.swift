//
//  QmHealthApp.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/2/23.
//

import SwiftUI

@main
struct QmHealthApp: App {
    @StateObject private var themeManager = ThemeManager.shared

    init() {
        // 通知代理要在启动早期注册：App 在前台时系统默认不展示本地通知。
        MedicineReminder.shared.setup()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
}
