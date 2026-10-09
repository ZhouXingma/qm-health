import SwiftUI

// MARK: - 弥散背景视图
struct DiffuseBackground: View {
    // 可调节参数
    @Binding var color1: Color
    @Binding var color2: Color
    @Binding var color3: Color
    @Binding var speed: Double
    
    @State private var time: CGFloat = 0
    let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            
            // 将颜色转换为CGColor
            let c1 = UIColor(color1).cgColor
            let c2 = UIColor(color2).cgColor
            let c3 = UIColor(color3).cgColor
            
            // 绘制多个弥散圆形
            for i in 0..<8 {
                // 分解复杂表达式，避免类型检查超时
                let angleBase = CGFloat(i) * .pi / 4
                let angleOffset = time * 0.3
                let angle = angleBase + angleOffset
                
                let radiusBase: CGFloat = 120
                let radiusVar: CGFloat = 40 * sin(time * 0.5 + CGFloat(i))
                let radius = radiusBase + radiusVar
                
                let centerXBase: CGFloat = width / 2
                let centerXOffset: CGFloat = 180 * cos(angle + time * 0.2)
                let centerX = centerXBase + centerXOffset
                
                let centerYBase: CGFloat = height / 2
                let centerYOffset: CGFloat = 120 * sin(angle * 0.8 + time * 0.25)
                let centerY = centerYBase + centerYOffset
                
                // 根据索引选择颜色
                let color: CGColor
                let opacityBase: CGFloat
                if i % 3 == 0 {
                    color = c1
                    opacityBase = 0.6 + 0.15 * sin(time + CGFloat(i))
                } else if i % 3 == 1 {
                    color = c2
                    opacityBase = 0.5 + 0.2 * cos(time * 0.7 + CGFloat(i))
                } else {
                    color = c3
                    opacityBase = 0.55 + 0.15 * sin(time * 0.9 + CGFloat(i) * 1.2)
                }
                
                let endRadiusBase: CGFloat = radius * 0.8
                let endRadiusVar: CGFloat = radius * 0.2 * sin(time * 0.4 + CGFloat(i) * 0.7)
                let endRadius = endRadiusBase + endRadiusVar
                
                let blurAmount: CGFloat = 25 + 10 * sin(time * 0.3 + CGFloat(i))
                
                // 绘制多个叠加圆产生弥散效果
                for j in 0..<4 {
                    let scale = 1.0 - CGFloat(j) * 0.2
                    let r = endRadius * scale
                    
                    let opacityVar = 0.1 * sin(time + CGFloat(i) * 2 + CGFloat(j))
                    let opacity = (0.4 - CGFloat(j) * 0.08) * (0.9 + opacityVar)
                    
                    let offsetX = 15 * sin(time * 0.5 + CGFloat(i) * 1.3 + CGFloat(j) * 2)
                    let offsetY = 15 * cos(time * 0.4 + CGFloat(i) * 0.9 + CGFloat(j) * 1.7)
                    
                    let circleX = centerX + offsetX - r
                    let circleY = centerY + offsetY - r
                    let circleWidth = r * 2
                    let circleHeight = r * 2
                    
                    let circle = Path(ellipseIn: CGRect(x: circleX,
                                                        y: circleY,
                                                        width: circleWidth,
                                                        height: circleHeight))
                    
                    var contextCopy = context
                    contextCopy.opacity = opacity
                    contextCopy.fill(circle, with: .color(Color(color).opacity(opacity)))
                }
            }
            
            // 添加一些小的装饰光点 - 分解表达式
            for i in 0..<12 {
                let angleBase = CGFloat(i) * .pi / 6
                let angleOffset = time * 0.15
                let angle = angleBase + angleOffset
                
                let distBase: CGFloat = 80
                let distVar: CGFloat = 50 * sin(time * 0.3 + CGFloat(i) * 1.1)
                let dist = distBase + distVar
                
                let xBase = width / 2
                let xOffset = 220 * cos(angle + time * 0.1)
                let x = xBase + xOffset
                
                let yBase = height / 2
                let yOffset = 180 * sin(angle * 0.7 + time * 0.15)
                let y = yBase + yOffset
                
                let rBase: CGFloat = 8
                let rVar: CGFloat = 6 * sin(time * 0.6 + CGFloat(i) * 0.9)
                let r = rBase + rVar
                
                let color = i % 3 == 0 ? c1 : (i % 3 == 1 ? c2 : c3)
                let opacityBase: CGFloat = 0.2
                let opacityVar: CGFloat = 0.1 * sin(time * 0.8 + CGFloat(i) * 0.5)
                let opacity = opacityBase + opacityVar
                
                let dotX = x - r
                let dotY = y - r
                let dotWidth = r * 2
                let dotHeight = r * 2
                
                let dot = Path(ellipseIn: CGRect(x: dotX,
                                                 y: dotY,
                                                 width: dotWidth,
                                                 height: dotHeight))
                
                var contextCopy = context
                contextCopy.opacity = opacity
                contextCopy.fill(dot, with: .color(Color(color).opacity(opacity)))
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.linear(duration: 0.02)) {
                time += 0.02 * speed
            }
        }
        .background(Color.black.opacity(0.1))
        .ignoresSafeArea()
    }
}

// MARK: - 演示视图（避免与现有ContentView冲突）
struct DiffuseBackgroundDemo: View {
    @State private var color1: Color = .blue
    @State private var color2: Color = .purple
    @State private var color3: Color = .pink
    @State private var speed: Double = 1.0
    
    var body: some View {
        ZStack {
            // 弥散背景
            DiffuseBackground(color1: $color1,
                              color2: $color2,
                              color3: $color3,
                              speed: $speed)
            
            // 液态玻璃卡片
            DiffuseGlassCard(color1: $color1,
                           color2: $color2,
                           color3: $color3,
                           speed: $speed)
                .padding(.horizontal, 30)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - 液态玻璃卡片（接收绑定参数）
struct DiffuseGlassCard: View {
    @Binding var color1: Color
    @Binding var color2: Color
    @Binding var color3: Color
    @Binding var speed: Double
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "drop.fill")
                .font(.system(size: 50))
                .foregroundStyle(.white.opacity(0.8))
            
            Text("液态玻璃")
                .font(.title.bold())
                .foregroundStyle(.white)
            
            Text("弥散背景 + 玻璃效果")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            
            Divider()
                .background(.white.opacity(0.3))
            
            HStack(spacing: 30) {
                DiffuseColorControl(color: $color1, label: "蓝")
                DiffuseColorControl(color: $color2, label: "紫")
                DiffuseColorControl(color: $color3, label: "粉")
            }
            
            HStack {
                Text("速度")
                    .foregroundStyle(.white.opacity(0.8))
                Slider(value: $speed, in: 0.0...2.0, step: 0.1)
                    .tint(.white.opacity(0.6))
                Text("\(speed, specifier: "%.1f")x")
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 35)
            }
        }
        .padding(30)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: 10)
    }
}

// MARK: - 颜色控制按钮
struct DiffuseColorControl: View {
    @Binding var color: Color
    let label: String
    
    let colors: [Color] = [.blue, .purple, .pink, .red, .orange, .yellow, .green, .teal, .indigo]
    
    var body: some View {
        VStack {
            Menu {
                ForEach(colors, id: \.self) { c in
                    Button {
                        color = c
                    } label: {
                        HStack {
                            Circle().fill(c).frame(width: 20, height: 20)
                            Text(diffuseColorName(c))
                        }
                    }
                }
            } label: {
                Circle()
                    .fill(color)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.3), lineWidth: 2)
                    )
                    .shadow(color: color.opacity(0.5), radius: 8)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
    
    // 辅助函数：获取颜色名称
    private func diffuseColorName(_ color: Color) -> String {
        switch color {
        case .blue: return "蓝色"
        case .purple: return "紫色"
        case .pink: return "粉色"
        case .red: return "红色"
        case .orange: return "橙色"
        case .yellow: return "黄色"
        case .green: return "绿色"
        case .teal: return "青色"
        case .indigo: return "靛蓝"
        default: return "自定义"
        }
    }
}

// MARK: - 预览
#Preview {
    DiffuseBackgroundDemo().preferredColorScheme(.light)
}
