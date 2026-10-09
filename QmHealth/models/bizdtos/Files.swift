//
//  Files.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/6/22.
//
import SwiftUI;

class FilesDTO : Codable {
    // 文件id
    var id: String?
    // 文件名字
    var name: String?
    // 文件临时id
    var fileTempId: String?
    // 文件临时id过期时间
    var tempIdExpireTime: String?
}
