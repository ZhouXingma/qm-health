//
//  CommModeel.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/6/1.
//
import Foundation

class UserDTO : Codable {
    // 用户id
    var id: String?
    // 姓名
    var name: String?
    // 昵称
    var nickname: String?
    // 性别
    var gender: Int64?
    // 生日
    var birthday: String?
    // 状态
    var status: Int64?
    // 实名认证
    var certification: Int64?
    // 头像信息
    var headerImg: String?
    // 工作
    var job: String?
    // 城市
    var city: String?
    // 血型
    var blood: Int64?
    // 血型RH
    var bloodRh: Int64?
    // 民族
    var nationality: Int64?
    // 婚姻状况
    var maritalStatus: Int64?
    
    init(id: String? = nil, name: String? = nil, nickname: String? = nil, gender: Int64? = nil, birthday: String? = nil, status: Int64? = nil, certification: Int64? = nil, headerImg: String? = nil, job: String? = nil, city: String? = nil, blood: Int64? = nil, bloodRh: Int64? = nil, nationality: Int64? = nil, maritalStatus: Int64? = nil) {
        self.id = id
        self.name = name
        self.nickname = nickname
        self.gender = gender
        self.birthday = birthday
        self.status = status
        self.certification = certification
        self.headerImg = headerImg
        self.job = job
        self.city = city
        self.blood = blood
        self.bloodRh = bloodRh
        self.nationality = nationality
        self.maritalStatus = maritalStatus
    }
}



