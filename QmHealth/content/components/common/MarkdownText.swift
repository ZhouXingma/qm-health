//
//  MarkdownText.swift
//  QmHealth
//
//  Created by Kiro on 2026/2/11.
//  Optimized: SwiftMath for native LaTeX rendering, performance & quality improvements
//
//  依赖：SwiftMath (https://github.com/mgriebling/SwiftMath)
//  集成方式：File > Add Package Dependencies > 搜索 SwiftMath
//

import SwiftUI
import SwiftMath  // MTMathUILabel 原生 LaTeX 渲染，无需 WebKit，无网络依赖

// MARK: - 主题配置

struct MarkdownTheme {
    // 代码块样式
    static let codeBackground   = Color(red: 0.11, green: 0.13, blue: 0.15)
    static let codeHeaderBg     = Color(red: 0.08, green: 0.10, blue: 0.12)
    static let codeText         = Color(red: 0.9, green: 0.9, blue: 0.9)
    static let codeBorder       = Color.white.opacity(0.08)
    
    // 文本颜色
    static let primary          = Color.primary
    static let secondary        = Color.secondary.opacity(0.85)
    static let tertiary         = Color.secondary.opacity(0.6)
    
    // 强调色
    static let accent           = Color.blue
    static let accentLight      = Color.blue.opacity(0.1)
    
    // 引用块
    static let quoteBar         = Color.blue.opacity(0.7)
    static let quoteBackground  = Color.blue.opacity(0.06)
    static let quoteText        = Color.secondary.opacity(0.9)
    
    // 行内代码
    static let inlineCodeBg     = Color.pink.opacity(0.12)
    static let inlineCodeText   = Color.pink.opacity(0.9)
    static let inlineCodeBorder = Color.pink.opacity(0.2)
    
    // 表格
    static let tableHeaderBg    = Color.blue.opacity(0.85)
    static let tableRowEven     = Color(.systemGray6).opacity(0.5)
    static let tableRowOdd      = Color(.systemBackground)
    static let tableBorder      = Color(.systemGray4).opacity(0.5)
    
    // 圆角和间距
    static let cornerRadius:     CGFloat = 10
    static let cornerRadiusLg:   CGFloat = 12
    static let cornerRadiusSm:   CGFloat = 6
    static let padding:          CGFloat = 16
    static let paddingSm:        CGFloat = 12
    static let paddingXs:        CGFloat = 8
}

// MARK: - MarkdownText 主视图

/// 增强版 Markdown 文本视图，支持 LaTeX 公式（SwiftMath 原生渲染）
struct MarkdownText: View {
    let content: String
    let fontSize: CGFloat

    // 在后台线程解析，避免主线程卡顿
    @State private var blocks: [MarkdownBlock] = []
    // 上一次解析的内容，用于判断是否需要重新解析
    @State private var lastParsedContent: String = ""
    // Markdown 解析节流器：固定间隔 60ms（约 16 次/秒）。
    // 注意这里必须是 throttle（固定间隔一定会执行）而不是 debounce，
    // 否则流式输出时增量一直不断，解析会被无限推迟，直到流出现空隙才
    // 一次性渲染出一大块内容。
    @StateObject private var throttler = IntervalThrottlerObject(interval: 0.06)

    init(_ content: String, fontSize: CGFloat = 16) {
        self.content = content
        self.fontSize = fontSize
    }

    /// 快速判断是否包含 Markdown 语法，避免对纯文本走异步解析
    private static func containsMarkdown(_ text: String) -> Bool {
        // 检测常见 Markdown / LaTeX 标记
        let patterns: [Character] = ["#", "*", "`", "|", "$", "~", "[", "!"]
        for ch in patterns {
            if text.contains(ch) { return true }
        }
        // 检测有序列表、引用块
        if text.range(of: #"^\s*\d+\."#, options: .regularExpression) != nil { return true }
        if text.range(of: #"^\s*>"#, options: .regularExpression) != nil { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if blocks.isEmpty {
                // 解析完成前先用普通 Text 占位，避免空白闪烁
                Text(content)
                    .font(.system(size: fontSize))
                    .foregroundStyle(MarkdownTheme.primary)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    renderBlock(block)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            // 首次出现时同步初始化，避免空白帧
            if blocks.isEmpty {
                initBlocks()
            }
        }
        .onChange(of: content) { _, newContent in
            updateBlocks(newContent)
        }
    }

    /// 首次初始化：纯文本直接同步生成单个 paragraph block，有 Markdown 则异步解析
    private func initBlocks() {
        if Self.containsMarkdown(content) {
            Task.detached(priority: .userInitiated) {
                let parsed = MarkdownParser.parse(content)
                await MainActor.run {
                    blocks = parsed
                    lastParsedContent = content
                }
            }
        } else {
            // 纯文本：直接同步生成，零延迟
            let segments = MarkdownParser.parseInlineSegments(content, fontSize: fontSize)
            blocks = [MarkdownBlock(type: .paragraph, content: content, inlineSegments: segments)]
            lastParsedContent = content
        }
    }

    /// 内容更新：判断是否只是在末尾追加了纯文本，是则直接更新最后一个 block，否则重新解析
    private func updateBlocks(_ newContent: String) {
        guard newContent != lastParsedContent else { return }

        // 如果不含 Markdown 语法，直接更新最后一个 paragraph block（追加场景）
        // 纯文本保持即时更新，不使用节流
        if !Self.containsMarkdown(newContent) {
            let segments = MarkdownParser.parseInlineSegments(newContent, fontSize: fontSize)
            let newBlock = MarkdownBlock(type: .paragraph, content: newContent, inlineSegments: segments)
            if blocks.isEmpty {
                blocks = [newBlock]
            } else if case .paragraph = blocks[blocks.count - 1].type {
                // 替换最后一个 paragraph，SwiftUI 会 diff 并平滑更新
                blocks[blocks.count - 1] = newBlock
            } else {
                blocks.append(newBlock)
            }
            lastParsedContent = newContent
            return
        }

        // 含 Markdown：固定间隔节流（首次立即执行，之后最多每 60ms 一次），
        // 保证流式输出期间内容持续、均匀地刷新
        throttler.submit {
            Task.detached(priority: .userInitiated) {
                let parsed = MarkdownParser.parse(newContent)
                await MainActor.run {
                    // 并发解析可能乱序返回：流式场景内容只增不减，
                    // 用长度做单调性校验，丢弃迟到的旧结果
                    guard newContent.count >= self.lastParsedContent.count else { return }
                    self.blocks = parsed
                    self.lastParsedContent = newContent
                }
            }
        }
    }

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block.type {
        case .heading1:
            Text(MarkdownParser.buildAttributedString(block.content, fontSize: fontSize + 10))
                .font(.system(size: fontSize + 10, weight: .heavy, design: .rounded))
                .foregroundStyle(MarkdownTheme.primary)
                .padding(.top, 16)
                .padding(.bottom, 8)

        case .heading2:
            Text(MarkdownParser.buildAttributedString(block.content, fontSize: fontSize + 7))
                .font(.system(size: fontSize + 7, weight: .bold, design: .rounded))
                .foregroundStyle(MarkdownTheme.primary)
                .padding(.top, 14)
                .padding(.bottom, 6)

        case .heading3:
            Text(MarkdownParser.buildAttributedString(block.content, fontSize: fontSize + 4))
                .font(.system(size: fontSize + 4, weight: .semibold, design: .rounded))
                .foregroundStyle(MarkdownTheme.primary)
                .padding(.top, 10)
                .padding(.bottom, 4)

        case .heading4, .heading5, .heading6:
            Text(MarkdownParser.buildAttributedString(block.content, fontSize: fontSize + 2))
                .font(.system(size: fontSize + 2, weight: .semibold))
                .foregroundStyle(MarkdownTheme.secondary)
                .padding(.top, 8)
                .padding(.bottom, 2)

        case .code:
            CodeBlockView(content: block.content, language: block.language, fontSize: fontSize)

        case .mathBlock:
            // SwiftMath 块级公式：原生渲染，自适应高度，无 WebView 开销
            MathBlockView(latex: block.content, fontSize: fontSize + 4, displayMode: true)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                .background(MarkdownTheme.accentLight)
                .clipShape(RoundedRectangle(cornerRadius: MarkdownTheme.cornerRadius))

        case .paragraph:
            // 段落内可能含行内公式，使用混合渲染
            InlineMixedView(segments: block.inlineSegments, fontSize: fontSize)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 2)

        case .listItem:
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(MarkdownTheme.accent.opacity(0.8))
                    .frame(width: 5, height: 5)
                    .padding(.top, fontSize * 0.6)
                InlineMixedView(segments: block.inlineSegments, fontSize: fontSize)
                    .lineSpacing(4)
            }
            .padding(.leading, CGFloat(block.indentLevel) * 20 + 4)
            .padding(.vertical, 1)

        case .orderedListItem:
            HStack(alignment: .top, spacing: 8) {
                Text("\(block.index ?? 1).")
                    .font(.system(size: fontSize - 1, weight: .semibold, design: .rounded))
                    .foregroundStyle(MarkdownTheme.accent.opacity(0.8))
                    .frame(minWidth: 22, alignment: .trailing)
                InlineMixedView(segments: block.inlineSegments, fontSize: fontSize)
                    .lineSpacing(4)
            }
            .padding(.leading, CGFloat(block.indentLevel) * 20)
            .padding(.vertical, 1)

        case .blockquote:
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(MarkdownTheme.quoteBar)
                    .frame(width: 3)
                InlineMixedView(segments: block.inlineSegments, fontSize: fontSize)
                    .lineSpacing(4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundStyle(MarkdownTheme.quoteText)
            }
            .background(MarkdownTheme.quoteBackground)
            .clipShape(RoundedRectangle(cornerRadius: MarkdownTheme.cornerRadius))
            .padding(.vertical, 4)

        case .horizontalRule:
            Rectangle()
                .fill(Color.gray.opacity(0.25))
                .frame(height: 1)
                .padding(.vertical, 12)

        case .table:
            if let data = block.tableData {
                TableView(data: data, fontSize: fontSize)
            }

        case .checkbox:
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: block.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: fontSize + 1))
                    .foregroundStyle(block.isChecked ? Color.green.opacity(0.8) : Color.gray.opacity(0.5))
                InlineMixedView(segments: block.inlineSegments, fontSize: fontSize)
                    .lineSpacing(4)
                    .opacity(block.isChecked ? 0.65 : 1.0)
                    .strikethrough(block.isChecked, color: .gray)
            }
            .padding(.leading, CGFloat(block.indentLevel) * 20)
            .padding(.vertical, 2)
        }
    }
}

// MARK: - InlineSegment：行内内容分段模型

/// 将一行文本分成「普通富文本」和「行内 LaTeX 公式」两种片段
enum InlineSegment: Identifiable {
    case text(AttributedString)
    case math(String)            // $...$ 中的 LaTeX 字符串

    var id: String {
        switch self {
        case .text(let a): return "t_\(a.description.hashValue)"
        case .math(let s): return "m_\(s.hashValue)"
        }
    }
}

// MARK: - InlineMixedView：混合行内公式与文本

/// 将段落内的普通文本与行内公式混合排列
/// 文本使用 AttributedString，行内公式使用 MTMathUILabel（SwiftMath）
struct InlineMixedView: View {
    let segments: [InlineSegment]
    let fontSize: CGFloat

    var body: some View {
        MdFlowLayout(spacing: 2) {
            ForEach(segments) { segment in
                switch segment {
                case .text(let attr):
                    Text(attr)
                        .font(.system(size: fontSize))
                        .foregroundStyle(MarkdownTheme.primary)
                        .fixedSize(horizontal: false, vertical: true)

                case .math(let latex):
                    // 行内公式：SwiftMath 原生渲染，无 WebView
                    MathBlockView(latex: latex, fontSize: fontSize * 1.05, displayMode: false)
                        .fixedSize()
                }
            }
        }
    }
}

// MARK: - MdFlowLayout：自动换行的行内布局
// iOS 16+ 使用原生 Layout 协议；iOS 15 自动降级为 GeometryReader 方案

/// iOS 15 降级：用 GeometryReader 测量宽度后手动计算行位置
struct MdFlowLayout_iOS15<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content

    @State private var totalHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            self.generateContent(in: geo)
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geo: GeometryProxy) -> some View {
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        return ZStack(alignment: .topLeading) {
            content()
                .fixedSize()
                .alignmentGuide(.leading) { d in
                    if abs(currentX - d.width) > geo.size.width {
                        currentX = 0
                        currentY += d.height + spacing
                    }
                    let result = currentX
                    currentX += d.width + spacing
                    return -result
                }
                .alignmentGuide(.top) { _ in -currentY }
        }
        .background(viewHeightReader($totalHeight))
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geo in
            Color.clear.preference(key: HeightPreferenceKey.self, value: geo.size.height)
        }
        .onPreferenceChange(HeightPreferenceKey.self) { binding.wrappedValue = $0 }
    }
}

private struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// 统一入口：编译时自动选择版本
struct MdFlowLayout: View {
    let spacing: CGFloat
    let content: () -> AnyView

    init(spacing: CGFloat = 4, @ViewBuilder content: @escaping () -> some View) {
        self.spacing = spacing
        self.content = { AnyView(content()) }
    }

    var body: some View {
        if #available(iOS 16, *) {
            _MdFlowLayout16(spacing: spacing, content: content)
        } else {
            MdFlowLayout_iOS15(spacing: spacing, content: content)
        }
    }
}

@available(iOS 16, *)
private struct _MdFlowLayout16: View {
    let spacing: CGFloat
    let content: () -> AnyView

    var body: some View {
        MdFlowLayoutImpl(spacing: spacing) { content() }
    }
}

// 真正实现 Layout 的私有类型，避免与包装器重名
@available(iOS 16, *)
private struct MdFlowLayoutImpl: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Self.Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.replacingUnspecifiedDimensions().width
        var currentX: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            if currentX + size.width > maxWidth && currentX > 0 {
                totalHeight += lineHeight + spacing
                currentX = 0
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        totalHeight += lineHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Self.Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        var lineViews: [(sub: Self.Subviews.Element, size: CGSize, x: CGFloat)] = []

        func flushLine() {
            for item in lineViews {
                let yOffset = (lineHeight - item.size.height) / 2
                item.sub.place(
                    at: CGPoint(x: item.x, y: currentY + yOffset),
                    proposal: ProposedViewSize(item.size)
                )
            }
            lineViews.removeAll()
            currentY += lineHeight + spacing
            lineHeight = 0
            currentX = bounds.minX
        }

        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                flushLine()
            }
            lineViews.append((subview, size, currentX))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        flushLine()
    }
}

// MARK: - MathBlockView：SwiftMath 渲染器（块级 & 行内通用）

/// 使用 SwiftMath (MTMathUILabel) 原生渲染 LaTeX，无需 WebView，性能优异
struct MathBlockView: UIViewRepresentable {
    let latex: String
    let fontSize: CGFloat
    let displayMode: Bool  // true = 块级居中（display）；false = 行内（text）

    func makeUIView(context: Context) -> MTMathUILabel {
        let label = MTMathUILabel()
        label.contentInsets = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
        configure(label)
        return label
    }

    func updateUIView(_ uiView: MTMathUILabel, context: Context) {
        configure(uiView)
    }

    private func configure(_ label: MTMathUILabel) {
        // SwiftMath 使用 labelMode 区分块级/行内，而非 displayMode(Bool)
        // .display  → 块级：公式较大、居中，等价于 LaTeX $$ ... $$
        // .text     → 行内：公式较小，与文字基线对齐，等价于 LaTeX $ ... $
        label.labelMode   = displayMode ? .display : .text
        label.textAlignment = displayMode ? .center : .left
        label.latex       = latex
        label.fontSize    = fontSize
        label.font        = MTFontManager().termesFont(withSize: fontSize)
        label.textColor   = UIColor.label   // 自动适配深色/浅色模式
        label.backgroundColor = .clear

        // 错误回退：若公式解析失败显示原始文本（斜体灰色）
        if label.error != nil {
            label.labelMode = .text
            label.latex = "\\textit{" + escapeLatexText(latex) + "}"
        }
    }

    private func escapeLatexText(_ text: String) -> String {
        text.replacingOccurrences(of: "_", with: "\\_")
            .replacingOccurrences(of: "^", with: "\\^{}")
            .replacingOccurrences(of: "{", with: "\\{")
            .replacingOccurrences(of: "}", with: "\\}")
    }
}

// MARK: - InlineMarkdownView（纯文本场景的兼容保留）

/// 不含行内公式时的轻量富文本视图
struct InlineMarkdownView: View {
    let text: String
    let fontSize: CGFloat

    var body: some View {
        Text(MarkdownParser.buildAttributedString(text, fontSize: fontSize))
            .font(.system(size: fontSize))
            .foregroundStyle(MarkdownTheme.primary)
    }
}

// MARK: - CodeBlockView

struct CodeBlockView: View {
    let content: String
    let language: String?
    let fontSize: CGFloat
    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                if let lang = language, !lang.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 9))
                        Text(lang.uppercased())
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Color.white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = content
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { 
                        isCopied = true 
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { 
                        withAnimation { isCopied = false }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.system(size: 12))
                        Text(isCopied ? "已复制" : "复制")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(isCopied ? Color.green.opacity(0.9) : Color.white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(isCopied ? Color.green.opacity(0.15) : Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, MarkdownTheme.paddingSm)
            .padding(.vertical, MarkdownTheme.paddingXs)
            .background(MarkdownTheme.codeHeaderBg)

            Divider().background(MarkdownTheme.codeBorder)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(content)
                    .font(.system(size: fontSize - 1, design: .monospaced))
                    .foregroundStyle(MarkdownTheme.codeText)
                    .padding(MarkdownTheme.paddingSm)
                    .textSelection(.enabled)
            }
        }
        .background(MarkdownTheme.codeBackground)
        .clipShape(RoundedRectangle(cornerRadius: MarkdownTheme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: MarkdownTheme.cornerRadius)
                .stroke(MarkdownTheme.codeBorder, lineWidth: 1)
        )
        .padding(.vertical, 6)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
    }
}

// MARK: - TableCellView（支持 Markdown 格式和 HTML 标签）

struct TableCellView: View {
    let text: String
    let fontSize: CGFloat
    let alignment: TextAlignment
    
    var body: some View {
        let processedText = processHTMLTags(text)
        let attributedString = MarkdownParser.buildAttributedString(processedText, fontSize: fontSize)
        
        Text(attributedString)
            .multilineTextAlignment(alignment)
    }
    
    // 处理 HTML 标签
    private func processHTMLTags(_ text: String) -> String {
        var result = text
        
        // 处理 <br/>, <br>, <br />
        result = result.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        
        // 处理 <strong> 和 </strong> 转为 **
        result = result.replacingOccurrences(of: "<strong>", with: "**", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "</strong>", with: "**", options: .caseInsensitive)
        
        // 处理 <b> 和 </b> 转为 **
        result = result.replacingOccurrences(of: "<b>", with: "**", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "</b>", with: "**", options: .caseInsensitive)
        
        // 处理 <em> 和 </em> 转为 *
        result = result.replacingOccurrences(of: "<em>", with: "*", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "</em>", with: "*", options: .caseInsensitive)
        
        // 处理 <i> 和 </i> 转为 *
        result = result.replacingOccurrences(of: "<i>", with: "*", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "</i>", with: "*", options: .caseInsensitive)
        
        // 处理 <code> 和 </code> 转为 `
        result = result.replacingOccurrences(of: "<code>", with: "`", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "</code>", with: "`", options: .caseInsensitive)
        
        return result
    }
}

// MARK: - TableView

struct TableView: View {
    let data: TableData
    let fontSize: CGFloat
    
    // 计算每列的最佳宽度
    private var columnWidths: [CGFloat] {
        var widths: [CGFloat] = []
        let maxCols = max(data.headers.count, data.rows.map { $0.count }.max() ?? 0)
        
        for colIndex in 0..<maxCols {
            var maxWidth: CGFloat = 100 // 最小宽度
            
            // 检查表头宽度
            if colIndex < data.headers.count {
                let headerWidth = estimateTextWidth(stripMarkdown(data.headers[colIndex]), fontSize: fontSize - 1, isBold: true)
                maxWidth = max(maxWidth, headerWidth)
            }
            
            // 检查每行该列的宽度
            for row in data.rows {
                if colIndex < row.count {
                    let cellWidth = estimateTextWidth(stripMarkdown(row[colIndex]), fontSize: fontSize - 1, isBold: false)
                    maxWidth = max(maxWidth, cellWidth)
                }
            }
            
            // 添加内边距，设置合理的最大宽度
            widths.append(min(maxWidth + 24, 200)) // 最大宽度限制为 200，超过会换行
        }
        
        return widths
    }
    
    // 移除 Markdown 标记以估算纯文本宽度
    private func stripMarkdown(_ text: String) -> String {
        var result = text
        // 移除 HTML 标签
        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // 移除 Markdown 标记
        result = result.replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\*([^*]+)\\*", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "`([^`]+)`", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "~~([^~]+)~~", with: "$1", options: .regularExpression)
        return result
    }
    
    // 估算文本宽度（单行）
    private func estimateTextWidth(_ text: String, fontSize: CGFloat, isBold: Bool) -> CGFloat {
        let font = UIFont.systemFont(ofSize: fontSize, weight: isBold ? .semibold : .regular)
        let attributes = [NSAttributedString.Key.font: font]
        let size = (text as NSString).size(withAttributes: attributes)
        return size.width
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                // 表头
                if !data.headers.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(Array(data.headers.enumerated()), id: \.offset) { index, header in
                            TableCellView(
                                text: header,
                                fontSize: fontSize - 1,
                                alignment: data.alignments[safe: index]?.toTextAlignment ?? .leading
                            )
                            .font(.system(size: fontSize - 1, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(width: columnWidths[safe: index] ?? 100, alignment: data.alignments[safe: index]?.toAlignment ?? .leading)
                            
                            if index < data.headers.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 1)
                            }
                        }
                    }
                    .background(MarkdownTheme.tableHeaderBg)
                }
                
                // 表格内容行
                ForEach(Array(data.rows.enumerated()), id: \.offset) { rowIndex, row in
                    VStack(spacing: 0) {
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cell in
                                TableCellView(
                                    text: cell,
                                    fontSize: fontSize - 1,
                                    alignment: data.alignments[safe: colIndex]?.toTextAlignment ?? .leading
                                )
                                .foregroundStyle(MarkdownTheme.primary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(width: columnWidths[safe: colIndex] ?? 100, alignment: data.alignments[safe: colIndex]?.toAlignment ?? .top)
                                .frame(maxHeight: .infinity, alignment: .top)
                                
                                if colIndex < row.count - 1 {
                                    Rectangle()
                                        .fill(MarkdownTheme.tableBorder)
                                        .frame(width: 1)
                                }
                            }
                            
                            // 填充空列（如果该行列数少于表头列数）
                            if row.count < data.headers.count {
                                ForEach(row.count..<data.headers.count, id: \.self) { colIndex in
                                    if colIndex > 0 {
                                        Rectangle()
                                            .fill(MarkdownTheme.tableBorder)
                                            .frame(width: 1)
                                    }
                                    Text("")
                                        .frame(width: columnWidths[safe: colIndex] ?? 100)
                                        .frame(maxHeight: .infinity)
                                }
                            }
                        }
                        .background(rowIndex % 2 == 0 ? MarkdownTheme.tableRowEven : MarkdownTheme.tableRowOdd)
                        
                        if rowIndex < data.rows.count - 1 {
                            Rectangle()
                                .fill(MarkdownTheme.tableBorder)
                                .frame(height: 1)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: MarkdownTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: MarkdownTheme.cornerRadius)
                    .stroke(MarkdownTheme.tableBorder, lineWidth: 1)
            )
        }
        .padding(.vertical, 8)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
}

// MARK: - MarkdownParser

struct MarkdownParser {

    // MARK: 块级解析（纯值类型，可安全在后台线程运行）

    static func parse(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = text.components(separatedBy: .newlines)
        var i = 0

        var inCodeBlock  = false
        var codeContent  = ""
        var codeLanguage = ""
        var inMathBlock  = false
        var mathContent  = ""
        var inTable      = false
        var tableLines: [String] = []
        var orderedListCounters: [Int: Int] = [:]

        while i < lines.count {
            let line    = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // ── 数学块 $$ ──────────────────────────────────────────────
            if trimmed == "$$" {
                if inMathBlock {
                    let latex = mathContent.trimmingCharacters(in: .whitespacesAndNewlines)
                    blocks.append(MarkdownBlock(type: .mathBlock, content: latex,
                                               inlineSegments: []))
                    mathContent = ""
                    inMathBlock = false
                } else {
                    inMathBlock = true
                }
                i += 1; continue
            }
            if inMathBlock { mathContent += line + "\n"; i += 1; continue }

            // ── 代码块 ``` ─────────────────────────────────────────────
            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    let c = codeContent.trimmingCharacters(in: .whitespacesAndNewlines)
                    blocks.append(MarkdownBlock(type: .code, content: c,
                                               language: codeLanguage,
                                               inlineSegments: []))
                    codeContent = ""; inCodeBlock = false
                } else {
                    codeLanguage = String(trimmed.dropFirst(3))
                        .trimmingCharacters(in: .whitespaces)
                    inCodeBlock = true
                }
                i += 1; continue
            }
            if inCodeBlock { codeContent += line + "\n"; i += 1; continue }

            // ── 表格 ───────────────────────────────────────────────────
            if trimmed.contains("|") && !inTable {
                if i + 1 < lines.count,
                   lines[i + 1].contains("-"), lines[i + 1].contains("|") {
                    inTable = true
                    tableLines = [line]
                    i += 1
                    while i < lines.count {
                        let t = lines[i].trimmingCharacters(in: .whitespaces)
                        if t.contains("|") { tableLines.append(lines[i]); i += 1 }
                        else { break }
                    }
                    if let tb = parseTable(tableLines) { blocks.append(tb) }
                    inTable = false; tableLines = []
                    continue
                }
            }

            // ── 空行 ───────────────────────────────────────────────────
            if trimmed.isEmpty {
                // 只有在非列表上下文时才清空计数器
                // 检查前一个块是否是有序列表，如果是则保留计数器
                if let lastBlock = blocks.last, lastBlock.type != .orderedListItem {
                    orderedListCounters.removeAll()
                }
                i += 1; continue
            }

            // ── 分割线 ────────────────────────────────────────────────
            if isHorizontalRule(trimmed) {
                blocks.append(MarkdownBlock(type: .horizontalRule, content: "",
                                           inlineSegments: []))
                orderedListCounters.removeAll()
                i += 1; continue
            }

            // ── 标题 ──────────────────────────────────────────────────
            if let h = parseHeading(line) {
                blocks.append(h)
                orderedListCounters.removeAll(); i += 1; continue
            }

            let indent = calculateIndent(line)

            // ── 复选框 ────────────────────────────────────────────────
            if let cb = parseCheckbox(trimmed, indent: indent) {
                blocks.append(cb)
                orderedListCounters.removeAll()
                i += 1; continue
            }

            // ── 无序列表 ──────────────────────────────────────────────
            if isUnorderedList(trimmed) {
                let c = String(trimmed.dropFirst(2))
                var block = MarkdownBlock(type: .listItem, content: c,
                                         indentLevel: indent,
                                         inlineSegments: [])
                block.inlineSegments = parseInlineSegments(c, fontSize: 16)
                blocks.append(block)
                orderedListCounters.removeAll(); i += 1; continue
            }

            // ── 有序列表 ──────────────────────────────────────────────
            if let range = trimmed.range(of: "^\\d+\\.\\s", options: .regularExpression) {
                let c = String(trimmed[range.upperBound...])
                
                // 检查是否需要重置计数器（新的列表开始）
                // 如果前一个块不是有序列表，或者缩进级别改变，则重置该级别的计数器
                if let lastBlock = blocks.last {
                    if lastBlock.type != .orderedListItem {
                        orderedListCounters[indent] = 0
                    } else if lastBlock.indentLevel != indent {
                        orderedListCounters[indent] = 0
                    }
                }
                
                let count = orderedListCounters[indent, default: 0] + 1
                orderedListCounters[indent] = count
                var block = MarkdownBlock(type: .orderedListItem, content: c,
                                         index: count, indentLevel: indent,
                                         inlineSegments: [])
                block.inlineSegments = parseInlineSegments(c, fontSize: 16)
                blocks.append(block)
                i += 1; continue
            }

            // ── 引用 ──────────────────────────────────────────────────
            if trimmed.hasPrefix("> ") {
                let c = String(trimmed.dropFirst(2))
                var block = MarkdownBlock(type: .blockquote, content: c,
                                         inlineSegments: [])
                block.inlineSegments = parseInlineSegments(c, fontSize: 16)
                blocks.append(block)
                orderedListCounters.removeAll()
                i += 1; continue
            }

            // ── 段落（合并连续行）────────────────────────────────────
            var pContent = trimmed
            i += 1
            while i < lines.count {
                let next = lines[i].trimmingCharacters(in: .whitespaces)
                if next.isEmpty || isSpecialStart(next) { break }
                pContent += " " + next
                i += 1
            }
            // 段落的行内 segments 在解析时携带 fontSize 占位值；实际渲染时由 InlineMixedView 使用自己的 fontSize
            let segments = parseInlineSegments(pContent, fontSize: 16)
            blocks.append(MarkdownBlock(type: .paragraph, content: pContent,
                                        inlineSegments: segments))
            orderedListCounters.removeAll()
        }

        return blocks
    }

    // MARK: 行内分段（拆出行内公式）

    /// 将含 $...$ 的文本拆成 [InlineSegment]，便于混合渲染
    static func parseInlineSegments(_ text: String, fontSize: CGFloat) -> [InlineSegment] {
        // 匹配 $...$ 行内公式
        let pattern = "\\$([^$\n]+?)\\$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.text(buildAttributedString(text, fontSize: fontSize))]
        }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, range: fullRange)

        if matches.isEmpty {
            return [.text(buildAttributedString(text, fontSize: fontSize))]
        }

        var segments: [InlineSegment] = []
        var cursor = text.startIndex

        for match in matches {
            guard let matchRange    = Range(match.range,       in: text),
                  let contentRange = Range(match.range(at: 1), in: text) else { continue }

            // 公式前的普通文本
            if cursor < matchRange.lowerBound {
                let plain = String(text[cursor..<matchRange.lowerBound])
                let attr  = buildAttributedString(plain, fontSize: fontSize)
                segments.append(.text(attr))
            }

            // 行内公式
            let latexStr = String(text[contentRange])
            segments.append(.math(latexStr))

            cursor = matchRange.upperBound
        }

        // 最后剩余的普通文本
        if cursor < text.endIndex {
            let tail = String(text[cursor...])
            segments.append(.text(buildAttributedString(tail, fontSize: fontSize)))
        }

        return segments
    }

    // MARK: 富文本构建（粗体、斜体、删除线、高亮、行内代码）

    static func buildAttributedString(_ text: String, fontSize: CGFloat) -> AttributedString {
        var result = AttributedString(text)

        // 行内代码（优先，避免被 * 干扰）
        applyPattern("`([^`\n]+?)`", text: text, to: &result) { attr in
            attr.font            = .system(size: fontSize - 0.5, design: .monospaced)
            attr.foregroundColor = MarkdownTheme.inlineCodeText
            attr.backgroundColor = MarkdownTheme.inlineCodeBg
        }
        // 粗斜体 ***
        applyPattern("\\*\\*\\*([^*]+?)\\*\\*\\*", text: text, to: &result) { attr in
            attr.font = .system(size: fontSize, weight: .bold).italic()
            attr.foregroundColor = MarkdownTheme.primary
        }
        // 粗体 **
        applyPattern("\\*\\*([^*]+?)\\*\\*", text: text, to: &result) { attr in
            attr.font = .system(size: fontSize, weight: .bold)
            attr.foregroundColor = MarkdownTheme.primary
        }
        // 斜体 *
        applyPattern("(?<!\\*)\\*([^*]+?)\\*(?!\\*)", text: text, to: &result) { attr in
            attr.font = .system(size: fontSize).italic()
            attr.foregroundColor = MarkdownTheme.secondary
        }
        // 删除线 ~~
        applyPattern("~~([^~]+?)~~", text: text, to: &result) { attr in
            attr.strikethroughStyle = .single
            attr.strikethroughColor = .gray
            attr.foregroundColor    = MarkdownTheme.tertiary
        }
        // 高亮 ==
        applyPattern("==([^=]+?)==", text: text, to: &result) { attr in
            attr.backgroundColor = Color.yellow.opacity(0.35)
            attr.foregroundColor = MarkdownTheme.primary
        }

        return result
    }

    // MARK: Inline AttributedString（供 InlineMarkdownView 兼容使用）

    static func parseInline(_ text: String, fontSize: CGFloat) -> AttributedString {
        buildAttributedString(text, fontSize: fontSize)
    }

    // MARK: 私有工具方法

    private static func applyPattern(
        _ pattern: String,
        text: String,
        to result: inout AttributedString,
        modifier: (inout AttributedString) -> Void
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches.reversed() {
            guard let r            = Range(match.range,       in: text),
                  let contentRange = Range(match.range(at: 1), in: text) else { continue }
            let fullStr    = String(text[r])
            let contentStr = String(text[contentRange])
            if let attrRange = result.range(of: fullStr) {
                var newAttr = AttributedString(contentStr)
                modifier(&newAttr)
                result.replaceSubrange(attrRange, with: newAttr)
            }
        }
    }

    private static func isSpecialStart(_ line: String) -> Bool {
        line.hasPrefix("#") || line.hasPrefix("- ") || line.hasPrefix("* ") ||
        line.hasPrefix("+ ") || line.hasPrefix(">") || line.hasPrefix("`") ||
        line.hasPrefix("$") || line.contains("|")
    }

    private static func isHorizontalRule(_ line: String) -> Bool {
        line.range(of: "^---+$", options: .regularExpression) != nil
    }

    private static func parseHeading(_ line: String) -> MarkdownBlock? {
        guard let match = line.range(of: "^#{1,6}\\s?", options: .regularExpression) else { return nil }
        let level   = line[match].filter { $0 == "#" }.count
        let content = String(line[match.upperBound...])
        let types: [Int: MarkdownBlockType] = [
            1: .heading1, 2: .heading2, 3: .heading3,
            4: .heading4, 5: .heading5, 6: .heading6
        ]
        guard let type = types[level] else { return nil }
        return MarkdownBlock(type: type, content: content, inlineSegments: [])
    }

    private static func calculateIndent(_ line: String) -> Int {
        line.prefix(while: { $0 == " " }).count / 2
    }

    private static func parseCheckbox(_ line: String, indent: Int) -> MarkdownBlock? {
        let pattern = "^[-*+]\\s*\\[([ xX])\\]\\s+(.+)$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line,
                                           range: NSRange(line.startIndex..., in: line)),
              let r1 = Range(match.range(at: 1), in: line),
              let r2 = Range(match.range(at: 2), in: line) else { return nil }
        let isChecked = String(line[r1]).lowercased() == "x"
        let content   = String(line[r2])
        var block = MarkdownBlock(type: .checkbox, content: content,
                                  indentLevel: indent, isChecked: isChecked,
                                  inlineSegments: [])
        block.inlineSegments = parseInlineSegments(content, fontSize: 16)
        return block
    }

    private static func isUnorderedList(_ line: String) -> Bool {
        line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ")
    }

    private static func parseTable(_ lines: [String]) -> MarkdownBlock? {
        guard lines.count >= 2 else { return nil }
        let headers = lines[0].split(separator: "|")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let alignRow = lines[1].split(separator: "|")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var alignments: [TableAlignment] = []
        for cell in alignRow {
            if cell.hasPrefix(":") && cell.hasSuffix(":") { alignments.append(.center) }
            else if cell.hasSuffix(":") { alignments.append(.right) }
            else { alignments.append(.left) }
        }
        var rows: [[String]] = []
        for k in 2..<lines.count {
            let row = lines[k].split(separator: "|")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if !row.isEmpty { rows.append(row) }
        }
        let tableData = TableData(headers: headers, rows: rows, alignments: alignments)
        return MarkdownBlock(type: .table, content: "", tableData: tableData,
                             inlineSegments: [])
    }
}

// MARK: - 数据模型

enum MarkdownBlockType {
    case heading1, heading2, heading3, heading4, heading5, heading6
    case paragraph, code, mathBlock
    case listItem, orderedListItem, blockquote, horizontalRule, table, checkbox
}

struct MarkdownBlock: Identifiable {
    let id              = UUID()
    let type:           MarkdownBlockType
    let content:        String
    var index:          Int?              = nil
    var indentLevel:    Int               = 0
    var language:       String?           = nil
    var tableData:      TableData?        = nil
    var isChecked:      Bool              = false
    // 预解析的行内分段，供 InlineMixedView 使用；mathBlock/code 此字段为空
    var inlineSegments: [InlineSegment]   = []

    init(type: MarkdownBlockType, content: String,
         index: Int? = nil, indentLevel: Int = 0,
         language: String? = nil, tableData: TableData? = nil,
         isChecked: Bool = false, inlineSegments: [InlineSegment] = []) {
        self.type           = type
        self.content        = content
        self.index          = index
        self.indentLevel    = indentLevel
        self.language       = language
        self.tableData      = tableData
        self.isChecked      = isChecked
        self.inlineSegments = inlineSegments
    }
}

struct TableData {
    let headers:    [String]
    let rows:       [[String]]
    let alignments: [TableAlignment]
}

enum TableAlignment {
    case left, center, right
    
    var toAlignment: Alignment {
        switch self {
        case .left:   return .leading
        case .center: return .center
        case .right:  return .trailing
        }
    }
    
    var toTextAlignment: TextAlignment {
        switch self {
        case .left:   return .leading
        case .center: return .center
        case .right:  return .trailing
        }
    }
}

// MARK: - 工具扩展

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        MarkdownText("""
        # 📱 移动端 Markdown 渲染
        
        这是一个专为移动端优化的 Markdown 渲染组件，支持 LaTeX 公式、代码高亮等丰富特性。
        
        ## ✨ 主要特性
        
        ### 行内公式渲染
        爱因斯坦质能方程 $E = mc^2$ 和欧拉公式 $e^{i\\pi} + 1 = 0$ 通过 SwiftMath 原生渲染。
        
        勾股定理 $a^2 + b^2 = c^2$，二次方程 $x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}$
        
        ### 块级公式
        傅里叶变换：
        $$
        f(x) = \\int_{-\\infty}^{+\\infty} \\hat{f}(\\xi)\\, e^{2\\pi i \\xi x}\\, d\\xi
        $$
        
        正态分布：
        $$
        f(x) = \\frac{1}{\\sigma\\sqrt{2\\pi}} e^{-\\frac{(x-\\mu)^2}{2\\sigma^2}}
        $$
        
        ## 🎨 文本样式
        
        支持 **粗体**、*斜体*、***粗斜体***、~~删除线~~、==高亮== 和 `行内代码`
        
        > 这是一个引用块，可以包含 **格式化** 文字和 $\\alpha + \\beta = \\gamma$ 公式
        
        ## 📋 列表功能
        
        ### 无序列表
        - 第一项内容
        - 第二项包含公式 $\\sin^2\\theta + \\cos^2\\theta = 1$
        - 第三项内容
          - 嵌套子项 A
          - 嵌套子项 B
        
        ### 有序列表
        1. 准备工作
        2. 执行步骤
        3. 验证结果
        
        ### 任务列表
        - [x] 完成 UI 设计
        - [x] 实现核心功能
        - [ ] 编写单元测试
        - [ ] 发布版本
        
        ---
        
        ## 💻 代码块
        
        ```swift
        // SwiftMath 集成示例
        import SwiftMath
        
        let label = MTMathUILabel()
        label.latex = "E = mc^2"
        label.fontSize = 20
        label.labelMode = .display
        ```
        
        ```python
        def fibonacci(n):
            if n <= 1:
                return n
            return fibonacci(n-1) + fibonacci(n-2)
        ```
        
        ## 📊 表格展示
        
        | 特性 | 旧方案 | 新方案 |
        | :--- | :---: | :---: |
        | 性能 | ❌ 慢 | ✅ 快 |
        | 离线 | ❌ 需联网 | ✅ 离线 |
        | 深色模式 | ⚠️ 手动 | ✅ 自动 |
        | 内存占用 | ❌ 高 | ✅ 低 |
        
        ### 支持 Markdown 格式的表格
        
        | 项目 | 说明 |
        | :--- | :--- |
        | **用药时间** | 每天早上 8:00<br/>每天晚上 20:00 |
        | *注意事项* | 饭后服用<br/>避免空腹 |
        | `剂量` | 每次 **2片**<br/>每日 *3次* |
        
        ## 🔬 复杂公式
        
        麦克斯韦方程组：
        $$
        \\begin{aligned}
        \\nabla \\cdot \\mathbf{E} &= \\frac{\\rho}{\\epsilon_0} \\\\
        \\nabla \\cdot \\mathbf{B} &= 0 \\\\
        \\nabla \\times \\mathbf{E} &= -\\frac{\\partial \\mathbf{B}}{\\partial t} \\\\
        \\nabla \\times \\mathbf{B} &= \\mu_0\\mathbf{J} + \\mu_0\\epsilon_0\\frac{\\partial \\mathbf{E}}{\\partial t}
        \\end{aligned}
        $$
        
        矩阵运算：
        $$
        \\begin{bmatrix}
        a & b \\\\
        c & d
        \\end{bmatrix}
        \\begin{bmatrix}
        x \\\\
        y
        \\end{bmatrix}
        =
        \\begin{bmatrix}
        ax + by \\\\
        cx + dy
        \\end{bmatrix}
        $$
        """, fontSize: 15)
        .padding(16)
    }
    .background(Color(.systemBackground))
}
