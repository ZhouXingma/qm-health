//
//  Pop.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/2/24.
//

import SwiftUI
struct Pop<C> : ViewModifier where C:View {
    // 是否需要显示
    @Binding var showState:Bool;
    // 图标
    @Binding var iconEnum:PopIconEnum;
    // 高度
    @Binding var height:CGFloat;
    // 宽度
    @Binding var weight:CGFloat;
    // 显示的内容
    var contentView: C;
    
    
    func body(content: Content) -> some View {
        ZStack {
            content
            if showState {
                VStack {
                    ZStack(alignment:.center) {
                        VStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(LinearGradient(colors: [Color.theme(.secondary).opacity(0.3),Color.theme(.secondary).opacity(0.2), .white], startPoint: .top, endPoint: .bottom))
                                .frame(width: 300, height: 120)
                        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        VStack {
                            Image(iconEnum.iconName())
                                .resizable()
                                .frame(maxWidth: 100, maxHeight: 100)
                            contentView
                                .foregroundStyle(.black)
                        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .offset(y: -30)
                    }
                    .frame(width: weight > 300 ? weight : 300, height: height > 250 ? height : 250, alignment: .top)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.white)
                            .shadow(color: Color.theme(.secondary).opacity(0.05), radius:2, x: -3, y:3)
                    )
                }.frame(maxWidth:.infinity, maxHeight: .infinity, alignment: .center)
                    .background(.ultraThinMaterial)
                    .onTapGesture(perform: {})
            }
        }
            
    }
}

extension View {
    func pop(showState:Binding<Bool>, iconEnum:Binding<PopIconEnum>, height:Binding<CGFloat>, weight:Binding<CGFloat>,
            viewFn: () -> some View) -> some View {
        modifier(Pop(showState: showState,iconEnum: iconEnum, height:height, weight:weight, contentView:viewFn()))
    }
    // 本地弹窗支持
    func withLocalPop(_ popManager: PopManager) -> some View {
        self.modifier(LocalPopModifier(popManager: popManager))
    }
    // 添加全局弹窗支持
    func withGlobalPop() -> some View {
        self.modifier(LocalPopModifier(popManager: PopManager.shared))
    }
}

// 全局弹窗修饰器
struct LocalPopModifier: ViewModifier {
    @ObservedObject var popManager:PopManager
    
    func body(content: Content) -> some View {
        content
            .pop(showState: $popManager.showPop, iconEnum: $popManager.popIcon, height: $popManager.popH, weight: $popManager.popW) {
                VStack {
                    if let customContent = popManager.customContent {
                        customContent
                    } else {
                        defaultPopContent
                    }
                }
            }
    }
    
    private var defaultPopContent: some View {
        VStack {
            Text(popManager.popInfoTitle)
                .font(.system(size: 23, weight: .bold))
                .padding(.bottom, 10)
            Text(popManager.popInfoDes)
                .padding(.bottom, 25)
            HStack {
                if popManager.buttonCancleShow {
                    Button {
                        if let cancel = popManager.customCancelAction {
                            cancel()
                        } else {
                            withAnimation {
                                popManager.showPop.toggle()
                            }
                        }
                    } label: {
                        Text(popManager.buttonCancleTitle)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width:120, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 30)
                                    .fill(.divider)
                            )
                    }
                    
                }
                Button {
                    if let action = popManager.customAction {
                        action()
                    } else {
                        withAnimation {
                            popManager.showPop.toggle()
                        }
                    }
                } label: {
                    Text(popManager.buttonText)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width:120, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 30)
                                .fill(Color.theme(.primary))
                        )
                }
            }
            
        }
    }
}
