import SwiftUI

// MARK: - 模型定义

// 记录类型枚举
enum RecordType {
    case visit      // 就诊
    case appointment // 预约
}

// 报告文件类型
enum ReportFileType {
    case image
    case pdf
}

// 报告文件模型
struct ReportFile: Identifiable {
    let id = UUID()
    var name: String           // 原始文件名
    var displayName: String    // 显示名称（用户可编辑）
    var type: ReportFileType
    var url: URL?
    var thumbnail: UIImage?
    var size: Int64?
    var isUploaded: Bool = false  // 是否已上传到服务器
    var uploadedFileId: String?   // 已上传文件的服务器 ID
}
