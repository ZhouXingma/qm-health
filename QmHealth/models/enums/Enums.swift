//
//  Enums.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/6/3.
//
import SwiftUI
/// 民族
enum Ethnicity: Int64, CaseIterable {
    /// 汉族
    case han = 1
    /// 壮族
    case zhuang = 2
    /// 满族
    case manchu = 3
    /// 回族
    case hui = 4
    /// 苗族
    case miao = 5
    /// 维吾尔族
    case uyghur = 6
    /// 土家族
    case tujia = 7
    /// 彝族
    case yi = 8
    /// 蒙古族
    case mongolian = 9
    /// 藏族
    case tibetan = 10
    /// 布依族
    case buyi = 11
    /// 侗族
    case dong = 12
    /// 瑶族
    case yao = 13
    /// 朝鲜族
    case korean = 14
    /// 白族
    case bai = 15
    /// 哈尼族
    case hani = 16
    /// 哈萨克族
    case kazakh = 17
    /// 黎族
    case li = 18
    /// 傣族
    case dai = 19
    /// 畲族
    case she = 20
    /// 傈僳族
    case lisu = 21
    /// 仡佬族
    case gelao = 22
    /// 东乡族
    case dongxiang = 23
    /// 高山族
    case gaoshan = 24
    /// 拉祜族
    case lahulu = 25
    /// 水族
    case shui = 26
    /// 佤族
    case va = 27
    /// 纳西族
    case naxi = 28
    /// 羌族
    case qiang = 29
    /// 土族
    case tu = 30
    /// 仫佬族
    case mulao = 31
    /// 锡伯族
    case xibo = 32
    /// 柯尔克孜族
    case keerkezi = 33
    /// 达斡尔族
    case dawoer = 34
    /// 景颇族
    case jingpo = 35
    /// 毛南族
    case maonan = 36
    /// 撒拉族
    case sala = 37
    /// 布朗族
    case bulang = 38
    /// 塔吉克族
    case tajik = 39
    /// 阿昌族
    case achang = 40
    /// 普米族
    case pumi = 41
    /// 鄂温克族
    case ewenki = 42
    /// 怒族
    case nu = 43
    /// 京族
    case jing = 44
    /// 基诺族
    case jinuo = 45
    /// 德昂族
    case deang = 46
    /// 保安族
    case baoan = 47
    /// 俄罗斯族
    case russian = 48
    /// 裕固族
    case yugur = 49
    /// 乌孜别克族
    case uzbek = 50
    /// 门巴族
    case menba = 51
    /// 鄂伦春族
    case elunchun = 52
    /// 独龙族
    case dulun = 53
    /// 塔塔尔族
    case tatart = 54
    /// 赫哲族
    case hezhe = 55
    /// 珞巴族
    case luoba = 56
    
    case other = 99

    /// 获取民族描述（中文名称）
    func getDesc() -> String {
        switch self {
        case .han: return "汉族"
        case .zhuang: return "壮族"
        case .manchu: return "满族"
        case .hui: return "回族"
        case .miao: return "苗族"
        case .uyghur: return "维吾尔族"
        case .tujia: return "土家族"
        case .yi: return "彝族"
        case .mongolian: return "蒙古族"
        case .tibetan: return "藏族"
        case .buyi: return "布依族"
        case .dong: return "侗族"
        case .yao: return "瑶族"
        case .korean: return "朝鲜族"
        case .bai: return "白族"
        case .hani: return "哈尼族"
        case .kazakh: return "哈萨克族"
        case .li: return "黎族"
        case .dai: return "傣族"
        case .she: return "畲族"
        case .lisu: return "傈僳族"
        case .gelao: return "仡佬族"
        case .dongxiang: return "东乡族"
        case .gaoshan: return "高山族"
        case .lahulu: return "拉祜族"
        case .shui: return "水族"
        case .va: return "佤族"
        case .naxi: return "纳西族"
        case .qiang: return "羌族"
        case .tu: return "土族"
        case .mulao: return "仫佬族"
        case .xibo: return "锡伯族"
        case .keerkezi: return "柯尔克孜族"
        case .dawoer: return "达斡尔族"
        case .jingpo: return "景颇族"
        case .maonan: return "毛南族"
        case .sala: return "撒拉族"
        case .bulang: return "布朗族"
        case .tajik: return "塔吉克族"
        case .achang: return "阿昌族"
        case .pumi: return "普米族"
        case .ewenki: return "鄂温克族"
        case .nu: return "怒族"
        case .jing: return "京族"
        case .jinuo: return "基诺族"
        case .deang: return "德昂族"
        case .baoan: return "保安族"
        case .russian: return "俄罗斯族"
        case .yugur: return "裕固族"
        case .uzbek: return "乌孜别克族"
        case .menba: return "门巴族"
        case .elunchun: return "鄂伦春族"
        case .dulun: return "独龙族"
        case .tatart: return "塔塔尔族"
        case .hezhe: return "赫哲族"
        case .luoba: return "珞巴族"
        case .other: return "其它"
        }
    }

    /// 根据编码获取民族，若无匹配则返回 nil
    static func getByCode(code: Int64) -> Ethnicity? {
        return Self(rawValue: code)
    }
}

/// 性别
enum Sex: Int64, CaseIterable {
    /// 男
    case male = 1
    /// 女
    case female = 2
    
    func getDesc() -> String {
        switch self {
        case Sex.female:
            return "女"
        case Sex.male:
            return "男"
        }
    }
    
    static func getByCode(code:Int64) -> Sex? {
        for sex in Sex.allCases {
            if sex.rawValue == code {
                return sex
            }
        }
        return nil
    }
}

/// 头像文件类型
enum HeadFileType: Int64, CaseIterable  {
    /// 本地文件
    case localFile = 1
    /// 系统名称
    case sysName = 2
}

/// 血型
enum BloodType: Int64, CaseIterable  {
    case A = 1;
    case B = 2;
    case AB = 3;
    case O = 4;
    
    func getDesc() -> String {
        switch self {
        case BloodType.A:
            return "A"
        case BloodType.B:
            return "B"
        case BloodType.AB:
            return "AB"
        case BloodType.O:
            return "O"
        }
    }
    
    static func getByCode(code:Int64) -> BloodType? {
        for t in BloodType.allCases {
            if t.rawValue == code {
                return t
            }
        }
        return nil
    }
}
/// 血型阴阳
enum BloodRhType:Int64, CaseIterable  {
    case Yin = 1;
    case Yang = 2;
    
    func getDesc() -> String {
        switch self {
        case BloodRhType.Yin:
            return "-"
        case BloodRhType.Yang:
            return "+"
        }
    }
    
    static func getByCode(code:Int64) -> BloodRhType? {
        for t in BloodRhType.allCases {
            if t.rawValue == code {
                return t
            }
        }
        return nil
    }
}

/// 是否
enum YesOrNo: Int64, CaseIterable {
    case No = 0
    case Yes = 1
    
    func getDesc() -> String {
        switch self {
        case YesOrNo.No:
            return "否"
        case YesOrNo.Yes:
            return "是"
        }
    }
    
    static func getByCode(code:Int64) -> YesOrNo? {
        for t in YesOrNo.allCases {
            if t.rawValue == code {
                return t
            }
        }
        return nil
    }
}


enum MaritalStatus: Int64, CaseIterable {
    case Married = 1
    case Unmarried = 2
    case Widowed = 3
    case Divorced = 4
    case ReMarried = 5
    
    func getDesc() -> String {
        switch self {
        case MaritalStatus.Married:
            return "已婚"
        case MaritalStatus.Unmarried:
            return "未婚"
        case MaritalStatus.Widowed:
            return "离异"
        case MaritalStatus.Divorced:
            return "丧偶"
        case MaritalStatus.ReMarried:
            return "再婚"
            
        }
    }
    
    static func getByCode(code:Int64) -> MaritalStatus? {
        for t in MaritalStatus.allCases {
            if t.rawValue == code {
                return t
            }
        }
        return nil
    }
}




/// 疾病严重程度
enum DiseaseSeverity: Int64, CaseIterable, Codable {
    case mild = 1          // 轻度
    case moderate = 2  // 中度
    case severe = 3     // 重度
    case critical = 4  // 危重
    case unknown = 5   // 未知
    
    var displayName: String {
        switch self {
        case .mild: return "轻度"
        case .moderate: return "中度"
        case .severe: return "重度"
        case .critical: return "危重"
        case .unknown: return "未知"
        }
    }
    
    var color: Color {
        switch self {
        case .mild: return Color.green
        case .moderate: return Color.orange
        case .severe:  return Color.red
        case .critical: return Color.purple
        case .unknown: return Color.gray
        }
    }
    var icon: String {
        switch self {
        case .mild: return "checkmark.circle.fill"
        case .moderate: return "exclamationmark.triangle.fill"
        case .severe: return "exclamationmark.octagon.fill"
        case .critical: return "xmark.octagon.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
    
    static func getByCode(code:Int64) -> DiseaseSeverity? {
        for t in DiseaseSeverity.allCases {
            if t.rawValue == code {
                return t
            }
        }
        return nil
    }
}

/// 疾病状态
enum DiseaseStatus: Int64, CaseIterable, Codable {
    case stable = 1          // 稳定
    case improving = 2    // 好转
    case worsening = 3    // 恶化
    case recovered = 4    // 康复
    case chronic = 5        // 慢性
    case justDiagnosed = 6  // 刚患
    
    var displayName: String {
        switch self {
        case .stable: return "稳定"
        case .improving: return "好转"
        case .worsening: return "恶化"
        case .recovered: return "康复"
        case .chronic: return "慢性"
        case .justDiagnosed: return "刚患"
        }
    }
    
    var color: Color {
        switch self {
        case .stable: return Color.theme(.primary)
        case .improving: return Color.theme(.chart3)
        case .worsening: return Color("error")
        case .recovered: return Color.green
        case .chronic: return Color("warning")
        case .justDiagnosed: return Color.theme(.chart1)
        }
    }
    
    var icon: String {
        switch self {
        case .stable: return "minus.circle.fill"
        case .improving: return "arrow.up.circle.fill"
        case .worsening: return "arrow.down.circle.fill"
        case .recovered: return "checkmark.circle.fill"
        case .chronic: return "clock.circle.fill"
        case .justDiagnosed: return "exclamationmark.circle.fill"
        }
    }
    
    static func getByCode(code:Int64) -> DiseaseStatus? {
        for t in DiseaseStatus.allCases {
            if t.rawValue == code {
                return t
            }
        }
        return nil
    }
}



// 过敏源严重程度枚举
enum AllergySeverity: Int64, CaseIterable, Codable {
    case mild = 1        // 轻度
    case moderate = 2    // 中度
    case severe = 3      // 重度
    case critical = 4    // 危重
    
    var displayName: String {
        switch self {
        case .mild: return "轻度"
        case .moderate: return "中度"
        case .severe: return "重度"
        case .critical: return "危重"
        }
    }
    
    var color: Color {
        switch self {
        case .mild: return Color.green
        case .moderate: return Color.orange
        case .severe:  return Color.red
        case .critical: return Color.purple
        }
    }
    
    var icon: String {
        switch self {
        case .mild: return "checkmark.circle.fill"
        case .moderate: return "exclamationmark.triangle.fill"
        case .severe: return "exclamationmark.octagon.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }
    
    static func getByCode(code:Int64) -> AllergySeverity? {
        for t in AllergySeverity.allCases {
            if t.rawValue == code {
                return t
            }
        }
        return nil
    }
}
