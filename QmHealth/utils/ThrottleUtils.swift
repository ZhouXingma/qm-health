//
//  ThrottleUtils.swift
//  QmHealth
//
//  Created by Kiro on 2026/2/11.
//  用途：提供节流功能，限制函数执行频率，避免过度调用
//

import Foundation
import Combine
import QuartzCore

// MARK: - Throttler 节流器

/// 节流器：限制函数执行频率
/// 在指定的延迟时间内，只执行最后一次调用
class Throttler {
    private var workItem: DispatchWorkItem?
    private let queue: DispatchQueue
    private let delay: TimeInterval
    
    /// 初始化节流器
    /// - Parameters:
    ///   - delay: 节流延迟时间（秒）
    ///   - queue: 执行队列，默认为主队列
    init(delay: TimeInterval, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }
    
    /// 节流执行：取消之前的任务，安排新任务在延迟后执行
    /// - Parameter action: 要执行的闭包
    func throttle(_ action: @escaping () -> Void) {
        // 取消之前的任务
        workItem?.cancel()
        
        // 创建新任务
        let newWorkItem = DispatchWorkItem(block: action)
        workItem = newWorkItem
        
        // 在延迟后执行
        queue.asyncAfter(deadline: .now() + delay, execute: newWorkItem)
    }
    
    /// 取消所有挂起的任务
    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
    
    deinit {
        cancel()
    }
}

// MARK: - ThrottlerObject 可观察节流器对象

/// 包装 Throttler 为 ObservableObject，用于 SwiftUI 中的 @StateObject
/// 提供与 SwiftUI 视图生命周期集成的节流功能
class ThrottlerObject: ObservableObject {
    private let throttler: Throttler
    
    /// 初始化可观察节流器对象
    /// - Parameter delay: 节流延迟时间（秒）
    init(delay: TimeInterval) {
        self.throttler = Throttler(delay: delay)
    }
    
    /// 节流执行：在指定延迟后执行操作，如果在延迟期间再次调用则重新计时
    /// - Parameter action: 要执行的闭包
    func throttle(_ action: @escaping () -> Void) {
        throttler.throttle(action)
    }
    
    /// 取消所有挂起的任务
    func cancel() {
        throttler.cancel()
    }
    
    deinit {
        throttler.cancel()
    }
}

// MARK: - IntervalThrottler 固定间隔节流器

/// 固定间隔节流器（真正意义上的 throttle，区别于上面 `Throttler` 的 debounce 语义）。
///
/// 语义：
/// - 首次调用立即执行（leading edge）；
/// - 距上次执行不足 `interval` 时，只保留最后一次调用，并在间隔到点时执行（trailing edge）；
/// - 因此在高频调用场景下，执行频率被稳定在 `1 / interval`，**不会**像 debounce 那样
///   在调用一直不停歇时永远不执行。
///
/// 引入原因：流式输出（SSE）时增量事件几乎连续到达，用 debounce 会导致
/// 内容长时间不刷新、直到流出现空隙才一次性渲染出一大块，体验很差。
final class IntervalThrottler {
    private let interval: TimeInterval
    private let queue: DispatchQueue

    private var lastExecuteTime: TimeInterval = 0
    private var pendingAction: (() -> Void)?
    private var isScheduled = false

    init(interval: TimeInterval, queue: DispatchQueue = .main) {
        self.interval = interval
        self.queue = queue
    }

    /// 提交一次执行请求，按固定间隔节流
    func submit(_ action: @escaping () -> Void) {
        let now = CACurrentMediaTime()
        let elapsed = now - lastExecuteTime

        if elapsed >= interval && !isScheduled {
            lastExecuteTime = now
            action()
            return
        }

        // 间隔内：只保留最后一次调用，到点后执行
        pendingAction = action
        guard !isScheduled else { return }
        isScheduled = true
        let waitTime = max(0, interval - elapsed)
        queue.asyncAfter(deadline: .now() + waitTime) { [weak self] in
            guard let self = self else { return }
            self.isScheduled = false
            self.lastExecuteTime = CACurrentMediaTime()
            let pending = self.pendingAction
            self.pendingAction = nil
            pending?()
        }
    }

    /// 立即执行挂起的任务（用于流结束时的收尾刷新）
    func flush() {
        let pending = pendingAction
        pendingAction = nil
        lastExecuteTime = CACurrentMediaTime()
        pending?()
    }

    func cancel() {
        pendingAction = nil
    }
}

/// `IntervalThrottler` 的 ObservableObject 包装，便于在 SwiftUI 中用 @StateObject 持有
final class IntervalThrottlerObject: ObservableObject {
    private let throttler: IntervalThrottler

    init(interval: TimeInterval) {
        self.throttler = IntervalThrottler(interval: interval)
    }

    func submit(_ action: @escaping () -> Void) {
        throttler.submit(action)
    }

    func flush() {
        throttler.flush()
    }

    func cancel() {
        throttler.cancel()
    }
}
