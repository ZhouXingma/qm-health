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
    @Environment(\.scenePhase) private var scenePhase

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
        .onChange(of: globalModel.isLogin) { _, isLogin in
            // 登录后重排用药提醒以滚动调度窗口；未登录时 refresh 内部会直接清理。
            if isLogin {
                MedicineReminder.shared.refresh()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // 从后台切回前台也要重排：App 未被杀时 isLogin 不变，
            // 只靠上面的 onChange 会漏掉「回到 App 补发错过提醒」这条路径。
            if phase == .active {
                MedicineReminder.shared.refresh()
            }
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
