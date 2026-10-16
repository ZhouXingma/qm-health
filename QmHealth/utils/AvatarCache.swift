//
//  AvatarCache.swift
//  QmHealth
//
//  头像本地缓存：以头像文件请求地址的「路径部分」作为缓存 key
//  （去掉 http://host:port 前缀），命中后不再走网络。
//

import Foundation
import UIKit

enum AvatarCache {
    /// 头像文件的请求地址（业务 API + 文件接口 + 头像 id）
    static func url(for headerImgId: String) -> String {
        apiUrl(FILE_LOAD + "/\(headerImgId)")
    }

    /// 缓存目录：Documents/qmhealth/cache/avatar
    private static let cacheDir = BASIC_DIRECTOR + "/qmhealth/cache/avatar"

    /// 缓存文件数上限，超出按修改时间删最旧的
    private static let maxFiles = 30

    /// 会话内内存缓存，避免列表滚动时反复读盘
    private static let memory = NSCache<NSString, NSData>()

    /// 缓存 key：去掉 `http://host:port` 前缀，只取请求地址的路径部分，
    /// 再把非法字符替换成 `_`。所以文件名与文件接口路径一一对应，
    /// 不同服务端地址下的同一个文件共用一份缓存。
    static func cacheKey(for url: String) -> String {
        let path = URL(string: url)?.path ?? ""
        let trimmed = path.isEmpty
            ? url
            : path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_")
        return trimmed.unicodeScalars.map { allowed.contains($0) ? String($0) : "_" }.joined()
    }

    /// 缓存文件路径
    static func filePath(for url: String) -> String {
        cacheDir + "/" + cacheKey(for: url)
    }

    /// 读缓存：内存优先，其次文件
    static func cachedData(for url: String) -> Data? {
        let key = cacheKey(for: url) as NSString
        if let cached = memory.object(forKey: key) {
            return cached as Data
        }
        guard let data = FileManager.default.contents(atPath: filePath(for: url)) else {
            return nil
        }
        memory.setObject(data as NSData, forKey: key)
        return data
    }

    /// 写缓存：内存 + 文件同时写
    static func store(_ data: Data, for url: String) {
        memory.setObject(data as NSData, forKey: cacheKey(for: url) as NSString)

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: cacheDir) {
            try? fileManager.createDirectory(atPath: cacheDir, withIntermediateDirectories: true)
        }
        try? data.write(to: URL(fileURLWithPath: filePath(for: url)), options: .atomic)

        pruneIfNeeded()
    }

    /// 删除某一份缓存（换头像后清掉旧头像）
    static func remove(for url: String) {
        memory.removeObject(forKey: cacheKey(for: url) as NSString)
        try? FileManager.default.removeItem(atPath: filePath(for: url))
    }

    /// 缓存文件超上限时删除最旧的
    private static func pruneIfNeeded() {
        let fileManager = FileManager.default
        guard let names = try? fileManager.contentsOfDirectory(atPath: cacheDir),
              names.count > maxFiles else {
            return
        }
        let files = names.compactMap { name -> (path: String, date: Date)? in
            let path = cacheDir + "/" + name
            guard let date = (try? fileManager.attributesOfItem(atPath: path))?[.modificationDate] as? Date else {
                return nil
            }
            return (path, date)
        }
        for file in files.sorted(by: { $0.date > $1.date }).dropFirst(maxFiles) {
            try? fileManager.removeItem(atPath: file.path)
        }
    }
}
