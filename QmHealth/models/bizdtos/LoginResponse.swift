//
//  LoginResponse.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/1/23.
//

import Foundation

// 登录响应
struct LoginResponse: Codable {
    // 用户的token
    let token: String
    // 用户id
    let userId: String
    // 用户姓名
    let userName: String?
    // 昵称
    let nickname: String?
    // 头像
    let headerImg: String?
}
