//
//  Loading.swift
//  test_ios26
//
//  Created by 周荥马 on 2026/2/12.
//

import SwiftUI

import SwiftUI

/// 一个AI正在思考/输出的动态波形指示器
/// - 每个波形条都有独立的波动频率和相位，避免同步僵硬
/// - 采用渐变填充+双重阴影，营造深邃的光感
/// - 流畅的60fps更新，无跳帧感
struct ThinkingWaveIndicator: View {
    // MARK: - 可定制属性
    var barCount: Int = 6               // 波形条数量
    var color: Color = .blue           // 主色调
    var baseHeight: CGFloat = 10       // 最小高度
    var waveRange: CGFloat = 24        // 波动幅度
    var barWidth: CGFloat = 6          // 条宽
    var spacing: CGFloat = 5          // 条间距
    var speed: Double = 2.2           // 基础波动速度
    var frequencyVariation: Double = 0.25 // 频率差异度（避免所有条完全同步）
    
    var body: some View {
        // TimelineView 依托屏幕刷新率更新，保证动画极致顺滑
        TimelineView(.animation) { context in
            HStack(spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    let height = waveHeight(for: context.date, index: index)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    color.opacity(0.7),
                                    color,
                                    color.opacity(0.9)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: barWidth, height: height)
                        // 外发光：柔和的主色光晕
                        .shadow(color: color.opacity(0.5), radius: 4, x: 0, y: 2)
                        // 内凹高光：增强立体感
                        .shadow(color: .white.opacity(0.3), radius: 1, x: 0, y: -1)
                        // 轻微的背景光晕叠加
                        .overlay(
                            Capsule()
                                .stroke(color.opacity(0.5), lineWidth: 0.8)
                                .blur(radius: 0.8)
                        )
                }
            }
            // 整体背景柔光，让波形更突出
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }
    
    // MARK: - 波形高度算法
    // 使用正弦函数 + 独立频率/相位，产生自然错落的跳动感
    private func waveHeight(for date: Date, index: Int) -> CGFloat {
        // 每个条都有自己的频率微调，避免“整体波动”的机械感
        let frequency = speed + (Double(index) * frequencyVariation)
        // 相位差让波形条不同时到达波峰/波谷
        let phase = Double(index) * 1.6
        // 时间因子，连续变化
        let t = date.timeIntervalSince1970 * frequency + phase
        // 将 sin 输出 [-1, 1] 映射到 [0, 1]
        let normalized = (sin(t) + 1) / 2
        // 实际高度 = 基础高度 + 振幅 * 归一化值
        return baseHeight + waveRange * CGFloat(normalized)
    }
}


#Preview {
    ZStack {
        // 深邃背景，更能凸显发光特效
        Color.black
            .ignoresSafeArea()
        
        VStack(spacing: 40) {
            // 经典蓝调
            ThinkingWaveIndicator(color: .cyan)
                .frame(width: 200)
            
            // 暖橙色，适合思考/创作场景
            ThinkingWaveIndicator(
                color: .orange,
                baseHeight: 12,
                waveRange: 28,
                barWidth: 7,
                speed: 1.8
            )
            .frame(width: 220)
            
            // 极光紫，带更强的频率差异
            ThinkingWaveIndicator(
                color: .purple,
                baseHeight: 8,
                waveRange: 22,
                barWidth: 5,
                speed: 2.5,
                frequencyVariation: 0.4
            )
            .frame(width: 180)
        }
    }
}
