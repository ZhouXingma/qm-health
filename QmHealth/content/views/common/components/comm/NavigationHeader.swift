//
//  NavigationHeader.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/3/20.
//

import SwiftUI

struct NavigationHeader<Left: View, Center: View, Right: View>: View {
    private let left: Left
    private let center: Center
    private let right: Right
    private let backgroundColor: Color
    private let horizontalPadding: CGFloat
    private let verticalPadding: CGFloat

    // MARK: - 核心初始化（完全自定义）
    init(
        @ViewBuilder left: () -> Left,
        @ViewBuilder center: () -> Center,
        @ViewBuilder right: () -> Right,
        backgroundColor: Color = Color("background"),
        horizontalPadding: CGFloat = 16,
        verticalPadding: CGFloat = 12
    ) {
        self.left = left()
        self.center = center()
        self.right = right()
        self.backgroundColor = backgroundColor
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }

    // MARK: - 便捷初始化1：仅标题
    init(
        title: String,
        backgroundColor: Color = Color("background"),
        horizontalPadding: CGFloat = 16,
        verticalPadding: CGFloat = 12
    ) where Left == EmptyView, Right == EmptyView, Center == Text {
        self.left = EmptyView()
        self.center = Text(title)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(Color("text_primary"))
        self.right = EmptyView()
        self.backgroundColor = backgroundColor
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }


    var body: some View {
        HStack(alignment: .center) {
            // 左侧内容（左对齐）
            left
                .frame(maxWidth: .infinity, alignment: .leading)
            
            
            // 中间内容（绝对居中）
            center
                .frame(maxWidth: .infinity, alignment: .center)

        
            // 右侧内容（右对齐）
            right
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(alignment: .center)
        .padding(.horizontal, horizontalPadding)
        .padding(.top, verticalPadding)
        .background(backgroundColor)
    }
}

// MARK: - 使用示例
struct NavigationHeader_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // 示例1：完全自定义（与参考代码效果一致）
            NavigationHeader(
                left: { Color.clear.frame(width: 40, height: 40) },
                center: {
                    VStack(spacing: 8) {
                        Text("就诊记录")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color("text_primary"))
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 10)
                                .frame(width: 16, height: 6)
                                .foregroundStyle(Color.theme(.primary))
                            RoundedRectangle(cornerRadius: 10)
                                .frame(width: 8, height: 6)
                                .foregroundStyle(Color("divider"))
                        }
                    }
                },
                right: {
                    Button(action: {}) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.theme(.primary))
                            .frame(width: 40, height: 40)
                            .background(Color("content_bg"))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                    }
                }
            )
        }
        .previewLayout(.sizeThatFits)
    }
}
