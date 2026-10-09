//
//  UsersTag.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/10/1.
//


// 用户标签列表信息
class UserTagListDTO : Codable {
    // 用户id
    var tagMap:[String:[String]]
}
// 保存用户标签的参数
class UserTagSaveParam : Codable {
    // 标签类型
    var tagType: String
    // 标签
    var tags: [String]
    
    init(tagType: String, tags: [String]) {
        self.tagType = tagType
        self.tags = tags
    }
}
