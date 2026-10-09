//
//  PopManager.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/3/25.
//

import SwiftUI

class PopManager: ObservableObject {
    // 单例实例
    static let shared = PopManager()
    
    // 显示弹窗
    @Published var showPop = false
    // 弹窗内容
    @Published var popIcon = PopIconEnum.type3
    // 弹窗高度
    @Published var popH: CGFloat = 250
    // 弹窗宽度
    @Published var popW: CGFloat = 300
    // 弹窗标题和描述
    @Published var popInfoTitle = ""
    @Published var popInfoDes = ""
    // 自定义内容
    @Published var customContent: AnyView? = nil
    // 自定义按钮文本
    @Published var buttonText = "知道了"
    // 自定义按钮动作
    @Published var customAction: (() -> Void)? = nil
    // 取消按钮显示
    @Published var buttonCancleShow = false
    // 取消按钮名称
    @Published var buttonCancleTitle = "取消"
    // 自定义取消动作
    @Published var customCancelAction: (() -> Void)? = nil
    
    public init() {}
    
    // 显示简单弹窗
    func showSimplePop(title: String, description: String, icon: PopIconEnum = .type3) {
        self.popInfoTitle = title
        self.popInfoDes = description
        self.popIcon = icon
        self.customContent = nil
        self.buttonText = "知道了"
        self.customAction = nil
        self.showPop = true
    }
    
    // 显示自定义内容弹窗
    func showCustomPop<Content: View>(icon: PopIconEnum = .type3, height: CGFloat = 250, width: CGFloat = 300, @ViewBuilder content: () -> Content) {
        self.popIcon = icon
        self.popH = height
        self.popW = width
        self.customContent = AnyView(content())
        self.showPop = true
    }
    
    // 显示带自定义按钮的弹窗
    func showActionPop(title: String,
                       description: String,
                       buttonText: String = "确定",
                       icon: PopIconEnum = .type3,
                       buttonCancleShow:Bool = false,
                       buttonCancleTitle: String = "取消",
                       customAction: @escaping () -> Void,
                       customCancelAction: @escaping () -> Void) {
        self.popInfoTitle = title
        self.popInfoDes = description
        self.popIcon = icon
        self.customContent = nil
        self.buttonText = buttonText
        self.customAction = customAction
        self.buttonCancleShow = buttonCancleShow
        self.buttonCancleTitle = buttonCancleTitle
        self.customCancelAction = customCancelAction
    
        self.showPop = true
        
    }
    
    // 关闭弹窗
    func closePop() {
        self.showPop = false
    }
}
