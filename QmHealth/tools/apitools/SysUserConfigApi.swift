//
//  SysUserConfigApi.swift
//  QmHealth
//
//  用户配置相关 API
//

import Foundation

/// 用户配置 API 服务
enum SysUserConfigApi {

    /// 后端在用户未配置时的默认 autoCreateDailyTask（对应 Rust DEFAULT_AUTO_CREATE_DAILY_TASK = true）
    static let defaultAutoCreateDailyTask: Bool = true

    /// 获取当前用户的配置（Rust: get_by_user_id → GET /api/sys/userconfig/getbyuserid）
    ///
    /// 后端在用户未配置时返回默认值（autoCreateDailyTask = DEFAULT_AUTO_CREATE_DAILY_TASK），
    /// 所以这里返回的 dto 永远不会是顶层 nil，调用方可以直接读 `autoCreateDailyTask`。
    static func getByUserId(
        completion: @escaping (SysUserConfigDTO) -> Void,
        errorHandle: ((BgResult<SysUserConfigDTO>?, BgResultNetWorkError) -> Void)? = nil,
        popManager: PopManager = PopManager.shared
    ) {
        BgResultNetWork<Empty?, SysUserConfigDTO>(
            apiUrl(SYS_USER_CONFIG_GET_BY_USER_ID),
            method: .get,
            popManager: popManager
        )
        .complicationHand { dto in
            // 后端确保 dto 永远不为 nil（未配置时返回默认值）
            completion(dto ?? SysUserConfigDTO(autoCreateDailyTask: defaultAutoCreateDailyTask))
        }
        .errorHandle { result, error in
            if let errorHandle {
                errorHandle(result, error)
            } else {
                popManager.showSimplePop(title: "提示", description: "获取配置失败：\(error)")
            }
        }
        .responseDecodable()
    }

    /// 保存或修改配置（Rust: save_or_update → POST /api/sys/userconfig/saveorupdate）
    ///
    /// 后端按 AuthUser.user_id 唯一配置：存在则更新，不存在则新增。
    static func saveOrUpdate(
        autoCreateDailyTask: Bool,
        completion: @escaping () -> Void,
        errorHandle: ((BgResult<String>?, BgResultNetWorkError) -> Void)? = nil,
        popManager: PopManager = PopManager.shared
    ) {
        let param = SysUserConfigSaveParam(autoCreateDailyTask: autoCreateDailyTask)
        BgResultNetWork<SysUserConfigSaveParam, String>(
            apiUrl(SYS_USER_CONFIG_SAVE_OR_UPDATE),
            method: .post,
            params: param,
            popManager: popManager
        )
        .complicationHand { _ in
            completion()
        }
        .errorHandle { result, error in
            if let errorHandle {
                errorHandle(result, error)
            } else {
                popManager.showSimplePop(title: "提示", description: "保存配置失败：\(error)")
            }
        }
        .responseDecodable()
    }
}