//
//  HomeRefreshBus.swift
//  QmHealth
//  首页下拉刷新的事件总线，通过 @EnvironmentObject 注入给首页各子组件。
//

import Foundation
import Combine

final class HomeRefreshBus: ObservableObject {
    /// 单例：让 Home 之外的入口（如切换账户）也能拿到同一个 bus 实例触发首页刷新。
    static let shared = HomeRefreshBus()

    /// 每次下拉刷新都会更新这个 UUID，子组件通过 .onChange(of:) 监听触发 reload。
    @Published var refreshTrigger: UUID = UUID()

    /// 主动触发一次首页刷新
    func triggerRefresh() {
        refreshTrigger = UUID()
    }
}