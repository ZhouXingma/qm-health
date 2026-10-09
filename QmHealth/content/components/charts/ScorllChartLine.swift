import SwiftUI

// MARK: - 数据模型
public struct ScrollChartDataPoint: Identifiable,Equatable {
    public let id = UUID()
    public let label: String
    public let value: Double
}

// MARK: - 图表样式配置
public struct ScrollChartStyle {
    var lineColor: [Color] = [.red, .purple]
    var lineWidth: CGFloat = 3
    var gradientColors: [Color] = [.red.opacity(0.3), .red.opacity(0.05)]
    var pointColor: Color = .red
    var pointBackgroundColor: Color = .white
    var animationDuration: Double = 1.5
    var showXAxis = true
    var showYAxis = true
    var showGradient = true
    var xAxisMinSpace: Double = 50
    var xAxisHeight: CGFloat = 20
    var yAxisSep:Int = 5
    var smoothness:CGFloat =  0.5
    var showPointCircle: Bool = false
    var showYLines = false
    var maxValue: Double? = nil
    var minValue: Double? = nil
    var showAverageLine: Bool = true
    var averageLineWidth: CGFloat = 2
    
    public init(
        lineColor: [Color] = [.red, .purple],
        lineWidth: CGFloat = 3,
        gradientColors: [Color] = [.red.opacity(0.3), .red.opacity(0.05)],
        pointColor: Color = .red,
        pointBackgroundColor: Color = .white,
        animationDuration: Double = 1.5,
        showXAxis: Bool = true,
        showYAxis: Bool = true,
        showGradient: Bool = true,
        xAxisMinSpace: Double = 50,
        xAxisHeight: CGFloat = 20,
        yAxisSep: Int = 5,
        smoothness: CGFloat = 0.5,
        showPointCircle: Bool = false,
        showYLines: Bool = false,
        maxValue: Double? = nil,
        minValue: Double? = nil,
        showAverageLine: Bool = true,
        averageLineColor: Color? = nil,
        averageLineWidth: CGFloat = 2
    ) {
        self.lineColor = lineColor
        self.lineWidth = lineWidth
        self.gradientColors = gradientColors
        self.pointColor = pointColor
        self.pointBackgroundColor = pointBackgroundColor
        self.animationDuration = animationDuration
        self.showXAxis = showXAxis
        self.showYAxis = showYAxis
        self.showGradient = showGradient
        self.xAxisMinSpace = xAxisMinSpace
        self.xAxisHeight = xAxisHeight
        self.yAxisSep = yAxisSep
        self.smoothness = smoothness
        self.showPointCircle = showPointCircle
        self.showYLines = showYLines
        self.maxValue = maxValue
        self.minValue = minValue
        self.showAverageLine = showAverageLine
        self.averageLineWidth = averageLineWidth
    }
}

// MARK: - ChartLine View
public struct ScrollChartLine: View {
    @Binding var data: [ScrollChartDataPoint]
    var style: ScrollChartStyle
    @State private var location: CGPoint = .zero
    @State private var selected: ScrollChartDataPoint? = nil
    @State private var animationProgress: CGFloat = 0
    @State private var scollSize:CGSize = .zero
    @State private var previousDataHash: Int = 0
    
    public init(data: Binding<[ScrollChartDataPoint]>, style: ScrollChartStyle) {
        _data = data
        self.style = style
    }
    
    public var body: some View {
        VStack {
            GeometryReader { geometry in
                let rect = geometry.frame(in: .local)
                chartContent(rect: rect)
            }
        }
        .onAppear {
            startAnimation()
        }
        .onChange(of: data) {
            startAnimation()
        }
    }
    
    // 启动动画
    private func startAnimation() {
        // 重置动画进度
        animationProgress = 0
        // 立即开始动画
        withAnimation(.easeInOut(duration: style.animationDuration)) {
            animationProgress = 1
        }
    }
}

// MARK: - 辅助视图
private extension ScrollChartLine {
    // MARK: - 图表内容
   @ViewBuilder
    private func chartContent(rect: CGRect) -> some View {
       ZStack(alignment: .topLeading) {
           if style.showYAxis {
               yAxisGrid()
                   .frame(height: style.showXAxis ? rect.height - style.xAxisHeight : rect.height)
                   .offset(y: -6)
           }
           ScrollView(.horizontal, showsIndicators: false) {
               ZStack {
                   GeometryReader { proxy in
                       Color.clear
                           .onAppear {
                               self.scollSize = proxy.size
                           }
                           .onChange(of: proxy.size) { _, new in
                               self.scollSize = new
                           }
                   }
                   .frame(maxWidth: .infinity)
                   .frame(height: style.showXAxis ? rect.height - style.xAxisHeight : rect.height)
                   VStack {
                       ZStack(alignment: .topLeading) {
                           Color.white.opacity(0.001).frame(width: self.scollSize.width, height: self.scollSize.height)
                           if !data.isEmpty {
                               if style.showGradient {
                                   gradientFill()
                               }
                               linePath()
                               if style.showAverageLine {
                                   averageLine()
                               }
                           }
                           
                           if style.showPointCircle || data.count <= 1 {
                               pointCircle()
                           }
                          if let _ = selected {
                              interactionPoint()
                          }
                       }
                       .frame(width: self.scollSize.width, height: self.scollSize.height)
                       .gesture(
                            LongPressGesture(minimumDuration: 1.0)
                                .onEnded{value in
                                }
                                .sequenced(before:
                                    DragGesture(minimumDistance: 0)
                                       .onChanged({ value in
                                          updateSelection(at: value.location, width: scollSize.width, height: scollSize.height)
                                       })
                                        .onEnded({ value in
                                           self.selected = nil
                                       })
                                  )
                       )
                       xAxisLabels()
                   }
                   if let s = selected {
                       HStack(alignment: .center, spacing: 0) {
                           Text("\(s.label):\(formatDoubleWithoutTrailingZeros(s.value))")
                               .font(.system(size: 12, weight: .medium))
                       }.padding(3)
                           .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.thinMaterial)
                           )
                       .position(x:location.x, y: calculateTooltipYPosition(rect: rect, y: location.y))
                       
                   }
               }.frame(minWidth: rect.size.width)
           }
           .frame(minWidth: rect.size.width)
           
       }
   }
    
    // MARK: - Y轴网格
    @ViewBuilder
    private func yAxisGrid() -> some View {
        let (maxValue, minValue, avgValue) = computerMaxMinAvgValue()
        VStack(spacing: 0) {
            ForEach(0..<style.yAxisSep, id: \.self) { i in
                HStack {
                    Text("\(getYValue(minValue: minValue, maxValue: maxValue, avgValue: avgValue, index: i))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.8))
                        .frame(alignment: .trailing)
                    if style.showYLines {
                        Rectangle()
                            .fill(.secondary.opacity(0.2))
                            .frame(height: 1)
                    }
                }
                Spacer()
            }
        }
    }
    
    // MARK: - X轴标签
    @ViewBuilder
    private func xAxisLabels() -> some View {
        HStack(spacing: 0) {
            ForEach(data) { point in
                Text(point.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .frame(minWidth: style.xAxisMinSpace)
            }
        }.frame(height: style.showXAxis ? style.xAxisHeight : 0).opacity(style.showXAxis ? 1 : 0)
        
    }
    // MARK: - 阴影区域
    @ViewBuilder
    private func gradientFill()  -> some View {
        let path = createSmoothPath(width:scollSize.width, height: scollSize.height, smoothness: style.smoothness, closed:true)
        path.fill(
            LinearGradient(
                colors: style.gradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
        ).mask(
            Rectangle()
                .frame(width: scollSize.width * animationProgress)
                .frame(maxWidth: .infinity, alignment: .leading)
        )
    }
    // MARK: - 线条
    @ViewBuilder
    private func linePath() -> some View {
        let path = createSmoothPath(width:scollSize.width, height: scollSize.height, smoothness: style.smoothness, closed:false)
        path.trim(from: 0, to: animationProgress)
            .stroke(LinearGradient(colors: style.lineColor, startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: style.lineWidth, lineCap: .round, lineJoin: .round))
    }
    
    // MARK: - 平均值横线
    @ViewBuilder
    private func averageLine() -> some View {
        let (maxValue, minValue, _) = computerMaxMinAvgValue()
        let dataValues = data.map { $0.value }
        let avgValue = dataValues.isEmpty ? 0 : dataValues.reduce(0, +) / Double(dataValues.count)
        let range = maxValue - minValue
        let normalized = range > 0 ? (CGFloat(avgValue) - minValue) / range : 0.5
        let yPosition = scollSize.height - (normalized * scollSize.height)
        
        ZStack(alignment: .topLeading) {
            Text("\(String(format: "%.2f", avgValue))")
                .offset(y: yPosition - 15) // 调整标签位置，避免与线条重叠
                .font(.system(size: 12))
                .foregroundStyle(LinearGradient(colors: style.lineColor, startPoint: .leading, endPoint: .trailing))
            Line()
                .stroke(style: StrokeStyle(lineWidth: style.averageLineWidth, dash: [5, 5]))
                .foregroundStyle(LinearGradient(colors: style.lineColor, startPoint: .leading, endPoint: .trailing))
                .frame(height: style.averageLineWidth)
                .offset(y: yPosition)
        }
        .opacity(animationProgress)
    }
    // MARK: - 交互点
    @ViewBuilder
    private func interactionPoint() -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                
                .fill(style.pointColor.opacity(0.3))
                .frame(maxHeight: .infinity)
                .frame(width: 2)
                .offset(x: location.x)
            Circle()
                .fill(style.pointBackgroundColor)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .fill(style.pointColor)
                        .frame(width: 10, height: 10)
                )
                .position(location)
                .shadow(color: style.pointColor.opacity(0.3), radius: 4)
        }
        .transition(.scale.combined(with: .opacity))
    }
    
    @ViewBuilder
    private func pointCircle() -> some View {
        ZStack(alignment: .topLeading) {
            let (maxValue, minValue, _) = computerMaxMinAvgValue()
            let range = maxValue - minValue
            let wSpace = max(scollSize.width / CGFloat(max(data.count, 1)), style.xAxisMinSpace)
            let points = data.enumerated().map { index, item in
                let x = (CGFloat(index) * wSpace) + (wSpace / 2)
                let normalized = range > 0 ? (item.value - minValue) / range : 0.5
                let y = scollSize.height - (CGFloat(normalized) * scollSize.height)
                return CGPoint(x: x, y: y)
            }
            ForEach(points.indices, id:\.self) { index in
                Circle()
                    .fill(style.pointColor)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .fill(style.pointBackgroundColor)
                            .frame(width: 10, height: 10)
                    )
                    .position(points[index])
                    .shadow(color: style.pointColor.opacity(0.3), radius: 4)
            }
        }
    }
    
}
// MARK: - 辅助方法
private extension ScrollChartLine {
    // MARK: - 最大最小值计算
    private func computerMaxMinAvgValue() -> (CGFloat, CGFloat, CGFloat) {
        // 收集所有有效值
        let dataValues = data.map { $0.value }
        
        // 使用自定义范围（如果提供的话），否则计算数据范围
        var maxValue = CGFloat(style.maxValue ?? (dataValues.max() ?? 100))
        var minValue = CGFloat(style.minValue ?? (dataValues.min() ?? 0))
        
        // 确保最大值和最小值不相等
        if maxValue == minValue {
            if maxValue > 0 {
                minValue = 0;
                maxValue = maxValue * CGFloat(2.0)
            } else if maxValue <= 0 {
                minValue = maxValue * CGFloat(2.0)
                maxValue = 0;
            }
        }
        
        // 计算平均步长和调整后的范围
        let avgValue = abs(CGFloat(maxValue - minValue) / CGFloat(style.yAxisSep))
        let maxTemp = maxValue + avgValue / 2;
        let minTemp = minValue - avgValue / 2;
        let avgTemp = abs(CGFloat(maxTemp - minTemp) / CGFloat(style.yAxisSep))
        
        return (maxTemp, minTemp, avgTemp)
    }
    // MARK: - Y轴值显示
    private func getYValue(minValue: CGFloat, maxValue: CGFloat, avgValue: CGFloat, index: Int) -> String {
        let value = maxValue - avgValue * CGFloat(index)
        
        // 根据整个数据范围确定小数位数
        let decimalPlaces = getDecimalPlacesForRange(avgValue: avgValue)
        
        // 直接格式化，避免NumberFormatter问题
        if decimalPlaces == 0 {
            return "\(Int(value.rounded()))"
        } else {
            return String(format: "%.\(decimalPlaces)f", value)
        }
    }

    // 根据整个数据范围确定小数位数
    private func getDecimalPlacesForRange(avgValue: CGFloat) -> Int {
        if avgValue < 0.01 {
            return 3
        } else if avgValue < 0.1 {
            return 2
        } else if avgValue < 1 {
            return 1
        } else if avgValue < 10 {
            return 1
        } else {
            return 0
        }
    }
}


// MARK: - 核心算法部分
private extension ScrollChartLine {
    
    // MARK: 创建平滑路径（Catmull–Rom 样条曲线）
    func createSmoothPath(width: CGFloat, height: CGFloat, smoothness: CGFloat, closed: Bool) -> Path {
        guard data.count > 1 else { return Path() }
        
        let (maxValue, minValue, _) = computerMaxMinAvgValue()
        let range = maxValue - minValue
        let wSpace = max(width / CGFloat(max(data.count, 1)), style.xAxisMinSpace)
        var startX = CGFloat(0.0);
        let points = data.enumerated().map { index, item in
            let x = (CGFloat(index) * wSpace) + (wSpace / 2)
            let normalized = range > 0 ? (item.value - minValue) / range : 0.5
            let y = height - (CGFloat(normalized) * height)
            if index == 0 { startX = x }
            return CGPoint(x: x, y: y)
        }
        
        var path = Path()
        path.move(to: points[0])
        
        for i in 0..<points.count - 1 {
            let p0 = i > 0 ? points[i - 1] : points[i]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = i + 2 < points.count ? points[i + 2] : points[i + 1]
            
            let t = smoothness.clamped(to: 0...1)
            
            let control1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6 * t,
                y: p1.y + (p2.y - p0.y) / 6 * t
            )
            let control2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6 * t,
                y: p2.y - (p3.y - p1.y) / 6 * t
            )
            
            path.addCurve(to: p2, control1: control1, control2: control2)
        }
        if closed, let lastPoint = points.last {
            path.addLine(to: CGPoint(x: lastPoint.x, y: height))
            path.addLine(to: CGPoint(x: startX, y: height))
            path.closeSubpath()
        }
        
        return path
    }
    
    // MARK: 根据 X 获取曲线对应 Y 值（精确对齐）
    func yValue(atX x: CGFloat, width: CGFloat, height: CGFloat) -> CGFloat {
        guard data.count > 1 else { return height / 2 }
        
        let (maxValue, minValue, _) = computerMaxMinAvgValue()
        let range = maxValue - minValue
        let wSpace = max(width / CGFloat(max(data.count, 1)), style.xAxisMinSpace)
        
        let points = data.enumerated().map { index, item -> CGPoint in
            let xPos = (CGFloat(index) * wSpace) + (wSpace / 2)
            let normalized = range > 0 ? (item.value - minValue) / range : 0.5
            let yPos = height - (CGFloat(normalized) * height)
            return CGPoint(x: xPos, y: yPos)
        }
        
        for i in 0..<points.count - 1 {
            let p0 = i > 0 ? points[i - 1] : points[i]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = i + 2 < points.count ? points[i + 2] : points[i + 1]
            
            if x >= p1.x && x <= p2.x {
                let t = style.smoothness.clamped(to: 0...1)
                
                let c1 = CGPoint(
                    x: p1.x + (p2.x - p0.x) / 6 * t,
                    y: p1.y + (p2.y - p0.y) / 6 * t
                )
                let c2 = CGPoint(
                    x: p2.x - (p3.x - p1.x) / 6 * t,
                    y: p2.y - (p3.y - p1.y) / 6 * t
                )
                
                let tVal = findTForX(targetX: x, p0: p1, c1: c1, c2: c2, p3: p2)
                let y = cubicBezier(tVal, p1.y, c1.y, c2.y, p2.y)
                return y
            }
        }
        return height / 2
    }
    
    // MARK: 选中更新
    func updateSelection(at location: CGPoint, width: CGFloat, height: CGFloat) {
        let y = yValue(atX: location.x, width: width, height: height)
        self.location = CGPoint(x: location.x, y: y)
        
        withAnimation(.easeOut(duration: 0.1)) {
            selected = closestPoint(toX: location.x, width: width)
        }
    }
    
    // MARK: 计算最近点
    func closestPoint(toX x: CGFloat, width: CGFloat) -> ScrollChartDataPoint? {
        let wSpace = max(width / CGFloat(max(data.count, 1)), style.xAxisMinSpace)
        let index = Int(x / wSpace)
        guard data.indices.contains(index) else { return nil }
        return data[index]
    }
    
    // MARK: 计算提示框Y位置
    func calculateTooltipYPosition(rect: CGRect, y: CGFloat) -> CGFloat {
        let tooltipHeight: CGFloat = 30 // 单线条提示框高度
        let outerPadding: CGFloat = 10 // 外部边距，避免紧贴边界
        
        // 计算图表区域的有效范围，使用xAxisHeight替代写死的数值
        let chartTop = outerPadding
        let chartBottom = (style.showXAxis ? rect.height - style.xAxisHeight : rect.height) - outerPadding
        
        // 计算提示框的理想位置 - 始终显示在上方
        var idealY = y - tooltipHeight
        
        // 调整位置，确保提示框完全在图表区域内
        if idealY < chartTop {
            idealY = chartTop
        } else if idealY > chartBottom {
            idealY = chartBottom
        }
        
        return idealY
    }
    
    
    func findTForX(targetX: CGFloat, p0: CGPoint, c1: CGPoint, c2: CGPoint, p3: CGPoint) -> CGFloat {
        var tMin: CGFloat = 0
        var tMax: CGFloat = 1
        var t: CGFloat = 0.5
        for _ in 0..<20 {
            let x = cubicBezier(t, p0.x, c1.x, c2.x, p3.x)
            if abs(x - targetX) < 0.1 { break }
            if x < targetX { tMin = t } else { tMax = t }
            t = (tMin + tMax) / 2
        }
        return t
    }
    
    func cubicBezier(_ t: CGFloat, _ p0: CGFloat, _ c1: CGFloat, _ c2: CGFloat, _ p3: CGFloat) -> CGFloat {
        let oneMinusT = 1 - t
        return pow(oneMinusT, 3) * p0
        + 3 * pow(oneMinusT, 2) * t * c1
        + 3 * oneMinusT * pow(t, 2) * c2
        + pow(t, 3) * p3
    }
    
    func formatDoubleWithoutTrailingZeros(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 15 // Double 最多约 15~17 位有效数字
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

// MARK: - Clamp Extension
private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

// MARK: - Line Shape
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}


// MARK: - 预览
struct ScrollChartStyle_Previews: PreviewProvider {
    static var previews: some View {
        @State var sampleData = [
            ScrollChartDataPoint(label: "Jan", value: 45),
            ScrollChartDataPoint(label: "Feb", value: 52),
            ScrollChartDataPoint(label: "Mar", value: 38),
            ScrollChartDataPoint(label: "Apr", value: 65),
            ScrollChartDataPoint(label: "May", value: 58),
            ScrollChartDataPoint(label: "Jun", value: 72),
            ScrollChartDataPoint(label: "Jul", value: 68),
            ScrollChartDataPoint(label: "Aug", value: 85),
            ScrollChartDataPoint(label: "Sep", value: 78),
            ScrollChartDataPoint(label: "Oct", value: 92),
            ScrollChartDataPoint(label: "Nov", value: 88),
            ScrollChartDataPoint(label: "Dec", value: 95)
        ]
        
        VStack {
            ScrollChartLine(data: $sampleData, style: ScrollChartStyle())
                .frame(height: 300)
                .padding()
        }
    }
}
