//
//  GlobalModel.swift
//  qm_health
//
//  Created by 周荥马 on 2025/2/22.
//

import SwiftUI
import Combine
class GlobalModel: ObservableObject {
    // 单例实例
    static public let shared = GlobalModel()
    // 是否已经登录
    @Published var isLogin:Bool = false;
    // 是否已完成初始设置
    @Published var hasCompletedInitialSetup: Bool = true
    // 选择的用户id
    @Published var currentUser:UserDTO?
    // 模式设置
    @Published var darkModeSettings: Int = UserDefaults.standard.integer(forKey: "darkMode") {
            didSet {
                UserDefaults.standard.set(self.darkModeSettings, forKey: "darkMode")
                let scenes = UIApplication.shared.connectedScenes
                let windowScene = scenes.first as? UIWindowScene
                let window = windowScene?.windows.first
                switch self.darkModeSettings {
                case 0:
                 window?.overrideUserInterfaceStyle = .unspecified
                case 1:
                 window?.overrideUserInterfaceStyle = .light
                case 2:
                 window?.overrideUserInterfaceStyle = .dark
                default:
                 window?.overrideUserInterfaceStyle = .unspecified
                }
            }
        }
    // 是否显示下面的进度
    @Published var showSubBar = true;
    // AI聊天跳转 - 待处理的会话ID（从消息通知跳转到AI聊天tab）
    @Published var pendingAiChatConversationId: String? = nil
    
    private init() {
        
    }
    
    public func reset() {
        self.isLogin = false;
        self.hasCompletedInitialSetup = true;
        self.currentUser = nil;
    }
}
