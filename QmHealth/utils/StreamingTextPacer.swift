//
//  StreamingTextPacer.swift
//  QmHealth
//
//  Created by Kiro on 2026/7/28.
//
//  流式文本"逐字显示"节拍器。
//
//  背景：后端 SSE 的 TEXT 增量事件并不是一个字一个字下发的，一个 delta 往往包含
//  十几到上百个字符；再叠加 Markdown 解析的节流，UI 上就表现为"憋一会儿，然后
//  突然蹦出一大块"。本组件把"数据到达节奏"和"渲染显示节奏"解耦：
//
//  - 数据侧：随时把最新的完整文本作为目标（setTarget）写进来，无需关心节奏；
//  - 显示侧：定时器以稳定帧率从已显示位置向目标位置推进若干字符，
//    推进步长与积压量成正比（积压越多推进越快），既保证"逐字流出"的观感，
//    也不会因为后端突然一次给一大段而长时间落后。
//
//  历史消息、错误回退等非流式场景直接整体显示，不做逐字动画。
//

import Foundation
import Combine

/// 逐字节拍器：把"目标文本"平滑地推进为"当前显示文本"
final class StreamingTextPacer: ObservableObject {

    /// 当前应当显示的文本（随定时器逐步增长）
    @Published private(set) var displayedText: String

    // MARK: - 节奏参数

    /// 定时器帧间隔（约 40fps，足够顺滑且远低于 Markdown 解析压力上限）
    private let tickInterval: TimeInterval = 1.0 / 40.0
    /// 积压追平系数：每帧推进 ceil(积压字符数 / divisor) 个字符。
    /// 值越大越"慢而稳"，越小越"快而跳"。14 ≈ 0.35 秒内追平当前积压。
    private let catchUpDivisor: Double = 14
    /// 单帧最多推进的字符数，避免超长文本瞬间刷屏
    private let maxStepPerTick: Int = 24

    // MARK: - 内部状态

    private var target: [Character] = []
    private var revealedCount: Int
    private var timer: Timer?
    private var isPaced: Bool = true

    /// - Parameter initialText: 初始显示文本。非流式场景（如加载历史消息）应传入完整文本，
    ///   避免等待 onAppear 才触发第一帧渲染，导致内容"闪现空白"或某些场景下永远不显示。
    init(initialText: String = "") {
        self.displayedText = initialText
        self.target = Array(initialText)
        self.revealedCount = initialText.count
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - 对外接口

    /// 设置目标文本
    /// - Parameters:
    ///   - text: 目标（完整）文本
    ///   - paced: 是否启用逐字动画。历史消息 / 已完成的消息传 false，直接整体显示
    func setTarget(_ text: String, paced: Bool) {
        isPaced = paced

        guard paced else {
            revealAll(text)
            return
        }

        let chars = Array(text)

        // 目标文本不是"在已显示内容后面追加"（如重新加载、内容被整体替换、
        // 出错回退成提示文案），逐字动画没有意义，直接同步显示
        guard isAppendOnly(chars) else {
            revealAll(text)
            return
        }

        target = chars
        if revealedCount < target.count {
            startTimer()
        } else {
            stopTimer()
        }
    }

    /// 立即显示全部内容（流结束、用户中断、视图消失前的收尾）
    func flush() {
        stopTimer()
        guard revealedCount < target.count else { return }
        revealedCount = target.count
        displayedText = String(target)
    }

    // MARK: - 内部实现

    /// 判断新目标是否只是在当前已显示内容之后追加
    /// 只做 O(1) 的边界校验：字符数不能变少，且已显示部分的最后一个字符要一致
    private func isAppendOnly(_ chars: [Character]) -> Bool {
        if chars.count < revealedCount { return false }
        if revealedCount == 0 { return true }
        guard revealedCount <= target.count else { return false }
        return chars[revealedCount - 1] == target[revealedCount - 1]
    }

    private func revealAll(_ text: String) {
        stopTimer()
        target = Array(text)
        revealedCount = target.count
        if displayedText != text {
            displayedText = text
        }
    }

    private func startTimer() {
        guard timer == nil else { return }
        let newTimer = Timer(timeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // .common 模式：滚动、手势进行中也继续推进，避免拖动列表时文字停住
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let remaining = target.count - revealedCount
        guard remaining > 0 else {
            stopTimer()
            return
        }

        let catchUpStep = Int((Double(remaining) / catchUpDivisor).rounded(.up))
        let step = min(max(1, catchUpStep), maxStepPerTick)
        revealedCount = min(target.count, revealedCount + step)
        displayedText = String(target[0..<revealedCount])

        if revealedCount >= target.count {
            stopTimer()
        }
    }
}
