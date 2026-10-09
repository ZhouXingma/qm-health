//
//  SubPopManager.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/6/21.
//
import SwiftUI

class SubPopManager: ObservableObject {
    // 单例实例
    static let shared = SubPopManager();
    // 显示弹窗
    @Published var showSubPop = false
    // 底部弹窗的高度
    @Published var height: CGFloat = 300.0;
    // 自定义内容
    @Published var customContent: AnyView? = nil
    // 自定义按钮动作
    @Published var customAction: (() -> Void)? = nil
    
    public init() {}
    
    func showCustomSubPop<Content: View>(customAction: @escaping () -> Void, content: () -> Content) {
        self.customContent = AnyView(content())
        self.customAction = customAction
        withAnimation(.easeInOut(duration: 0.3)) {
            showSubPop = true
        }
    }
    
    func showCustomSubPopWithHeight<Content: View>(height: CGFloat, customAction: @escaping () -> Void, content: () -> Content) {
        self.height = height;
        self.customAction = customAction;
        self.customContent = AnyView(content())
        withAnimation(.easeInOut(duration: 0.3)) {
            showSubPop = true
        }
    }
    
    // 关闭弹窗
    func closeSubPop() {
        self.showSubPop = false
    }
    
}
