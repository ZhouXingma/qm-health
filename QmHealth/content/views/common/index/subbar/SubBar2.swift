//
//  SubBar.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/3/2.
//

import SwiftUI

struct SubBar2: View {
    @Binding var currentSelect:Int;
    @Namespace private var namespace
    
    var body: some View {
        VStack {
            GlassEffectContainer(spacing: 20) {
                if currentSelect != 99 {
                    Spacer()
                }
                HStack(alignment: .center) {
                    
                    if currentSelect != 99 {
                        Spacer()
                        HStack(spacing: 10) {
                            SubBarItem2(index: 0, systemName: "house.fill", name: "首页", currentSelect: $currentSelect)
                                .appGlassEffect(.regular.interactive())
                                .glassEffectUnion(id: 1, namespace: namespace)
                                .glassEffectID("main", in: namespace)
                            SubBarItem2(index: 1, systemName: "heart.text.clipboard.fill", name: "就诊", currentSelect: $currentSelect)
                                .appGlassEffect(.regular.interactive())
                                .glassEffectUnion(id: 1, namespace: namespace)
                                .glassEffectID("main1", in: namespace)
                            SubBarItem2(index: 2, systemName: "pill.fill", name: "用药", currentSelect: $currentSelect)
                                .appGlassEffect(.regular.interactive())
                                .glassEffectUnion(id: 1, namespace: namespace)
                                .glassEffectID("main2", in: namespace)
                            SubBarItem2(index: 3, systemName: "person.fill",name: "个人", currentSelect: $currentSelect)
                                .appGlassEffect(.regular.interactive())
                                .glassEffectUnion(id: 1, namespace: namespace)
                                .glassEffectID("main3", in: namespace)
                        }
                        Spacer()
                        VStack {
                            Button {
                                withAnimation {
                                    currentSelect = 99
                                }
                                
                            } label: {
                                HStack {
                                    Text("AI")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(currentSelect == 99 ? Color.white:.secondary)
                                    
                                }.frame(width: 44, height: 44, alignment: .center)
                                    .padding(5)
                            }
                        }.appGlassEffect(.regular.interactive())
                            .glassEffectUnion(id: 2, namespace: namespace)
                        
                    } else {
                        HStack {
                            SubBarItem2Mini(index: 0, systemName: "house.fill", name: "首页", currentSelect: $currentSelect)
                                .appGlassEffect(.regular.interactive())
                                .glassEffectUnion(id: 1, namespace: namespace)
                                .glassEffectID("main", in: namespace)
                        }.padding(.leading, 10)
                    }
                    Spacer()
                }
            }
            if currentSelect == 99 {
                Spacer()
            }
        }
            
            
    }
}

struct SubBarItem2 : View {
    let index:Int;
    let systemName:String;
    let name:String;
    @Binding var currentSelect:Int;
    @Namespace private var namespace
    var body: some View {
        VStack {
            Image(systemName: systemName)
                .font(.system(size: 20))
                .padding(.bottom, 1)
                .foregroundStyle(currentSelect == index ? Color.theme(.primary):.secondary)
//            Text(name)
//                .font(.system(size: 10))
//                .foregroundStyle(currentSelect == index ? Color.theme(.primary):.secondary)
        }
        .frame(minWidth: 44, minHeight: 44)
        .padding(5)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                currentSelect = index;
            }
        }
    }
}

struct SubBarItem2Mini : View {
    let index:Int;
    let systemName:String;
    let name:String;
    @Binding var currentSelect:Int;
    @Namespace private var namespace
    var body: some View {
        VStack {
            Image(systemName: systemName)
                .font(.system(size: 18))
                .padding(.bottom, 1)
                .foregroundStyle(currentSelect == index ? Color.theme(.primary):.secondary)
//            Text(name)
//                .font(.system(size: 10))
//                .foregroundStyle(currentSelect == index ? Color.theme(.primary):.secondary)
        }
        .frame(minWidth: 30, minHeight: 30)
        .padding(5)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                currentSelect = index;
            }
        }
    }
}

