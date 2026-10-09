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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
}
