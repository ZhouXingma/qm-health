//
//  UsersModelConfigApi.swift
//  QmHealth
//
//  用户模型配置 API 服务（/api/users/modelconfig/*）
//

import Foundation

/// 用户模型配置 API 服务
///
/// - list: 列出当前用户所有模型配置（GET）
/// - add: 新增模型配置（POST）
/// - update: 更新模型配置（POST）
/// - delete: 删除模型配置（POST）
/// - getById: 查询单条模型配置（POST）
enum UsersModelConfigApi {

    /// 列出当前用户所有模型配置
    static func list(
        completion: @escaping ([UsersModelConfigDTO]) -> Void,
        errorHandle: ((BgResult<[UsersModelConfigDTO]>?, BgResultNetWorkError) -> Void)? = nil,
        popManager: PopManager = PopManager.shared
    ) {
        BgResultNetWork<Empty?, [UsersModelConfigDTO]>(
            apiUrl(USERS_MODEL_CONFIG_LIST),
            method: .get,
            popManager: popManager
        )
        .complicationHand { list in
            completion(list ?? [])
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

    /// 新增模型配置
    static func add(
        param: UsersModelConfigAddDTO,
        completion: @escaping (String?) -> Void,
        errorHandle: ((BgResult<String?>?, BgResultNetWorkError) -> Void)? = nil,
        popManager: PopManager = PopManager.shared
    ) {
        BgResultNetWork<UsersModelConfigAddDTO, String?>(
            apiUrl(USERS_MODEL_CONFIG_ADD),
            method: .post,
            params: param,
            popManager: popManager
        )
        .complicationHand { id in
            completion(id ?? nil)
        }
        .errorHandle { result, error in
            if let errorHandle {
                errorHandle(result, error)
            } else {
                popManager.showSimplePop(title: "提示", description: "新增失败：\(error)")
            }
        }
        .responseDecodable()
    }

    /// 更新模型配置
    static func update(
        param: UsersModelConfigUpdateDTO,
        completion: @escaping () -> Void,
        errorHandle: ((BgResult<UInt64?>?, BgResultNetWorkError) -> Void)? = nil,
        popManager: PopManager = PopManager.shared
    ) {
        BgResultNetWork<UsersModelConfigUpdateDTO, UInt64?>(
            apiUrl(USERS_MODEL_CONFIG_UPDATE),
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
                popManager.showSimplePop(title: "提示", description: "更新失败：\(error)")
            }
        }
        .responseDecodable()
    }

    /// 删除模型配置
    static func delete(
        id: String,
        completion: @escaping () -> Void,
        errorHandle: ((BgResult<UInt64?>?, BgResultNetWorkError) -> Void)? = nil,
        popManager: PopManager = PopManager.shared
    ) {
        let param = UsersModelConfigDeleteDTO(id: id)
        BgResultNetWork<UsersModelConfigDeleteDTO, UInt64?>(
            apiUrl(USERS_MODEL_CONFIG_DELETE),
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
                popManager.showSimplePop(title: "提示", description: "删除失败：\(error)")
            }
        }
        .responseDecodable()
    }

    /// 按 id 查询单条模型配置
    static func getById(
        id: String,
        completion: @escaping (UsersModelConfigDTO?) -> Void,
        errorHandle: ((BgResult<UsersModelConfigDTO?>?, BgResultNetWorkError) -> Void)? = nil,
        popManager: PopManager = PopManager.shared
    ) {
        let param = UsersModelConfigIdQueryDTO(id: id)
        BgResultNetWork<UsersModelConfigIdQueryDTO, UsersModelConfigDTO?>(
            apiUrl(USERS_MODEL_CONFIG_GET_BY_ID),
            method: .post,
            params: param,
            popManager: popManager
        )
        .complicationHand { dto in
            completion(dto ?? nil)
        }
        .errorHandle { result, error in
            if let errorHandle {
                errorHandle(result, error)
            } else {
                popManager.showSimplePop(title: "提示", description: "查询失败：\(error)")
            }
        }
        .responseDecodable()
    }
}

/// 系统默认配置 API（listbycode）
enum SysConfigApi {

    /// 根据 code 拉取配置列表（如 "AI_VENDORS"）
    static func listByCode(
        code: String,
        completion: @escaping ([SysConfigDTO]) -> Void,
        errorHandle: ((BgResult<[SysConfigDTO]>?, BgResultNetWorkError) -> Void)? = nil,
        popManager: PopManager = PopManager.shared
    ) {
        let param = SysConfigListByCodeRequest(code: code)
        BgResultNetWork<SysConfigListByCodeRequest, [SysConfigDTO]>(
            apiUrl(SYS_CONFIG_LIST_BY_CODE),
            method: .post,
            params: param,
            popManager: popManager
        )
        .complicationHand { list in
            completion(list ?? [])
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
}
