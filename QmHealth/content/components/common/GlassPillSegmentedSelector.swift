//
//  GlassPillSegmentedSelector.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/8/31.
//

import SwiftUI

/// 液态玻璃胶囊分段选择器
///
/// 视觉：长椭圆液态玻璃外层 + 主题色小椭圆指示器，激活哪一个，小椭圆就 spring 滑到对应选项位置。
///
/// 实现要点：
/// - 不依赖 `matchedGeometryEffect`（在 iOS 26 glassEffect 环境下不可靠）
/// - 用 background GeometryReader 取宽度，把 segment 宽度存到独立 `@State segmentWidth`
/// - 指示器 x 偏移由独立 `@State indicatorX` 持有
/// - onChange(of: selection) + withAnimation 驱动 indicatorX 更新 → SwiftUI 自然产生 spring 动画
/// - 实色 fallback：先用灰色背景 + 主题色实色 indicator 验证滑动，最后再加 glassEffect
struct GlassPillSegmentedSelector: View {
    @Binding var selection: Int
    var titles: [String]

    /// 小椭圆指示器主题色
    var indicatorTint: Color = AppColor.primary

    /// 长椭圆外层与小椭圆指示器之间的间距（同时控制 segment 之间的间距）
    var inset: CGFloat = 5
    /// 控件整体高度
    var height: CGFloat = 36

    /// 选中态文字色
    var selectedTextColor: Color = .white
    /// 未选中态文字色
    var unselectedTextColor: Color = AppColor.textPrimary

    @State private var segmentWidth: CGFloat = 0
    @State private var indicatorX: CGFloat = 5

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 1. 长椭圆外层（实色 fallback：先用浅灰验证，再换 glassEffect）
            Capsule()
                .fill(Color.clear)
                .frame(maxWidth: .infinity, maxHeight: height)
                .appGlass(.regular, in: Capsule())

            // 2. 小椭圆指示器（实色 fallback：先用主题色实色，再换 glassEffect）
            if segmentWidth > 0 {
                Capsule()
                    .fill(Color.clear)
                    .glassPill(.clear.tint(indicatorTint))
                    .frame(width: segmentWidth, height: height - inset * 2)
                    .offset(x: indicatorX, y: inset)
                    
            }

            // 3. 透明按钮层
            HStack(spacing: inset) {
                ForEach(titles.indices, id: \.self) { idx in
                    Text(titles[idx])
                        .font(.system(size: 14, weight: selection == idx ? .semibold : .medium))
                        .foregroundColor(selection == idx ? selectedTextColor : unselectedTextColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onTapGesture {
                            guard selection != idx else { return }
                            selection = idx
                        }
                }
            }
            .padding(inset)
        }
        .frame(height: height)
        // 用 background GeometryReader 监听宽度，存入 segmentWidth
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { updateLayout(width: proxy.size.width) }
                    .onChange(of: proxy.size.width) { _, newWidth in
                        updateLayout(width: newWidth)
                    }
            }
        )
        // 监听 selection 变化驱动 indicatorX
        .onChange(of: selection) { _, newValue in
            updateIndicatorX(selection: newValue, animated: true)
        }
        .onAppear {
            updateIndicatorX(selection: selection, animated: false)
        }
    }

    private func updateLayout(width: CGFloat) {
        let count = max(titles.count, 1)
        segmentWidth = (width - inset * 2 - inset * CGFloat(count - 1)) / CGFloat(count)
        updateIndicatorX(selection: selection, animated: false)
    }

    private func updateIndicatorX(selection: Int, animated: Bool) {
        let target = inset + CGFloat(selection) * (segmentWidth + inset)
        if animated {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                indicatorX = target
            }
        } else {
            indicatorX = target
        }
    }
}

#Preview("实色 fallback 验证") {
    @Previewable @State var idx = 1
    @Previewable @State var idx1 = 1
    return VStack(spacing: 20) {
        GlassPillSegmentedSelector(selection: $idx, titles: ["全部", "已读", "未读"])
        GlassPillSegmentedSelector(
            selection: $idx1,
            titles: ["今天", "本周", "本月", "全部"]
        )
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
