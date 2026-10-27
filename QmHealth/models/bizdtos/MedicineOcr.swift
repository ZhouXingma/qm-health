//
//  MedicineOcr.swift
//  QmHealth
//  用药信息 OCR 识别结果模型
//

import Foundation

// MARK: - 固定提示词
/// 用药信息识别提示词；输出字段与 AddMedicinePlanRequest 一一对应。
let kMedicineOcrQuestion = """
不要做任何多余的动作和查询。识别这个图片，然后按照这个json格式输出，不存在的信息可以不输出，输出内容前后不允许带任何额外符号，只输出纯文本。# 角色
你是医疗用药信息抽取引擎（OCR + 结构化）。你会收到一张图片（医院处方单、药店小票、药盒、药袋或用药医嘱截图），
任务是识别其中的用药信息，并严格输出 JSON。

# 输出要求
1. 只输出 JSON 本身，不要 markdown 代码块、不要解释、不要注释。
2. 图片中只有一种药品 → 输出一个 JSON 对象；有多种药品 → 输出 JSON 数组，每个元素结构相同。
3. 图片中没有任何药品信息 → 输出 []。
4. 字段值必须来自图片内容。图中没有的信息一律填 null，严禁推测、编造或补全。
5. 不要输出 schema 中没有的字段。

# JSON 结构（字段与 AddMedicinePlanRequest 一一对应）
{
  "medicineName": "string",
  "medicineForm": "string | null",
  "specification": "string | null",
  "specificationUnit": "string | null",
  "frequencyType": 1,
  "takingInfo": { },
  "startDate": "yyyy-MM-dd | null",
  "endDate": "yyyy-MM-dd | null",
  "sourceType": 1,
  "medicalAdvice": "string | null"
}

# 字段说明（每个字段都必须按此规则填写）

1. medicineName（string，必填）
   - 药品名称，取通用名/商品名原文，如"阿莫西林胶囊"。
   - 去掉规格、包装数量、厂家、批准文号，如"阿莫西林胶囊 0.25g*24粒" → "阿莫西林胶囊"。
   - 无法识别药名 → null（不要填"未知药品"）。

2. medicineForm（string，剂型编码，可为 null）
   - 必须是下列 MedicineForm 枚举编码之一（字符串形式，如"1"）：
     1-胶囊 2-药片 3-液体 4-外用 5-乳液 6-乳霜 7-凝胶 8-吸入剂 9-喷剂 10-栓剂
     11-泡沫 12-注射 13-滴剂 14-粉末 15-设备 16-贴剂 17-软膏 18-汤剂 19-颗粒剂
     20-丸剂（大蜜丸） 21-丸剂（水丸/浓缩丸） 22-散剂 23-膏方（膏滋） 24-丹剂
     25-锭剂 26-茶剂 27-露剂 28-药酒（酒剂） 29-酊剂 30-煎膏剂 31-流浸膏 32-浸膏剂 33-膜剂
   - 从药名/剂型描述推断，如"胶囊"→"1"、"片"→"2"、"口服液/糖浆"→"3"、"软膏"→"17"、"颗粒"→"19"、"注射"→"12"。
   - 无法判断 → null。

3. specification（string，规格数值，可为 null）
   - 只取数值部分，如"0.25g" → "0.25"，"100mg" → "100"，"5mL" → "5"。
   - 复合规格（如"500mg/5mL"）无法拆分时原样写入 specification，specificationUnit 填 null。
   - 只有包装量（如"24粒/盒"）不算规格 → null。

4. specificationUnit（string，规格单位，可为 null）
   - 与 specification 配套，如 "g"、"mg"、"μg"、"mL"、"L"、"IU"。
   - 写成图片中的单位原文，统一大小写为：g、mg、μg、mL、L、IU、%。

5. frequencyType（整数 1~5，必填）
   - 1-每天（每日固定时间服药，如"一日三次""每天早晚各一次"）
   - 2-循环定时（用药后停药再循环，如"用3天停1天""服5天停2天""用3周停1周"）
   - 3-每周特定日（如"每周一、三、五""每周日"）
   - 4-每隔N天（如"隔日一次""每3天一次"）
   - 5-按需（如"必要时服用""疼痛时服用""prn"）
   - 无法判断频次 → 5，并在 medicalAdvice 保留原医嘱文字。

6. takingInfo（object，必填，结构由 frequencyType 决定）
   剂量时间点统一结构 DoseTime：
   { "time": "HH:mm", "doseUnit": "string", "doseAmount": number }

   - frequencyType = 1：
     { "times": [DoseTime, ...] }
     例：一日三次每次1片 → {"times":[{"time":"08:00","doseUnit":"片","doseAmount":1},{"time":"12:00","doseUnit":"片","doseAmount":1},{"time":"18:00","doseUnit":"片","doseAmount":1}]}

   - frequencyType = 2：
     { "cycleUnit": 1|2, "times": [DoseTime, ...], "cycleUseTimes": number, "cycleStopTimes": number }
     cycleUnit：1-天，2-周。例："用3天停1天，每天1次1粒" →
     {"cycleUnit":1,"times":[{"time":"08:00","doseUnit":"粒","doseAmount":1}],"cycleUseTimes":3,"cycleStopTimes":1}

   - frequencyType = 3：
     { "sun": [], "mon": [], "tue": [], "wed": [], "thu": [], "fri": [], "sat": [] }
     七个键必须全部输出，不服药的日子给空数组 []。例：每周一、三、五每次1粒 →
     {"sun":[],"mon":[{"time":"08:00","doseUnit":"粒","doseAmount":1}],"tue":[],"wed":[{"time":"08:00","doseUnit":"粒","doseAmount":1}],"thu":[],"fri":[{"time":"08:00","doseUnit":"粒","doseAmount":1}],"sat":[]}

   - frequencyType = 4：
     { "intervalDays": number, "times": [DoseTime, ...] }
     例：隔日一次 → {"intervalDays":2,"times":[...]}；每3天一次 → {"intervalDays":3,"times":[...]}

   - frequencyType = 5：
     {}（固定输出空对象）

7. startDate（string，格式 yyyy-MM-dd，可为 null）
   - 取图片中的开方日期/起始日期；多个日期取最早的开方日期。
   - 图片中无日期 → null（交给系统取当天，不要自己编日期）。

8. endDate（string，格式 yyyy-MM-dd，可为 null）
   - 图片写了疗程（如"共7天""连服5天"）且能确定 startDate 时，按疗程推算结束日期。
   - 如果是当天用药或者一次性用药，endDate必须和startDate一样
   - 否则 null（表示长期服药）。

9. sourceType（整数 1~3，必填）
   - 1-医院处方：图片为医院处方单/电子处方/门诊病历医嘱。
   - 2-药店购买：图片为药店小票、购药清单、药店处方。
   - 3-自行添加：药盒、说明书、手写便签，或无法判断来源。

10. medicalAdvice（string，可为 null）
    - 保留医嘱原文，如"饭后服用""忌辛辣""多饮水""整片吞服，不可掰开"。
    - 不要重复填写已结构化到 frequencyType/takingInfo 的内容。

# 识别与推断规则
1. 时间点：图片写了具体时间（"8点""早8:00""睡前"）按原文换算为 HH:mm；
   "晨起"→08:00，"上午"→09:00，"中午"→12:00，"下午"→15:00，"晚上/睡前"→21:00。
2. 只写了次数没有时间时，按以下默认时间补齐：
   一日1次→["09:00"]；一日2次→["08:00","20:00"]；
   一日3次→["08:00","12:00","18:00"]；一日4次→["08:00","12:00","18:00","22:00"]；
   每N小时一次→从08:00起按N小时间隔排，最多4次。
3. 剂量：
   - "1片/1粒/2袋" → doseAmount 取数字，doseUnit 取单位。
   - "半片"→0.5，"1/2片"→0.5，"1.5片"→1.5。
   - "5mL" → doseAmount 5，doseUnit "mL"。
   - 只写次数不写剂量 → doseAmount 1，doseUnit 按剂型默认单位：
     胶囊=粒、药片=片、液体=mL、外用=mL、乳液=mL、乳霜=g、凝胶=g、吸入剂=吸、喷剂=喷、
     栓剂=枚、泡沫=g、注射=支、滴剂=滴、粉末=g、设备=支、贴剂=贴、软膏=g、汤剂=mL、
     颗粒剂=袋、丸剂=丸、散剂=g、膏方=g、丹剂=丸、锭剂=锭、茶剂=袋、露剂=mL、药酒=mL、
     酊剂=mL、煎膏剂=g、流浸膏=mL、浸膏剂=g、膜剂=贴。剂型未知时用"片"。
4. 频次文字映射优先级：按需 > 循环定时 > 每周特定日 > 每隔N天 > 每天。
5. 中药汤剂按"每日1剂，分早晚2次温服"等原文拆分 DoseTime，单位可用"剂""碗""mL"。

# 输出前自检
- medicineForm 只能取 1~33 的字符串，或 null。
- frequencyType 只能是 1~5 的整数。
- takingInfo 的结构必须与 frequencyType 严格匹配（3 必须输出全部七个周键）。
- doseAmount 必须是数字（不是字符串）。
- 所有日期为 yyyy-MM-dd，时间为 HH:mm。
- 除上述 10 个字段外不输出任何其他键。
- 输出必须是可被 JSON.parse 直接解析的文本。
"""

// MARK: - OCR 识别出的单种药品
/// 字段与 AddMedicinePlanRequest 对应；使用宽松解码兼容大模型偶发的字符串数字。
struct MedicineOcrItemDTO: Decodable {
    var medicineName: String?
    var medicineForm: String?
    var specification: String?
    var specificationUnit: String?
    var frequencyType: Int?
    var takingInfo: MedicineOcrTakingInfoDTO?
    var startDate: String?
    var endDate: String?
    var sourceType: Int?
    var medicalAdvice: String?

    private enum CodingKeys: String, CodingKey {
        case medicineName, medicineForm, specification, specificationUnit
        case frequencyType, takingInfo, startDate, endDate, sourceType, medicalAdvice
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        medicineName = container.ocrString(forKey: .medicineName)
        medicineForm = container.ocrString(forKey: .medicineForm)
        specification = container.ocrString(forKey: .specification)
        specificationUnit = container.ocrString(forKey: .specificationUnit)
        frequencyType = container.ocrInt(forKey: .frequencyType)
        takingInfo = try? container.decodeIfPresent(MedicineOcrTakingInfoDTO.self, forKey: .takingInfo)
        startDate = container.ocrString(forKey: .startDate)
        endDate = container.ocrString(forKey: .endDate)
        sourceType = container.ocrInt(forKey: .sourceType)
        medicalAdvice = container.ocrString(forKey: .medicalAdvice)
    }
}

// MARK: - OCR 识别出的服药详情
struct MedicineOcrTakingInfoDTO: Decodable {
    var times: [MedicineOcrDoseTimeDTO]?
    var cycleUnit: Int?
    var cycleUseTimes: Int?
    var cycleStopTimes: Int?
    var intervalDays: Int?
    var sun: [MedicineOcrDoseTimeDTO]?
    var mon: [MedicineOcrDoseTimeDTO]?
    var tue: [MedicineOcrDoseTimeDTO]?
    var wed: [MedicineOcrDoseTimeDTO]?
    var thu: [MedicineOcrDoseTimeDTO]?
    var fri: [MedicineOcrDoseTimeDTO]?
    var sat: [MedicineOcrDoseTimeDTO]?

    private enum CodingKeys: String, CodingKey {
        case times, cycleUnit, cycleUseTimes, cycleStopTimes, intervalDays
        case sun, mon, tue, wed, thu, fri, sat
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        times = try? container.decodeIfPresent([MedicineOcrDoseTimeDTO].self, forKey: .times)
        cycleUnit = container.ocrInt(forKey: .cycleUnit)
        cycleUseTimes = container.ocrInt(forKey: .cycleUseTimes)
        cycleStopTimes = container.ocrInt(forKey: .cycleStopTimes)
        intervalDays = container.ocrInt(forKey: .intervalDays)
        sun = try? container.decodeIfPresent([MedicineOcrDoseTimeDTO].self, forKey: .sun)
        mon = try? container.decodeIfPresent([MedicineOcrDoseTimeDTO].self, forKey: .mon)
        tue = try? container.decodeIfPresent([MedicineOcrDoseTimeDTO].self, forKey: .tue)
        wed = try? container.decodeIfPresent([MedicineOcrDoseTimeDTO].self, forKey: .wed)
        thu = try? container.decodeIfPresent([MedicineOcrDoseTimeDTO].self, forKey: .thu)
        fri = try? container.decodeIfPresent([MedicineOcrDoseTimeDTO].self, forKey: .fri)
        sat = try? container.decodeIfPresent([MedicineOcrDoseTimeDTO].self, forKey: .sat)
    }

    /// 按频次组装成提交结构；结构不完整时返回 nil，由上层回退到「每天」。
    func asTakingInfoRaw(frequencyType: Int16, defaultUnit: String) -> TakingInfoRaw? {
        switch frequencyType {
        case 1:
            return TakingInfoRaw(times: doseTimes(times, defaultUnit: defaultUnit))
        case 2:
            return TakingInfoRaw(
                times: doseTimes(times, defaultUnit: defaultUnit),
                cycleUnit: cycleUnit == 2 ? 2 : 1,
                cycleUseTimes: max(cycleUseTimes ?? 1, 1),
                cycleStopTimes: max(cycleStopTimes ?? 1, 1)
            )
        case 3:
            return TakingInfoRaw(
                sun: doseTimes(sun, defaultUnit: defaultUnit),
                mon: doseTimes(mon, defaultUnit: defaultUnit),
                tue: doseTimes(tue, defaultUnit: defaultUnit),
                wed: doseTimes(wed, defaultUnit: defaultUnit),
                thu: doseTimes(thu, defaultUnit: defaultUnit),
                fri: doseTimes(fri, defaultUnit: defaultUnit),
                sat: doseTimes(sat, defaultUnit: defaultUnit)
            )
        case 4:
            return TakingInfoRaw(
                times: doseTimes(times, defaultUnit: defaultUnit),
                intervalDays: max(intervalDays ?? 2, 2)
            )
        default:
            return nil
        }
    }

    private func doseTimes(_ list: [MedicineOcrDoseTimeDTO]?, defaultUnit: String) -> [DoseTime]? {
        guard let list, !list.isEmpty else { return nil }
        return list.map { $0.asDoseTime(defaultUnit: defaultUnit) }
    }
}

// MARK: - OCR 识别出的单个服药时间点
struct MedicineOcrDoseTimeDTO: Decodable {
    var time: String?
    var doseUnit: String?
    var doseAmount: Double?

    private enum CodingKeys: String, CodingKey {
        case time, doseUnit, doseAmount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        time = container.ocrString(forKey: .time)
        doseUnit = container.ocrString(forKey: .doseUnit)
        doseAmount = container.ocrDouble(forKey: .doseAmount)
    }

    func asDoseTime(defaultUnit: String) -> DoseTime {
        let unit = doseUnit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return DoseTime(
            time: Self.normalizedTime(time),
            doseUnit: unit.isEmpty ? defaultUnit : unit,
            doseAmount: max(doseAmount ?? 1, 0.01)
        )
    }

    /// 统一成 HH:mm；无法解析时使用 09:00。
    static func normalizedTime(_ raw: String?) -> String {
        guard let raw else { return "09:00" }
        let text = raw
            .replacingOccurrences(of: "：", with: ":")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = text.split(separator: ":")
        if parts.count >= 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
           (0...23).contains(hour), (0...59).contains(minute) {
            return String(format: "%02d:%02d", hour, minute)
        }
        return "09:00"
    }
}

// MARK: - 转成用药计划
extension MedicineOcrItemDTO {
    /// 转换为可直接保存或进入编辑页的用药计划；缺少药品名称时返回 nil。
    func asMedicinePlan(
        valueScopes: [String: ValueScopeInfo],
        medicineFormUnits: [String: [String]]
    ) -> UsersMedicinePlanDTO? {
        let name = medicineName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty else { return nil }

        let rawForm = trimmed(medicineForm)
        let formScope = valueScopes["medicineForm"]?.valueScope ?? []
        // 值域已加载时校验剂型编码，避免把模型编造的编码写入计划。
        let form: String? = {
            guard let rawForm else { return nil }
            return formScope.isEmpty || formScope.contains(where: { $0.value == rawForm }) ? rawForm : nil
        }()
        let formDescription = form.flatMap { valueScopes["medicineForm"]?.desc(forValue: $0) }
        let defaultUnit = formDescription.flatMap { medicineFormUnits[$0]?.first } ?? "片"

        var frequency = Int16(min(max(frequencyType ?? 1, 1), 5))
        var takingInfo = takingInfo?.asTakingInfoRaw(frequencyType: frequency, defaultUnit: defaultUnit)

        // 频次为 5 时无需服药时间；其余频次缺少时间则回退为每天 09:00。
        if frequency == 5 {
            takingInfo = nil
        } else if !Self.hasSchedule(takingInfo, frequency: frequency) {
            frequency = 1
            takingInfo = TakingInfoRaw(times: [DoseTime(time: "09:00", doseUnit: defaultUnit, doseAmount: 1)])
        }

        let start = Self.normalizedDate(startDate) ?? Self.todayString
        var end = Self.normalizedDate(endDate)
        if let endDate = end, endDate < start {
            end = nil
        }

        return UsersMedicinePlanDTO(
            medicineName: name,
            medicineForm: form,
            specification: trimmed(specification),
            specificationUnit: trimmed(specificationUnit),
            frequencyType: frequency,
            takingInfo: takingInfo,
            startDate: start,
            endDate: end,
            sourceType: Int16(min(max(sourceType ?? 3, 1), 3)),
            medicalAdvice: trimmed(medicalAdvice)
        )
    }

    private func trimmed(_ value: String?) -> String? {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }

    private static func hasSchedule(_ info: TakingInfoRaw?, frequency: Int16) -> Bool {
        guard let info else { return false }
        if frequency == 3 {
            return [info.sun, info.mon, info.tue, info.wed, info.thu, info.fri, info.sat]
                .contains { $0?.isEmpty == false }
        }
        return info.times?.isEmpty == false
    }

    private static var todayString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = DateUtils.DateFormat.ymd
        return formatter.string(from: Date())
    }

    /// 仅接受 yyyy-MM-dd / yyyy/M/d，其余视为未识别。
    private static func normalizedDate(_ value: String?) -> String? {
        guard let value else { return nil }
        let text = value
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ".", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = DateUtils.DateFormat.ymd
        guard let date = input.date(from: text) else { return nil }

        let output = DateFormatter()
        output.locale = Locale(identifier: "en_US_POSIX")
        output.dateFormat = DateUtils.DateFormat.ymd
        return output.string(from: date)
    }
}

// MARK: - OCR 返回内容清理
enum MedicineOcrParser {
    /// 去除可能包裹 JSON 的 markdown 代码围栏及首尾空白。
    static func stripCodeFence(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            if let firstLineEnd = text.firstIndex(of: "\n") {
                text = String(text[text.index(after: firstLineEnd)...])
            } else {
                text = text.replacingOccurrences(of: "```", with: "")
            }
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasSuffix("```") {
            text = String(text.dropLast(3))
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - 宽松解码辅助
private extension KeyedDecodingContainer {
    func ocrString(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value == value.rounded() ? String(Int(value)) : String(value)
        }
        return nil
    }

    func ocrInt(forKey key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    func ocrDouble(forKey key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}
