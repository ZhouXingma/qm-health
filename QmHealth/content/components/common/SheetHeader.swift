//
//  SheetHeader.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/11/9.
//

import SwiftUI

struct SheetHeader: View {
    // 标题
    var title : String
    // 左侧按钮
    var leftButton: HeaderButtonInfo?
    // 右侧按钮
    var rightButton: HeaderButtonInfo?
    
    var body: some View {
        HStack(alignment: .center) {
            if let lb = leftButton , lb.buttonShow {
                VStack {
                    Button(action: {
                        lb.buttonHandle()
                    }) {
                        Image(systemName: lb.buttonImage)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.theme(.primary))
                            .frame(width: 32, height: 32)
                            .background(Color("content_bg"))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                    }
                }.padding(.top, 10)
            } else {
                Color.clear
                    .frame(width: 32, height: 32)
            }
            Spacer()
            VStack {
                Text("\(title)")
                    .font(.system(size: 18, weight: .bold))
            }.padding(.top, 10)
            Spacer()
            if let rb = rightButton , rb.buttonShow {
                VStack {
                    Button(action: {
                        rb.buttonHandle()
                    }) {
                        Image(systemName: rb.buttonImage)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.theme(.primary))
                            .frame(width: 32, height: 32)
                            .background(Color("content_bg"))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                    }
                }.padding(.top, 10)
            } else {
                Color.clear
                    .frame(width: 32, height: 32)
            }
        }.frame(height: 40, alignment: .center)
            .padding(.horizontal, 20)
       
    }
}

/// 头部按钮信息
class HeaderButtonInfo : ObservableObject {
    // 按钮的图标
    var buttonImage: String;
    // 按钮点击处理
    var buttonHandle: ()->Void;
    // 是否显示按钮
    @Published var buttonShow: Bool
    
    init(buttonImage: String, buttonHandle: @escaping () -> Void, buttonShow: Bool = true) {
        self.buttonImage = buttonImage
        self.buttonHandle = buttonHandle
        self.buttonShow = buttonShow
    }
}

#Preview {
    @Previewable @State var handle = false;
    return SheetHeader(title: "测试图标");
}
