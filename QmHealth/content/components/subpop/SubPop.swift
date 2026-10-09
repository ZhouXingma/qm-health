//
//  SeleteData.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/6/21.
//

import SwiftUI
struct SubPop<C> : ViewModifier where C:View {
    // 是否需要显示
    @Binding var showState:Bool;
    // 高度
    @Binding var height: CGFloat;
    // 显示的内容
    var contentView: C;
    // 确定时间
    var sureAction:(() -> Void)?;
    func body(content: Content) -> some View {
        ZStack {
            content
            if showState {
                VStack {
                    Spacer()
                    VStack(spacing: 10){
                        HStack {
                            Button {
                                closeSuPop();
                            } label: {
                                Image(systemName: "xmark")
                                    .foregroundStyle(Color.theme(.primary))
                            }
                            Spacer()
                            Button {
                                if nil != sureAction {
                                    sureAction!();
                                }
                                closeSuPop();
                            } label: {
                                Text("确认")
                                    .foregroundStyle(Color.theme(.primary))
                            }
                        }
                        VStack {
                            contentView
                        }.frame(maxHeight: .infinity, alignment: .center)
                    }.padding()
                     .frame(height: height)
                     .appGlass(.regular.tint(AppColor.content.opacity(0.5)), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                     .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
                     .animation(.easeInOut(duration: 0.8), value: showState)
                     .offset(y: showState ? 0 : height)
                }.ignoresSafeArea(.all, edges: .bottom)
                    .frame(maxWidth:.infinity, maxHeight: .infinity, alignment: .center)
                    .background(Color.black.opacity(0.6))
                    .onTapGesture {
                        closeSuPop()
                    }
            }
            
        }
    }
    
    func closeSuPop() {
        showState = false
    }
}

extension View {
    func subPop(showState:Binding<Bool>, height: Binding<CGFloat>, sureAction: (()->Void)?, viewFn: () -> some View) -> some View {
        self.modifier(SubPop(showState: showState, height: height, contentView: viewFn(), sureAction: sureAction))
    }
    // 本地弹窗支持
    func withLocalSubPop(_ subPopManager: SubPopManager) -> some View {
        self.modifier(LocalSubPopModifier(subPopManager: subPopManager))
    }
    
    // 添加全局弹窗支持
    func withGlobalSubPop() -> some View {
        self.modifier(LocalSubPopModifier(subPopManager: SubPopManager.shared))
    }
}


// 全局弹窗修饰器
struct LocalSubPopModifier: ViewModifier {
    @ObservedObject private var subPopManager:SubPopManager;
    
    init(subPopManager: SubPopManager) {
        self._subPopManager = ObservedObject(initialValue: subPopManager)
    }
    
    func body(content: Content) -> some View {
        content.subPop(showState: $subPopManager.showSubPop, height: $subPopManager.height, sureAction: subPopManager.customAction) {
            VStack {
                subPopManager.customContent
            }
        }
    }
}

