//
//  TabViewTitle.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/10/13.
//

import SwiftUI

struct TabSelectTitle: View {
    @Binding var tabIndex: Int
    var tabTitles: [String] = []
    var bgColor: Color
    
    // 用于存储每个 tab 的 frame 信息
    @State private var frame:CGRect = .zero
    
    @State private var fatherFrame:CGRect = .zero
    
    @State private var indexOfFrame:[Int:CGRect] = [:]
    
    var body: some View {
        ZStack() {
            GeometryReader { proxy in
                Color.clear
                    .frame(maxWidth:.infinity, alignment: .leading)
                .onAppear() {
                    fatherFrame = proxy.frame(in: .global);
                }
                .onChange(of: proxy.frame(in: .global)) {_,_ in
                    fatherFrame = proxy.frame(in: .global);
                }
            }
            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.theme(.primary).opacity(frame.width <= 0 ? 0 : 1))
                    .frame(width: frame.width)
                    .offset(x: frame.minX <= 0 ? .infinity : frame.minX - fatherFrame.minX)
                    .animation(.spring(duration: 0.3,bounce: 0.2), value: frame)

            }.frame(maxWidth:.infinity, alignment: .leading)
            HStack {
                ForEach(tabTitles.indices, id: \.self) { index in
                    GeometryReader { proxy in
                        Button {
                            frame = proxy.frame(in: .global)
                            tabIndex = index
                        } label: {
                            HStack {
                                Text(tabTitles[index])
                                    .font(.system(size: 14, weight: .medium))
                            }.frame(maxWidth: .infinity, maxHeight: .infinity)
                                .foregroundStyle(tabIndex == index ? .white : Color("text_primary"))
                                .animation(.easeInOut(duration: 0.3), value: tabIndex)
                        }
                        .onAppear() {
                            let frameTemp = proxy.frame(in: .global)
                            indexOfFrame[index] = frameTemp
                        }
                        .onChange(of: proxy.frame(in: .global)) {_,_ in
                            let frameTemp = proxy.frame(in: .global)
                            indexOfFrame[index] = frameTemp
                        }
                    }
                }
            }.frame(maxWidth:.infinity, alignment: .leading)
                .onChange(of: indexOfFrame) { oldValue, newValue in
                    frame = indexOfFrame[tabIndex] ?? .zero
                }
                .onChange(of: tabIndex) { oldValue, newValue in
                    frame = indexOfFrame[tabIndex] ?? .zero
                }
        }.frame(height: 30, alignment: .leading)
         .frame(maxWidth: .infinity)
        .padding(3)
        .background(bgColor)
        .cornerRadius(10)
    }
}

#Preview {
    @Previewable @State var tabIndex = 0
    var tabTitles:[String] = ["当前","趋势","计划"]
    return TabSelectTitle(tabIndex: $tabIndex, tabTitles: tabTitles, bgColor: .gray.opacity(0.1))
}
