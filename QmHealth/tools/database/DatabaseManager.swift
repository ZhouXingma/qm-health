//
//  DatabaseManager.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/3/11.
//

import SwiftUI
//import SQLite
//
//class DatabaseManager {
//    static let shared = DatabaseManager()
//    private var db: Connection?
//
//    private init() {
//        do {
//            createBasePath();
//            // 初始化数据库连接
//            db = try Connection(BASIC_DIRECTOR+DATABASE_PATH+"/"+DATABASE_FILE)
//            print("Database created at: \(BASIC_DIRECTOR+DATABASE_PATH+"/"+DATABASE_FILE)")
//        } catch {
//            print("Unable to open database: \(error)")
//        }
//    }
//    
//    func createBasePath() {
//        if !FilesUtils.isExit(filePath: BASIC_DIRECTOR+DATABASE_PATH) {
//            FilesUtils.createDirector(directorPath: BASIC_DIRECTOR+DATABASE_PATH)
//        }
//        if FilesUtils.isExit(filePath: BASIC_DIRECTOR+DATABASE_PATH+"/"+DATABASE_FILE) {
//            return
//        }
//        FilesUtils.createFile(filePath: BASIC_DIRECTOR+DATABASE_PATH+"/"+DATABASE_FILE)
//    }
//
//    func getConnection() -> Connection? {
//        return db
//    }
//}
