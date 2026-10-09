import SwiftUI

// MARK: - 医疗温柔弥散背景（增强可见度）
struct DiffuseBackground1: View {
    @Binding var color1: Color
    @Binding var color2: Color
    @Binding var color3: Color
    @Binding var speed: Double
    
    @Environment(\.colorScheme) var colorScheme
    
    @State private var time: CGFloat = 0
    let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            let centerX = width / 2
            let centerY = height / 2
            
            // 大幅提高透明度，让效果更明显
            let baseOpacity: CGFloat = colorScheme == .dark ? 1.0 : 0.7
            
            // 转换颜色
            let c1 = UIColor(color1).cgColor
            let c2 = UIColor(color2).cgColor
            let c3 = UIColor(color3).cgColor
            
            // 1. 大型旋转色块
            drawLargeRotatingBlocks(context: &context, size: size, centerX: centerX, centerY: centerY,
                                   c1: c1, c2: c2, c3: c3, time: time, baseOpacity: baseOpacity)
            
            // 2. 强烈脉动光晕
            drawStrongPulsingGlows(context: &context, size: size, centerX: centerX, centerY: centerY,
                                  c1: c1, c2: c2, c3: c3, time: time, baseOpacity: baseOpacity)
            
            // 3. 旋转的彩色圆环
            drawRotatingRings(context: &context, size: size, centerX: centerX, centerY: centerY,
                             c1: c1, c2: c2, c3: c3, time: time, baseOpacity: baseOpacity)
            
            // 4. 流动的彩色光柱
            drawLightColumns(context: &context, size: size,
                            c1: c1, c2: c2, c3: c3, time: time, baseOpacity: baseOpacity)
            
            // 5. 旋转的星形
            drawRotatingStars(context: &context, size: size, centerX: centerX, centerY: centerY,
                             c1: c1, c2: c2, c3: c3, time: time, baseOpacity: baseOpacity)
        }
        .onReceive(timer) { _ in
            withAnimation(.linear(duration: 0.016)) {
                time += 0.016 * CGFloat(speed)
            }
        }
        .background(
            colorScheme == .dark ?
            Color(white: 0.02) :
            Color(white: 0.98)
        )
        .ignoresSafeArea()
    }
    
    // MARK: - 大型旋转色块
    private func drawLargeRotatingBlocks(context: inout GraphicsContext, size: CGSize,
                                         centerX: CGFloat, centerY: CGFloat,
                                         c1: CGColor, c2: CGColor, c3: CGColor,
                                         time: CGFloat, baseOpacity: CGFloat) {
        let blockCount = 6
        
        for i in 0..<blockCount {
            let angle = time * 0.1 + CGFloat(i) * .pi / 3
            let radius: CGFloat = 200 + 100 * sin(time * 0.08 + CGFloat(i) * 1.1)
            
            let x = centerX + radius * cos(angle + time * 0.06)
            let y = centerY + radius * 0.5 * sin(angle * 0.8 + time * 0.07)
            
            let size2: CGFloat = 80 + 60 * sin(time * 0.12 + CGFloat(i) * 1.3)
            let rotation = angle + time * 0.1
            
            let colors = [c1, c2, c3]
            let color = colors[i % 3]
            let opacity = (0.25 + 0.15 * (0.5 + 0.5 * sin(time * 0.06 + CGFloat(i)))) * baseOpacity
            
            // 绘制大型圆角矩形
            var rect = Path(roundedRect: CGRect(x: -size2/2, y: -size2/2,
                                               width: size2, height: size2),
                           cornerRadius: size2 * 0.3)
            
            let transform = CGAffineTransform(translationX: x, y: y)
                .rotated(by: rotation)
            rect = rect.applying(transform)
            
            // 填充和边框
            context.opacity = opacity
            context.fill(rect, with: .color(Color(color).opacity(opacity)))
            
            // 边框
            context.opacity = opacity * 0.8
            context.stroke(rect, with: .color(Color(color).opacity(opacity * 0.8)), lineWidth: 2)
        }
    }
    
    // MARK: - 强烈脉动光晕
    private func drawStrongPulsingGlows(context: inout GraphicsContext, size: CGSize,
                                        centerX: CGFloat, centerY: CGFloat,
                                        c1: CGColor, c2: CGColor, c3: CGColor,
                                        time: CGFloat, baseOpacity: CGFloat) {
        let glows: [(CGFloat, CGFloat, CGFloat, CGColor)] = [
            (centerX - 200, centerY - 150, 280, c1),
            (centerX + 180, centerY + 130, 260, c2),
            (centerX - 150, centerY + 200, 250, c3),
            (centerX + 220, centerY - 180, 240, c1),
            (centerX - 250, centerY + 160, 230, c2),
            (centerX + 100, centerY - 220, 220, c3)
        ]
        
        for (index, (x, y, baseRadius, color)) in glows.enumerated() {
            // 强烈脉动
            let pulse = 0.5 + 0.5 * sin(time * 0.2 + CGFloat(index) * 1.5)
            let radius = baseRadius * (0.7 + 0.3 * pulse)
            let opacity = (0.15 + 0.1 * pulse) * baseOpacity
            
            // 多层光晕
            for layer in 0..<5 {
                let scale = 1.0 - CGFloat(layer) * 0.15
                let r = radius * scale
                let op = opacity * (0.8 - CGFloat(layer) * 0.12)
                
                let path = Path(ellipseIn: CGRect(x: x - r, y: y - r,
                                                 width: r * 2, height: r * 2))
                
                let gradientColors: [Color] = [
                    Color(color).opacity(op),
                    Color(color).opacity(op * 0.3),
                    Color.clear
                ]
                let gradient = Gradient(colors: gradientColors)
                context.fill(path, with: .radialGradient(gradient,
                                                        center: CGPoint(x: x, y: y),
                                                        startRadius: 0,
                                                        endRadius: r))
            }
        }
    }
    
    // MARK: - 旋转的彩色圆环
    private func drawRotatingRings(context: inout GraphicsContext, size: CGSize,
                                   centerX: CGFloat, centerY: CGFloat,
                                   c1: CGColor, c2: CGColor, c3: CGColor,
                                   time: CGFloat, baseOpacity: CGFloat) {
        let ringCount = 8
        
        for i in 0..<ringCount {
            let angle = time * 0.08 + CGFloat(i) * .pi / 4
            let radius: CGFloat = 120 + 80 * sin(time * 0.1 + CGFloat(i) * 0.9)
            let orbitRadius: CGFloat = 180 + 80 * sin(time * 0.06 + CGFloat(i) * 1.1)
            
            let x = centerX + orbitRadius * cos(angle + time * 0.05)
            let y = centerY + orbitRadius * 0.5 * sin(angle * 0.7 + time * 0.06)
            
            let colors = [c1, c2, c3]
            let color = colors[i % 3]
            let opacity = (0.12 + 0.08 * (0.5 + 0.5 * sin(time * 0.07 + CGFloat(i)))) * baseOpacity
            
            // 绘制圆环
            let ringPath = Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                                 width: radius * 2, height: radius * 2))
            
            context.opacity = opacity
            context.stroke(ringPath, with: .color(Color(color).opacity(opacity)), lineWidth: 3)
            
            // 外发光
            context.opacity = opacity * 0.3
            context.stroke(ringPath, with: .color(Color(color).opacity(opacity * 0.3)), lineWidth: 8)
            
            // 环上的光点
            let dotCount = 8
            for j in 0..<dotCount {
                let dotAngle = CGFloat(j) / CGFloat(dotCount) * .pi * 2 + time * 0.08 + CGFloat(i) * 0.2
                let dotX = x + radius * cos(dotAngle)
                let dotY = y + radius * sin(dotAngle)
                let dotSize: CGFloat = 4 + 3 * sin(time * 0.15 + CGFloat(i) + CGFloat(j))
                
                let dotPath = Path(ellipseIn: CGRect(x: dotX - dotSize/2,
                                                    y: dotY - dotSize/2,
                                                    width: dotSize,
                                                    height: dotSize))
                context.opacity = opacity * 2
                context.fill(dotPath, with: .color(Color(color).opacity(opacity * 2)))
            }
        }
    }
    
    // MARK: - 流动的彩色光柱
    private func drawLightColumns(context: inout GraphicsContext, size: CGSize,
                                  c1: CGColor, c2: CGColor, c3: CGColor,
                                  time: CGFloat, baseOpacity: CGFloat) {
        let columnCount = 8
        
        for i in 0..<columnCount {
            let progress = (time * 0.05 + CGFloat(i) / CGFloat(columnCount)).truncatingRemainder(dividingBy: 1.0)
            let x = progress * size.width
            
            let height: CGFloat = 200 + 150 * sin(time * 0.08 + CGFloat(i) * 1.2)
            let y = size.height / 2 - height/2 + 50 * sin(time * 0.06 + CGFloat(i) * 0.8)
            let width: CGFloat = 20 + 15 * sin(time * 0.1 + CGFloat(i) * 1.4)
            
            let colors = [c1, c2, c3]
            let color = colors[i % 3]
            let opacity = (0.08 + 0.06 * (0.5 + 0.5 * sin(time * 0.05 + CGFloat(i)))) * baseOpacity
            
            // 绘制光柱
            let rect = CGRect(x: x - width/2, y: y, width: width, height: height)
            let path = Path(roundedRect: rect, cornerRadius: width/2)
            
            // 渐变填充
            let gradientColors: [Color] = [
                Color(color).opacity(opacity),
                Color(color).opacity(opacity * 0.3),
                Color(color).opacity(opacity)
            ]
            let gradient = Gradient(colors: gradientColors)
            context.fill(path, with: .linearGradient(gradient,
                                                    startPoint: CGPoint(x: x, y: y),
                                                    endPoint: CGPoint(x: x, y: y + height)))
            
            // 发光效果
            context.opacity = opacity * 0.2
            let glowRect = CGRect(x: x - width, y: y - 20, width: width * 2, height: height + 40)
            let glowPath = Path(roundedRect: glowRect, cornerRadius: width)
            context.fill(glowPath, with: .color(Color(color).opacity(opacity * 0.2)))
        }
    }
    
    // MARK: - 旋转的星形
    private func drawRotatingStars(context: inout GraphicsContext, size: CGSize,
                                   centerX: CGFloat, centerY: CGFloat,
                                   c1: CGColor, c2: CGColor, c3: CGColor,
                                   time: CGFloat, baseOpacity: CGFloat) {
        let starCount = 10
        
        for i in 0..<starCount {
            let angle = time * 0.09 + CGFloat(i) * .pi * 2 / CGFloat(starCount)
            let radius: CGFloat = 160 + 100 * sin(time * 0.07 + CGFloat(i) * 0.9)
            
            let x = centerX + radius * cos(angle + time * 0.04)
            let y = centerY + radius * 0.5 * sin(angle * 0.6 + time * 0.05)
            
            let starSize: CGFloat = 15 + 20 * sin(time * 0.15 + CGFloat(i) * 1.2)
            let rotation = angle + time * 0.12
            
            let colors = [c1, c2, c3]
            let color = colors[i % 3]
            let opacity = (0.15 + 0.1 * (0.5 + 0.5 * sin(time * 0.08 + CGFloat(i)))) * baseOpacity
            
            // 绘制星形
            var path = Path()
            let points = 5
            let outerRadius = starSize
            let innerRadius = starSize * 0.4
            
            for j in 0..<points * 2 {
                let angle2 = CGFloat(j) / CGFloat(points * 2) * .pi * 2 - .pi / 2
                let r = j % 2 == 0 ? outerRadius : innerRadius
                let px = r * cos(angle2)
                let py = r * sin(angle2)
                
                if j == 0 {
                    path.move(to: CGPoint(x: px, y: py))
                } else {
                    path.addLine(to: CGPoint(x: px, y: py))
                }
            }
            path.closeSubpath()
            
            let transform = CGAffineTransform(translationX: x, y: y)
                .rotated(by: rotation)
            path = path.applying(transform)
            
            // 填充和边框
            context.opacity = opacity
            context.fill(path, with: .color(Color(color).opacity(opacity)))
            
            // 发光边框
            context.opacity = opacity * 0.6
            context.stroke(path, with: .color(Color(color).opacity(opacity * 0.6)), lineWidth: 1.5)
            
            // 光芒
            let glowPath = Path(ellipseIn: CGRect(x: x - starSize, y: y - starSize,
                                                 width: starSize * 2, height: starSize * 2))
            context.opacity = opacity * 0.2
            context.fill(glowPath, with: .color(Color(color).opacity(opacity * 0.2)))
        }
    }
}

// MARK: - 调试面板
struct DiffuseBackgroundDebugPanel2: View {
    @Binding var color1: Color
    @Binding var color2: Color
    @Binding var color3: Color
    @Binding var speed: Double
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.spring()) { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "paintpalette.fill")
                        .foregroundStyle(.white.opacity(0.9))
                    Text("背景控制")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.white.opacity(0.7))
                        .font(.caption)
                }
                .padding()
            }
            
            if isExpanded {
                VStack(spacing: 20) {
                    HStack(spacing: 25) {
                        ColorPickerButton2(color: $color1, label: "主色", defaultColor: Color(red: 0.4, green: 0.7, blue: 0.9))
                        ColorPickerButton2(color: $color2, label: "辅色", defaultColor: Color(red: 0.7, green: 0.5, blue: 0.9))
                        ColorPickerButton2(color: $color3, label: "点缀", defaultColor: Color(red: 0.3, green: 0.8, blue: 0.6))
                    }
                    
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "speedometer")
                                .foregroundStyle(.white.opacity(0.7))
                            Text("动画速度")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                            Spacer()
                            Text("\(speed, specifier: "%.1f")x")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 35)
                        }
                        Slider(value: $speed, in: 0.0...2.0, step: 0.1)
                            .tint(.white.opacity(0.6))
                    }
                    
                    HStack(spacing: 12) {
                        PresetButton2(label: "医疗蓝",
                                    colors: (Color(red: 0.4, green: 0.7, blue: 0.9),
                                            Color(red: 0.6, green: 0.5, blue: 0.9),
                                            Color(red: 0.3, green: 0.8, blue: 0.6)))
                        PresetButton2(label: "温柔粉",
                                    colors: (Color(red: 0.9, green: 0.6, blue: 0.6),
                                            Color(red: 0.8, green: 0.5, blue: 0.7),
                                            Color(red: 0.6, green: 0.8, blue: 0.8)))
                        PresetButton2(label: "自然绿",
                                    colors: (Color(red: 0.4, green: 0.8, blue: 0.5),
                                            Color(red: 0.6, green: 0.7, blue: 0.3),
                                            Color(red: 0.3, green: 0.7, blue: 0.7)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 5)
        .padding(.horizontal, 20)
    }
}

struct ColorPickerButton2: View {
    @Binding var color: Color
    let label: String
    let defaultColor: Color
    
    let presetColors: [(Color, String)] = [
        (Color(red: 0.4, green: 0.7, blue: 0.9), "蓝"),
        (Color(red: 0.7, green: 0.5, blue: 0.9), "紫"),
        (Color(red: 0.3, green: 0.8, blue: 0.6), "绿"),
        (Color(red: 0.9, green: 0.6, blue: 0.6), "粉"),
        (Color(red: 0.6, green: 0.8, blue: 0.8), "青"),
        (Color(red: 0.9, green: 0.7, blue: 0.5), "橙")
    ]
    
    var body: some View {
        VStack(spacing: 6) {
            Menu {
                ForEach(presetColors, id: \.0) { preset in
                    Button {
                        color = preset.0
                    } label: {
                        HStack {
                            Circle().fill(preset.0).frame(width: 16, height: 16)
                            Text(preset.1)
                        }
                    }
                }
                Button {
                    color = defaultColor
                } label: {
                    HStack {
                        Circle().fill(defaultColor).frame(width: 16, height: 16)
                        Text("重置")
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 36, height: 36)
                        .shadow(color: color.opacity(0.6), radius: 15)
                    
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 36, height: 36)
                }
            }
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

struct PresetButton2: View {
    let label: String
    let colors: (Color, Color, Color)
    
    var body: some View {
        Button {
            NotificationCenter.default.post(name: NSNotification.Name("UpdateColors"),
                                           object: nil,
                                           userInfo: ["color1": colors.0,
                                                     "color2": colors.1,
                                                     "color3": colors.2])
        } label: {
            HStack(spacing: 4) {
                Circle().fill(colors.0).frame(width: 12, height: 12)
                Circle().fill(colors.1).frame(width: 12, height: 12)
                Circle().fill(colors.2).frame(width: 12, height: 12)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.white.opacity(0.15), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
            )
        }
    }
}

// MARK: - 演示视图
struct DiffuseBackground1Demo: View {
    @State private var color1: Color = Color(red: 0.4, green: 0.7, blue: 0.9)
    @State private var color2: Color = Color(red: 0.7, green: 0.5, blue: 0.9)
    @State private var color3: Color = Color(red: 0.3, green: 0.8, blue: 0.6)
    @State private var speed: Double = 1.0
    
    var body: some View {
        ZStack {
            DiffuseBackground1(color1: $color1,
                               color2: $color2,
                               color3: $color3,
                               speed: $speed)
            
            VStack {
                Spacer()
                
                DiffuseBackgroundDebugPanel2(color1: $color1,
                                           color2: $color2,
                                           color3: $color3,
                                           speed: $speed)
                .padding(.bottom, 30)
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UpdateColors"))) { notification in
            if let userInfo = notification.userInfo {
                color1 = userInfo["color1"] as? Color ?? color1
                color2 = userInfo["color2"] as? Color ?? color2
                color3 = userInfo["color3"] as? Color ?? color3
            }
        }
    }
}

// MARK: - 预览
#Preview {
    DiffuseBackground1Demo()
}
