//
//  MedicineReminder.swift
//  QmHealth
//  用药提醒：纯本地通知实现，不依赖服务端推送。
//
//  流程：拉取全部用药计划 → 本地展开未来若干天的应服时间点 →
//  为每个时间点排一条 .timeSensitive 本地通知。
//

import Foundation
import UserNotifications

/// 用药提醒调度器。
///
/// - 开关状态持久化在 UserDefaults（key 与个人中心的 @AppStorage 一致）。
/// - 拉取失败时保留既有调度，不清空，避免网络抖动导致提醒凭空消失。
/// - 今日已服用的时间点不排通知（依据 medicineplan/today 的 isTaken）。
final class MedicineReminder: NSObject, UNUserNotificationCenterDelegate {
    static let shared = MedicineReminder()

    private override init() {
        super.init()
    }

    /// 注册为通知代理，需在 App 启动早期调用。
    ///
    /// App 处于前台时，系统默认**丢弃**本地通知的展示（不弹横幅、不响铃）。
    /// 用药提醒恰恰经常在用户正看着 App 时到达（补发就是打开 App 时投递的），
    /// 所以必须实现 willPresent 显式要求展示。
    func setup() {
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    /// 用户开关。
    private static let enabledKey = "medicineReminderEnabled"

    /// 通知标识前缀，重新调度时按前缀批量清理旧通知。
    private static let identifierPrefix = "medicine-reminder-"

    /// 滚动调度窗口（天）。用户每次进入 App 都会重排以向后滚动窗口。
    private static let horizonDays = 7

    /// 待处理本地通知条数上限。
    /// iOS 对单个 App 只保留最早的 64 条 pending 通知，超出部分被系统丢弃，
    /// 因此这里按触发时间取最早的 60 条，留出余量。
    private static let pendingLimit = 60

    private var isRefreshing = false

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    // MARK: - 宽限期

    /// 宽限期档位：错过提醒后，在 App 内补发的时长。
    enum GraceOption: Int, CaseIterable, Identifiable {
        case off = 0
        case min30 = 30
        case min60 = 60
        case min120 = 120
        case min180 = 180

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .off: return "不补发"
            case .min30: return "30 分钟"
            case .min60: return "1 小时"
            case .min120: return "2 小时"
            case .min180: return "3 小时"
            }
        }
    }

    private static let graceMinutesKey = "medicineReminderGraceMinutes"
    private static let defaultGraceMinutes = GraceOption.min60.rawValue
    /// 记录今天已提醒过的时间点（正常排入系统或已补发），避免同一时间点重复提醒。
    private static let notifiedKey = "medicineReminderNotifiedSlots"

    /// 补发宽限期（分钟），0 表示不补发。
    var graceMinutes: Int {
        get {
            guard UserDefaults.standard.object(forKey: Self.graceMinutesKey) != nil else {
                return Self.defaultGraceMinutes
            }
            return UserDefaults.standard.integer(forKey: Self.graceMinutesKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.graceMinutesKey) }
    }

    // MARK: - 权限

    /// 请求通知权限，首次调用会弹出系统授权框。
    func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
    }

    /// 当前是否已获得通知权限（不弹框）。
    func hasAuthorization(_ completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let granted = settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
            DispatchQueue.main.async { completion(granted) }
        }
    }

    // MARK: - 对外入口

    /// 全量刷新提醒。开关关闭或未登录时只做清理。
    /// 触发点：App 启动/登录后、用药计划增删改后、服药记录增删后、切换账号后。
    func refresh() {
        guard isEnabled, !TokenUtils.getToken().isEmpty else {
            clearAll()
            return
        }
        guard !isRefreshing else { return }
        isRefreshing = true

        var plans: [UsersMedicinePlanDTO] = []
        var todayPlans: [TodayMedicinePlanDTO] = []
        var plansLoaded = false
        var didFinish = false

        // 收敛入口，保证只执行一次。
        // 网络层在 401 等分支不会回调任何 handler，所以除了 group 还要有超时兜底，
        // 否则 isRefreshing 会卡在 true，后续刷新全被上面的 guard 拒掉。
        let finish: () -> Void = { [weak self] in
            guard !didFinish else { return }
            didFinish = true

            guard let self else { return }
            self.isRefreshing = false
            // 计划列表拉取失败 → 保留既有调度，不动。
            guard plansLoaded else { return }
            self.schedule(plans: plans, todayPlans: todayPlans)
        }

        let group = DispatchGroup()

        // 全部计划：medicineName 传空串由服务端返回全量。
        group.enter()
        BgResultNetWork<MedicinePlanListParam, [UsersMedicinePlanDTO]>.post(
            apiUrl(MEDICINE_PLAN_LIST),
            params: MedicinePlanListParam(medicineName: "")
        )
        .complicationHand { (data: [UsersMedicinePlanDTO]?) in
            plans = data ?? []
            plansLoaded = true
            group.leave()
        }
        .errorHandle { _, _ in
            group.leave()
        }
        .responseDecodable()

        // 今日计划：用于跳过今天已经服用的时间点。
        group.enter()
        BgResultNetWork<Empty, [TodayMedicinePlanDTO]>.post(
            apiUrl(MEDICINE_PLAN_TODAY),
            params: Empty()
        )
        .complicationHand { (data: [TodayMedicinePlanDTO]?) in
            todayPlans = data ?? []
            group.leave()
        }
        .errorHandle { _, _ in
            group.leave()
        }
        .responseDecodable()

        group.notify(queue: .main, execute: finish)
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: finish)
    }

    /// 清空本模块排入的全部待处理通知。
    func clearAll(_ completion: (() -> Void)? = nil) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(Self.identifierPrefix) }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
            DispatchQueue.main.async { completion?() }
        }
    }

    // MARK: - 调度

    private func schedule(plans: [UsersMedicinePlanDTO], todayPlans: [TodayMedicinePlanDTO]) {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        // 今日已服用的 "planId|HH:mm"，用于跳过对应时间点。
        var takenKeys = Set<String>()
        for item in todayPlans where item.isTaken {
            guard let hm = normalizeTime(item.time) else { continue }
            takenKeys.insert("\(item.planId)|\(hm)")
        }

        var candidates: [(fireDate: Date, request: UNNotificationRequest, todayKey: String?)] = []

        for offset in 0..<Self.horizonDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }

            for plan in plans {
                guard let slots = doseSlots(on: day, for: plan, calendar: calendar) else { continue }

                for slot in slots {
                    guard let hourMinute = hourMinute(from: slot.time),
                          let fireDate = calendar.date(
                              bySettingHour: hourMinute.hour,
                              minute: hourMinute.minute,
                              second: 0,
                              of: day
                          ),
                          fireDate > now else { continue }

                    let hm = String(format: "%02d:%02d", hourMinute.hour, hourMinute.minute)

                    // 今天且已服用过 → 不再提醒。
                    if offset == 0, let planId = plan.id, takenKeys.contains("\(planId)|\(hm)") {
                        continue
                    }

                    let request = makeRequest(
                        plan: plan,
                        slot: slot,
                        day: day,
                        hourMinute: hourMinute,
                        calendar: calendar
                    )

                    // 今天的时间点单独记下来，供补发判断「是否已经正常提醒过」。
                    let todayKey = offset == 0
                        ? "\(plan.id ?? "plan")|\(DateUtils.formatDate(day, format: DateUtils.DateFormat.yyyymmdd))|\(hm)"
                        : nil
                    candidates.append((fireDate, request, todayKey))
                }
            }
        }

        // 按触发时间排序后只保留最早的一批，避免超出系统的 pending 上限。
        let picked = candidates
            .sorted { $0.fireDate < $1.fireDate }
            .prefix(Self.pendingLimit)

        let dayStamp = DateUtils.formatDate(today, format: DateUtils.DateFormat.yyyymmdd)
        var notified = notifiedSlots(dayStamp: dayStamp)

        // 今天已排入系统的时间点会由系统按时弹出（App 在后台/关闭也有效），
        // 所以先标记掉；否则之后打开 App 时补发会再提醒一次同一个时间点。
        for item in picked {
            if let key = item.todayKey {
                notified.insert(key)
            }
        }

        let graceRequests = makeGraceRequests(
            plans: plans,
            today: today,
            now: now,
            takenKeys: takenKeys,
            notified: &notified,
            dayStamp: dayStamp,
            calendar: calendar
        )

        saveNotifiedSlots(notified, dayStamp: dayStamp)

        clearAll {
            let center = UNUserNotificationCenter.current()
            for item in picked {
                center.add(item.request)
            }
            // 宽限期补发：错过时间点后打开 App，立即提醒一次。
            for request in graceRequests {
                center.add(request)
            }
        }
    }

    // MARK: - 宽限期补发

    /// 今天已过点、尚未服用、且距现在不超过宽限期的计划，在打开 App 时立即投递一条提醒。
    /// 本地通知必须在触发时刻前排入系统，错过了就没有机会补发——
    /// 因此这里靠「打开 App」这个时机把漏掉的提醒补上。
    /// 已经由系统正常提醒过的时间点不再补发，避免同一时间点提醒两次。
    private func makeGraceRequests(
        plans: [UsersMedicinePlanDTO],
        today: Date,
        now: Date,
        takenKeys: Set<String>,
        notified: inout Set<String>,
        dayStamp: String,
        calendar: Calendar
    ) -> [UNNotificationRequest] {
        let minutes = graceMinutes
        guard minutes > 0 else { return [] }

        let graceSeconds = TimeInterval(minutes * 60)
        var requests: [UNNotificationRequest] = []

        for plan in plans {
            guard let slots = doseSlots(on: today, for: plan, calendar: calendar) else { continue }

            for slot in slots {
                guard let hourMinute = hourMinute(from: slot.time),
                      let fireDate = calendar.date(
                          bySettingHour: hourMinute.hour,
                          minute: hourMinute.minute,
                          second: 0,
                          of: today
                      ),
                      fireDate <= now,
                      now.timeIntervalSince(fireDate) <= graceSeconds else { continue }

                let hm = String(format: "%02d:%02d", hourMinute.hour, hourMinute.minute)
                let planId = plan.id ?? "plan"

                // 已经服用过的不补发。
                if takenKeys.contains("\(planId)|\(hm)") { continue }

                let key = "\(planId)|\(dayStamp)|\(hm)"
                // 该时间点今天已经提醒过（正常排入系统或已补发）→ 不再重复提醒。
                guard !notified.contains(key) else { continue }
                notified.insert(key)

                let content = UNMutableNotificationContent()
                content.title = "用药提醒"
                content.subtitle = "\(hm) 的用药还未记录"
                let name = plan.medicineName ?? "用药"
                content.body = slot.amountText.isEmpty ? name : "\(name) \(slot.amountText)"
                content.sound = .default
                content.interruptionLevel = .timeSensitive
                content.threadIdentifier = plan.id ?? "medicine"

                requests.append(
                    UNNotificationRequest(
                        identifier: "\(Self.identifierPrefix)grace-\(key)",
                        content: content,
                        trigger: nil
                    )
                )
            }
        }

        return requests
    }

    /// 今天已经提醒过的时间点，读取时直接丢弃非当天的历史记录。
    private func notifiedSlots(dayStamp: String) -> Set<String> {
        let stored = UserDefaults.standard.stringArray(forKey: Self.notifiedKey) ?? []
        return Set(stored.filter { $0.contains("|\(dayStamp)|") })
    }

    private func saveNotifiedSlots(_ keys: Set<String>, dayStamp: String) {
        let kept = keys.filter { $0.contains("|\(dayStamp)|") }
        UserDefaults.standard.set(Array(kept), forKey: Self.notifiedKey)
    }

    private func makeRequest(
        plan: UsersMedicinePlanDTO,
        slot: DoseSlot,
        day: Date,
        hourMinute: (hour: Int, minute: Int),
        calendar: Calendar
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "用药提醒"

        let name = plan.medicineName ?? "用药"
        content.body = slot.amountText.isEmpty ? name : "\(name) \(slot.amountText)"
        content.sound = .default
        // 时间敏感：可穿透专注模式，静音下仍以横幅呈现。
        content.interruptionLevel = .timeSensitive
        content.threadIdentifier = plan.id ?? "medicine"

        let dayText = DateUtils.formatDate(day, format: DateUtils.DateFormat.yyyymmdd)
        let hmText = String(format: "%02d%02d", hourMinute.hour, hourMinute.minute)
        let identifier = "\(Self.identifierPrefix)\(plan.id ?? "plan")-\(dayText)-\(hmText)"

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(
                year: calendar.component(.year, from: day),
                month: calendar.component(.month, from: day),
                day: calendar.component(.day, from: day),
                hour: hourMinute.hour,
                minute: hourMinute.minute
            ),
            repeats: false
        )

        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    // MARK: - 展开某天的服药时间点

    private struct DoseSlot {
        let time: String
        let amountText: String
    }

    /// 该计划在指定日期是否需要服药；是则返回当天全部时间点，否则返回 nil。
    private func doseSlots(
        on day: Date,
        for plan: UsersMedicinePlanDTO,
        calendar: Calendar
    ) -> [DoseSlot]? {
        guard isDoseDay(day, plan: plan, calendar: calendar),
              let info = plan.takingInfo else { return nil }

        let times: [DoseTime]?
        switch plan.frequencyTypeEnum {
        case .weekly:
            times = weeklyTimes(info, on: day, calendar: calendar)
        case .daily, .cyclic, .interval:
            times = info.times
        case .asNeeded, .none:
            times = nil
        }

        guard let times, !times.isEmpty else { return nil }
        return times.map { DoseSlot(time: $0.time, amountText: doseText($0.doseAmount, $0.doseUnit)) }
    }

    /// 判断指定日期是否落在计划的服药日。
    private func isDoseDay(
        _ day: Date,
        plan: UsersMedicinePlanDTO,
        calendar: Calendar
    ) -> Bool {
        let dayStart = calendar.startOfDay(for: day)

        // 计划周期之外不提醒。
        let start = plan.startDate.flatMap(parseDay) ?? dayStart
        let startDay = calendar.startOfDay(for: start)
        guard dayStart >= startDay else { return false }

        if let endText = plan.endDate, !endText.isEmpty, let end = parseDay(endText) {
            guard dayStart <= calendar.startOfDay(for: end) else { return false }
        }

        guard let info = plan.takingInfo else { return false }

        switch plan.frequencyTypeEnum {
        case .daily:
            return true

        case .asNeeded, .none:
            return false

        case .weekly:
            return !(weeklyTimes(info, on: day, calendar: calendar) ?? []).isEmpty

        case .interval:
            guard let days = info.intervalDays, days > 0 else { return false }
            let diff = calendar.dateComponents([.day], from: startDay, to: dayStart).day ?? 0
            return diff >= 0 && diff % days == 0

        case .cyclic:
            // 循环定时：连续服用 cycleUseTimes 个周期单位，再停用 cycleStopTimes 个，如此往复。
            guard let use = info.cycleUseTimes, let stop = info.cycleStopTimes,
                  use > 0, use + stop > 0 else { return false }
            let unitDays = (info.cycleUnit == 2) ? 7 : 1
            let diff = calendar.dateComponents([.day], from: startDay, to: dayStart).day ?? 0
            guard diff >= 0 else { return false }
            return (diff / unitDays) % (use + stop) < use
        }
    }

    private func weeklyTimes(
        _ info: TakingInfoRaw,
        on day: Date,
        calendar: Calendar
    ) -> [DoseTime]? {
        switch calendar.component(.weekday, from: day) {
        case 1: return info.sun
        case 2: return info.mon
        case 3: return info.tue
        case 4: return info.wed
        case 5: return info.thu
        case 6: return info.fri
        case 7: return info.sat
        default: return nil
        }
    }

    // MARK: - 工具

    private func parseDay(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = DateUtils.DateFormat.ymd
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: text)
    }

    /// 解析 "H:mm" / "HH:mm" 形式的时间。
    private func hourMinute(from time: String) -> (hour: Int, minute: Int)? {
        let parts = time.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        return (hour, minute)
    }

    private func normalizeTime(_ time: String) -> String? {
        guard let hm = hourMinute(from: time) else { return nil }
        return String(format: "%02d:%02d", hm.hour, hm.minute)
    }

    private func doseText(_ amount: Double, _ unit: String) -> String {
        let amountText = amount == amount.rounded() ? String(Int(amount)) : String(amount)
        return "\(amountText)\(unit)"
    }
}
