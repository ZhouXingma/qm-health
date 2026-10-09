import SwiftUI
import Foundation

// MARK: - 发送人类型
enum SenderType: String, Codable, CaseIterable {
    case system = "system"
    case ai = "ai"
    case otherUser = "user"
}

// MARK: - 消息类型（UI 展示用）
enum MessageType: String, CaseIterable {
    case healthReminder = "health_reminder"
    case system = "system"
    case medication = "medication"
    case appointment = "appointment"
    case ai = "ai"
    case otherUser = "user"
    
    var icon: String {
        switch self {
        case .healthReminder: return "heart.fill"
        case .system: return "bell.fill"
        case .medication: return "pill.fill"
        case .appointment: return "calendar.badge.clock"
        case .ai: return "brain.head.profile"
        case .otherUser: return "person.fill"
        }
    }
    
    var label: String {
        switch self {
        case .healthReminder: return "健康提醒"
        case .system: return "系统通知"
        case .medication: return "用药提醒"
        case .appointment: return "预约提醒"
        case .ai: return "AI助手"
        case .otherUser: return "用户消息"
        }
    }
    
    var color: Color {
        switch self {
        case .healthReminder: return .red
        case .system: return Color.theme(.primary)
        case .medication: return .orange
        case .appointment: return .blue
        case .ai: return .green
        case .otherUser: return .purple
        }
    }
    
    static func from(senderType: String?) -> MessageType {
        guard let type = senderType else { return .system }
        switch type {
        case "system": return .system
        case "ai": return .ai
        case "user": return .otherUser
        default: return .system
        }
    }
}

// MARK: - API 请求参数
struct MessagePageParam: Encodable {
    let pageNumber: Int16
    let pageSize: Int16
    let isRead: Int16?
    let senderType: String?
}

struct MessageBatchDeleteParam: Encodable {
    let ids: [String]
}

struct MessageReadParam: Encodable {
    let id: String
}

// MARK: - API 返回的消息 DTO
struct MessageDTO: Codable, Identifiable {
    let id: String
    let senderId: String?
    let senderType: String?
    let receiverId: String?
    let msgTitle: String?
    let msgContent: String?
    let isRead: Int16?
    let gmtRead: String?
    let redirectType: String?
    let redirectParams: [String: String]?
    let gmtCreated: String?
}

// MARK: - 分页响应
struct MessagePageData: Codable {
    let datas: [MessageDTO]?
    let pageNumber: Int16?
    let pageSize: Int16?
    let total: Int64?
}

// MARK: - 消息模型
struct MessageNotification: Identifiable {
    let id: String
    let type: MessageType
    let title: String
    let content: String
    let time: Date
    var isRead: Bool
    let senderType: SenderType?
    let redirectType: String?
    let redirectParams: [String: String]?

    // 格式化的时间显示
    var formattedTime: String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(time) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: time)
        } else if calendar.isDateInYesterday(time) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "昨天 \(formatter.string(from: time))"
        } else if let daysAgo = calendar.dateComponents([.day], from: time, to: now).day, daysAgo < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE HH:mm"
            formatter.locale = Locale(identifier: "zh_CN")
            return formatter.string(from: time)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd HH:mm"
            return formatter.string(from: time)
        }
    }
}

// MARK: - DTO 转 模型
extension MessageNotification {
    static func from(dto: MessageDTO) -> MessageNotification? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let time = dateFormatter.date(from: dto.gmtCreated ?? "") else { return nil }
        
        return MessageNotification(
            id: dto.id,
            type: MessageType.from(senderType: dto.senderType),
            title: dto.msgTitle ?? "",
            content: dto.msgContent ?? "",
            time: time,
            isRead: (dto.isRead ?? 0) == 1,
            senderType: SenderType(rawValue: dto.senderType ?? ""),
            redirectType: dto.redirectType,
            redirectParams: dto.redirectParams
        )
    }
}

// MARK: - API 服务
class MessageApiService {
    
    /// 获取未读消息数量
    static func getUnreadCount(
        completion: @escaping (Int) -> Void,
        errorHandle: ((BgResult<Int>?, BgResultNetWorkError) -> Void)? = nil,
        popManager: PopManager = PopManager.shared
    ) {
        BgResultNetWork<Empty?, Int>(
            apiUrl(MESSAGE_UNREAD_COUNT),
            method: .post,
            popManager: popManager
        )
            .complicationHand { data in
                if let count = data {
                    completion(count)
                }
            }
            .errorHandle { result, error in
                if let errorHandle {
                    errorHandle(result, error)
                } else {
                    popManager.showSimplePop(title: "提示", description: "操作失败：\(error)")
                }
            }
            .responseDecodable()
    }

    /// 分页获取消息列表
    static func getMessagePage(
        params: MessagePageParam,
        completion: @escaping ([MessageNotification], Int64) -> Void,
        errorHandle: ((BgResult<MessagePageData>?, BgResultNetWorkError) -> Void)? = nil,
        popManager: PopManager = PopManager.shared
    ) {
        BgResultNetWork<MessagePageParam, MessagePageData>(
            apiUrl(MESSAGE_PAGE),
            method: .post,
            params: params,
            popManager: popManager
        )
            .complicationHand { data in
                var messages: [MessageNotification] = []
                let total = data?.total ?? 0
                if let dtoList = data?.datas {
                    for dto in dtoList {
                        if let message = MessageNotification.from(dto: dto) {
                            messages.append(message)
                        }
                    }
                }
                completion(messages, total)
            }
            .errorHandle { result, error in
                if let errorHandle {
                    errorHandle(result, error)
                } else {
                    popManager.showSimplePop(title: "提示", description: "加载失败：\(error)")
                }
            }
            .responseDecodable()
    }

    /// 全部标记为已读
    static func readAll(
        completion: @escaping () -> Void,
        errorHandle: ((BgResult<Int>?, BgResultNetWorkError) -> Void)? = nil,
        popManager: PopManager = PopManager.shared
    ) {
        BgResultNetWork<Empty?, Int>(
            apiUrl(MESSAGE_READ_ALL),
            method: .post,
            popManager: popManager
        )
            .complicationHand { _ in
                completion()
            }
            .errorHandle { result, error in
                if let errorHandle {
                    errorHandle(result, error)
                } else {
                    popManager.showSimplePop(title: "提示", description: "操作失败：\(error)")
                }
            }
            .responseDecodable()
    }

    /// 标记单条消息为已读
    static func markAsRead(
        id: String,
        completion: @escaping () -> Void,
        errorHandle: ((BgResult<Int>?, BgResultNetWorkError) -> Void)? = nil,
        popManager: PopManager = PopManager.shared
    ) {
        let params = MessageReadParam(id: id)
        BgResultNetWork<MessageReadParam, Int>(
            apiUrl(MESSAGE_READ),
            method: .post,
            params: params,
            popManager: popManager
        )
            .complicationHand { _ in
                completion()
            }
            .errorHandle { result, error in
                if let errorHandle {
                    errorHandle(result, error)
                } else {
                    popManager.showSimplePop(title: "提示", description: "操作失败：\(error)")
                }
            }
            .responseDecodable()
    }

    /// 根据 ID 批量删除
    static func batchDelete(
        ids: [String],
        completion: @escaping () -> Void,
        errorHandle: ((BgResult<Int>?, BgResultNetWorkError) -> Void)? = nil,
        popManager: PopManager = PopManager.shared
    ) {
        let params = MessageBatchDeleteParam(ids: ids)
        BgResultNetWork<MessageBatchDeleteParam, Int>(
            apiUrl(MESSAGE_BATCH_DELETE),
            method: .post,
            params: params,
            popManager: popManager
        )
            .complicationHand { _ in
                completion()
            }
            .errorHandle { result, error in
                if let errorHandle {
                    errorHandle(result, error)
                } else {
                    popManager.showSimplePop(title: "提示", description: "操作失败：\(error)")
                }
            }
            .responseDecodable()
    }
}
