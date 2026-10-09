//
//  SysUserConfig.swift
//  QmHealth
//
//  用户配置相关模型 / DTO
//

import Foundation

/// 后端 SysUserConfigDTO（get_by_user_id 返回）
///
/// 字段说明：
/// - autoCreateDailyTask：是否自动创建每日任务
class SysUserConfigDTO: Codable {
    var id: String?
    var userId: String?
    var autoCreateDailyTask: Bool?
    var gmtModified: String?
    var gmtDeleted: String?
    var isDeleted: Int?

    init(id: String? = nil,
         userId: String? = nil,
         autoCreateDailyTask: Bool? = nil,
         gmtModified: String? = nil,
         gmtDeleted: String? = nil,
         isDeleted: Int? = nil) {
        self.id = id
        self.userId = userId
        self.autoCreateDailyTask = autoCreateDailyTask
        self.gmtModified = gmtModified
        self.gmtDeleted = gmtDeleted
        self.isDeleted = isDeleted
    }
}

/// 保存/修改用户配置请求参数（对应 SysUserConfigSaveDTO）
struct SysUserConfigSaveParam: Encodable {
    let autoCreateDailyTask: Bool?

    init(autoCreateDailyTask: Bool?) {
        self.autoCreateDailyTask = autoCreateDailyTask
    }
}