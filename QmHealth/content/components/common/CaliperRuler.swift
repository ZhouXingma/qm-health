//
//  CaliperRuler.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/11/14.
//

import SwiftUI

// MARK: - 纯卡尺组件（只有尺子，不包含数值显示）
struct CaliperRuler: View {
    // 尺的值
    @Binding var value: Double
    // 最小值
    let minValue: Double
    // 最大值
    let maxValue: Double
    // 步宽
    let step: Double
    // 多少刻度为大刻度
    let majorTickInterval: Int
    
    // 普通刻度高度
    private let tickHeight: CGFloat = 20
    // 最大刻度高度
    private let majorTickHeight: CGFloat = 35
    // 刻度之间的距离
    private let tickSpacing: CGFloat = 10
    // 距离大小
    @State private var dragOffset: CGFloat = 0
    // 最新的值
    @State private var lastValue: Double
    // 是否在拖动
    @State private var isDragging: Bool = false
    // 拖动反馈
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    
    init(value: Binding<Double>,
         minValue: Double,
         maxValue: Double,
         step: Double,
         majorTickInterval: Int = 10) {
        self._value = value
        self.minValue = minValue
        self.maxValue = maxValue
        self.step = step
        self.majorTickInterval = majorTickInterval
        self._lastValue = State(initialValue: value.wrappedValue)
    }
    
    var body: some View {
        ZStack {
            // 背景辉光效果
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .blue.opacity(isDragging ? 0.3 : 0.15),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)
                .blur(radius: 20)
                .animation(.easeInOut(duration: 0.3), value: isDragging)
            
            // 中心指示器
            VStack(spacing: 0) {
                Triangle()
                    .fill(
                        LinearGradient(
                            colors: [.red, .orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 20, height: 15)
                    .shadow(color: .red.opacity(0.5), radius: isDragging ? 8 : 4)
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.red, .orange.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3, height: 65)
                    .shadow(color: .red.opacity(0.5), radius: isDragging ? 8 : 4)
            }
            .scaleEffect(isDragging ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
            .zIndex(1)
            
            // 可滚动的刻度尺
            GeometryReader { geometry in
                let width = geometry.size.width
                let centerOffset = width / 2
                
                Canvas { context, size in
                    let totalSteps = Int((maxValue - minValue) / step)
                    
                    // 计算当前值对应的偏移量
                    let baseValueOffset = CGFloat((lastValue - minValue) / step) * tickSpacing
                    let offset = centerOffset - baseValueOffset + dragOffset
                    
                    for i in 0...totalSteps {
                        let x = offset + CGFloat(i) * tickSpacing
                        
                        if x >= -50 && x <= size.width + 50 {
                            let isMajorTick = i % majorTickInterval == 0
                            let height = isMajorTick ? majorTickHeight : tickHeight
                            
                            let distanceFromCenter = abs(x - centerOffset)
                            let maxDistance = size.width / 2
                            let opacity = max(0.3, 1 - (distanceFromCenter / maxDistance) * 0.7)
                            
                            let path = Path { p in
                                p.move(to: CGPoint(x: x, y: size.height))
                                p.addLine(to: CGPoint(x: x, y: size.height - height))
                            }
                            
                            let isNearCenter = distanceFromCenter < 30
                            let tickColor = isNearCenter ? Color.blue : (isMajorTick ? Color.primary : Color.secondary)
                            
                            context.stroke(
                                path,
                                with: .color(tickColor.opacity(opacity)),
                                lineWidth: isMajorTick ? 2.5 : 1.5
                            )
                            
                            if isMajorTick {
                                let tickValue = minValue + Double(i) * step
                                let text = Text("\(Int(tickValue))")
                                    .font(.system(size: 13, weight: isNearCenter ? .bold : .medium))
                                    .foregroundColor(isNearCenter ? .blue : .primary)
                                
                                context.draw(
                                    text,
                                    at: CGPoint(x: x, y: size.height - height - 18)
                                )
                            }
                        }
                    }
                }
                .frame(height: 90)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            if !isDragging {
                                isDragging = true
                                hapticFeedback.prepare()
                            }
                            // 拖动的距离
                            dragOffset = gesture.translation.width
                            // 拖动改变大小
                            let offsetChange = -dragOffset / tickSpacing
                            // 值计算
                            var newValue = lastValue + offsetChange * step
                            // 最新的值
                            newValue = min(max(newValue, minValue), maxValue)
                            let roundedValue = round(newValue / step) * step
                            
                            if roundedValue != value {
                                hapticFeedback.impactOccurred()
                            }
                            
                            value = roundedValue
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                lastValue = value
                                dragOffset = 0
                                isDragging = false
                            }
                        }
                )
            }
            .frame(height: 90)
        }
        .padding(.horizontal)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemGray6),
                            Color(.systemGray5)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        .blur(radius: 1)
                        .offset(y: -1)
                )
        )
        .onChange(of: value) { oldValue, newValue in
            // 当外部修改value时，更新lastValue以保持同步
            if !isDragging {
                lastValue = newValue
            }
        }
    }
}


// MARK: - 三角形形状
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}



#Preview {
    @Previewable @State var temperature: Double = 36.5;
    return CaliperRuler(
        value: $temperature,
        minValue: 35,
        maxValue: 42,
        step: 0.1,
        majorTickInterval: 5
    );
}
