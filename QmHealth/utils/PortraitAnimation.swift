//
//  PortraitAnimation.swift
//  QmHealth
//  个人肖像动画素材匹配（按年龄 / 性别）
//

import Foundation

enum PortraitAnimation {
    /// 素材在 Bundle 中的目录
    private static let folder = "Portraits"

    /// 素材覆盖的年龄锚点
    private static let anchors: [(age: Int, key: String)] = [
        (3, "age3"),
        (8, "age8"),
        (16, "age16"),
        (28, "age28"),
        (45, "age45"),
        (68, "age68")
    ]

    /// 由生日计算周岁
    static func age(from birthday: String?, now: Date = Date()) -> Int? {
        guard let birthday, !birthday.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let birthDate = formatter.date(from: birthday) else { return nil }
        return Calendar.current.dateComponents([.year], from: birthDate, to: now).year
    }

    /// 素材名，例如 portrait_age28_male
    static func assetName(age: Int?, gender: Int64?) -> String {
        let sex = gender == Sex.female.rawValue ? "female" : "male"
        return "portrait_\(ageKey(age: age))_\(sex)"
    }

    /// 取最接近的年龄锚点；不满 1 岁使用婴儿素材
    private static func ageKey(age: Int?) -> String {
        guard let age, age >= 1 else { return "baby" }
        return anchors.min { abs($0.age - age) < abs($1.age - age) }?.key ?? "age28"
    }

    /// 素材 URL（兼容目录被平铺打包的情况）
    static func url(assetName: String) -> URL? {
        Bundle.main.url(forResource: assetName, withExtension: "mp4", subdirectory: folder)
            ?? Bundle.main.url(forResource: assetName, withExtension: "mp4")
    }
}
