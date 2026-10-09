//
//  JsonUtils.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/2/25.
//
import Foundation

/// 用于 JSON 编码/解码的工具类，支持自定义日期格式。
class JSONFormatUtil {
    
    public static let defaultInstall = JSONFormatUtil.default();
    public static let withoutDateFormatInstall = JSONFormatUtil.withoutDateFormatting();
    
    /// JSON 解码器
    public let decoder: JSONDecoder
    
    /// JSON 编码器
    public let encoder: JSONEncoder

    // MARK: - 构造方法

    /// 使用指定日期格式初始化工具类
    /// - Parameter dateFormat: 日期格式字符串，如 `"yyyy-MM-dd HH:mm:ss"`。若为 `nil`，则不设置日期策略。
    private init(dateDecodingStrategy:JSONDecoder.DateDecodingStrategy? = nil, dateEncodingStrategy:JSONEncoder.DateEncodingStrategy? = nil) {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        
        if let dateDecoding = dateDecodingStrategy {
            decoder.dateDecodingStrategy = dateDecoding
        }
        if let dataEncoding = dateEncodingStrategy {
            encoder.dateEncodingStrategy = dataEncoding
        }
        
        self.decoder = decoder
        self.encoder = encoder
    }

    // MARK: - 工厂方法

    /// 创建一个使用默认日期格式（"yyyy-MM-dd HH:mm:ss"）的实例
    static func `default`() -> JSONFormatUtil {
        return JSONFormatUtil.withDateFormat("yyyy-MM-dd HH:mm:ss")
    }

    /// 创建一个不处理日期格式的实例
    static func withoutDateFormatting() -> JSONFormatUtil {
        return JSONFormatUtil()
    }

    /// 创建一个使用自定义日期格式的实例
    /// - Parameter format: 日期格式字符串
    static func withDateFormat(_ format: String) -> JSONFormatUtil {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return JSONFormatUtil(dateDecodingStrategy: .formatted(formatter), dateEncodingStrategy: .formatted(formatter))
    }

    // MARK: - 编码 (Encode)

    /// 将 Encodable 对象编码为 Data
    func encode<T: Encodable>(_ value: T) throws -> Data {
        do {
            return try encoder.encode(value)
        } catch {
            print("❌ JSON encode failed: \(error)")
            throw error
        }
    }

    /// 将 Encodable 对象编码为 UTF-8 字符串
    func encodeToString<T: Encodable>(_ value: T) throws -> String? {
        guard let data = try? encode(value),
              let string = String(data: data, encoding: .utf8) else {
            print("❌ Failed to convert encoded data to string")
            return nil
        }
        return string
    }

    /// 将 Encodable 对象编码为 [String: Any] 字典（通过 JSON 中转）
    func encodeToDictionary<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try encode(value)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw EncodingError.invalidValue(value, EncodingError.Context(
                codingPath: [],
                debugDescription: "Encoded data is not a valid JSON dictionary."
            ))
        }
        return dict
    }

    // MARK: - 解码 (Decode)

    /// 从 Data 解码为指定类型
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            let jsonString = String(data: data, encoding: .utf8) ?? "<invalid UTF-8>"
            print("❌ JSON decode failed for type \(T.self). Error: \(error)")
            print("Raw JSON: \(jsonString)")
            throw error
        }
    }

    /// 从字符串解码为指定类型
    func decodeFromString<T: Decodable>(_ jsonString: String, as type: T.Type) throws -> T {
        guard let data = jsonString.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: [],
                debugDescription: "String is not valid UTF-8"
            ))
        }
        return try decode(type, from: data)
    }
}

