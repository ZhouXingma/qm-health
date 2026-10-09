//
//  ContentView.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/2/23.
//

import SwiftUI

struct ContentView: View {
    @StateObject var globalModel = GlobalModel.shared
    @StateObject var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack {
            if !globalModel.isLogin {
                Login()
            } else {
                if !globalModel.hasCompletedInitialSetup {
                     // 显示初始设置页面
                     InitialProfileSetupView()
                 } else {
                     // 显示主应用页面
                     Index()
                 }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color("background"))
        .environmentObject(globalModel)
        .withGlobalSubPop()
        .withGlobalPop()
        .preferredColorScheme(themeManager.colorScheme)
        .id(themeManager.appearanceTheme.rawValue)
        .onAppear() {
            initData()
            
        }
    }
    
    // MARK: - 函数
    // 初始化函数
    func initData() {
        globalModel.darkModeSettings = globalModel.darkModeSettings
        // 无需登录
        checkLogin(globalModel);
        // 检查用户是否已设置基本信息
        checkUserSetup(globalModel)
    }
}

#Preview {
    ContentView().preferredColorScheme(.light)
}
