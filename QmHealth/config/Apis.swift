//
//  Apis.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/2/27.
//

let BASIC_URL = ApiConfig.defaultBasicUrl
let AI_BASIC_URL = ApiConfig.defaultAiUrl
// MARK: - 值域
let VALUE_SCOPE_LIST = "/api/valuescope/list"

// MARK: - 用户相关
let USER_REGISTER = "/public/users/register"
let USER_LOGIN = "/public/users/login"
let USER_GET = "/api/users/get"
let USER_UPATE = "/api/users/update"
let USER_LOGOUT = "/api/users/logout"

let USER_TAG_LIST = "/api/users/tag/list"
let USER_TAG_SAVE = "/api/users/tag/saveorppdate"


// MARK: - 文件操作相关
let FILE_UPLOAD = "/api/files/upload"
let FILE_LOAD = "/api/files/load"

// MARK: - 疾病信息
let DISEASE_SAVEORUPDATE = "/api/users/disease/saveorupdate"
let DISEASE_LIST_NOT_RECOVERED = "/api/users/disease/list_not_recovered"
let DISEASE_PAGE = "/api/users/disease/page"
let DISEASE_DELETE = "/api/users/disease/delete"

// MARK: - 过敏源
let ALLERGY_SAVEORUPDATE = "/api/users/allergy/saveorupdate"
let ALLERGY_LIST = "/api/users/allergy/list"
let ALLERGY_DELETE = "/api/users/allergy/delete"

// MARK: - 过敏记录
let ALLERGY_RECORDS_PAGE = "/api/users/allergyrecords/page"
let ALLERGY_RECORD_SAVEORUPDATE = "/api/users/allergyrecords/saveorupdate"
let ALLERGY_RECORD_DELETE = "/api/users/allergyrecords/delete"

// MARK: - 指标信息
let HEALTH_INDICATOR_LAST_STATUS = "/api/users/healthindicator/last_status"
let HEALTH_INDICATOR_LAST = "/api/users/healthindicator/last"
let HEALTH_INDICATOR_PAGE = "/api/users/healthindicator/page"
let HEALTH_INDICATOR_ADD = "/api/users/healthindicator/add"
let HEALTH_INDICATOR_DELETE = "/api/users/healthindicator/delete"
let HEALTH_INDICATOR_META_LIST = "/api/sys/healthindicator/json"
let HEALTH_INFICATOR_CONFIG = "/api/sys/healthindicator/config"

// MARK: - 健康曲线
let HEALTH_CURVE_SAVE = "/api/users/healthcurveplan/save"
let HEALTH_CURVE_GET = "/api/users/healthcurveplan/get"

// MARK: - 元数据操作
let METADATA_RECORD_ADD = "/api/users/metadata/record/add"
let METADATA_RECORD_LATEST = "/api/users/metadata/record/latest"
let METADATA_ADD_UPDATE = "/api/users/metadata/addorupdate"
let METADATA_DELETE = "/api/users/metadata/delete"
let METADATA_GETBYCODE = "/api/users/metadata/getbycode"
let METADATA_ALLLASTED = "/api/users/metadata/alllatest"

// MARK: - 饮水记录
let WATER_INTAKE_LISTBYDATE = "/api/users/waterintake/listbydate"
let WATER_INTAKE_SAVE = "/api/users/waterintake/save"
let WATER_INTAKE_DELETE = "/api/users/waterintake/delete"

// MARK: - 用药记录
let MEDICINE_TAKE_SAVE = "/api/users/medicine/save"
let MEDICINE_TAKE_LIST_BY_DATE = "/api/users/medicine/listbydate"
let MEDICINE_TAKE_DELETE = "/api/users/medicine/delete"
let MEDICINE_TAKE_HISTORY = "/api/users/medicine/listrecentcommonmedicines"
let MEDICINE_TAKE_LIST_DATES_BY_MONTH = "/api/users/medicine/listdatesbymonth"

// MARK: - 用药计划
let MEDICINE_PLAN_FORM_UNITS = "/api/users/medicineplan/medicineFormUnits"
let MEDICINE_PLAN_ADD = "/api/users/medicineplan/add"
let MEDICINE_PLAN_UPDATE = "/api/users/medicineplan/update"
let MEDICINE_PLAN_DETAIL = "/api/users/medicineplan/detail"
let MEDICINE_PLAN_DELETE = "/api/users/medicineplan/delete"
let MEDICINE_PLAN_LIST = "/api/users/medicineplan/list"
let MEDICINE_PLAN_PAGE = "/api/users/medicineplan/page"
let MEDICINE_PLAN_TODAY = "/api/users/medicineplan/today"

// MARK: - 就诊记录
let MEDICALVISIT_ADD = "/api/users/medicalvisit/add"
let MEDICALVISIT_UPDATE = "/api/users/medicalvisit/update"
let MEDICALVISIT_DELETE = "/api/users/medicalvisit/delete"
let MEDICALVISIT_DETAIL = "/api/users/medicalvisit/detail"
let MEDICALVISIT_PAGE = "/api/users/medicalvisit/page"
let MEDICALVISIT_UPDATE_STATUS = "/api/users/medicalvisit/updatestatus"
let MEDICALVISIT_PAGE_BY_DISEASE = "/api/users/disease/page_medical_visits_by_disease"

// MARK: - 就诊报告
let MEDICAL_REPORT_PAGE = "/api/users/medicalreport/page"

// MARK: - 用户配置
let SYS_USER_CONFIG_GET_BY_USER_ID = "/api/sys/userconfig/getbyuserid"
let SYS_USER_CONFIG_SAVE_OR_UPDATE = "/api/sys/userconfig/saveorupdate"

// MARK: - 系统公共配置（含 AI 服务商默认配置）
let SYS_CONFIG_LIST_BY_CODE = "/public/sys/config/listbycode"
let SYS_CONFIG_SAVE = "/public/sys/config/save"

// MARK: - 用户模型配置（已配置的 AI 模型列表）
let USERS_MODEL_CONFIG_LIST = "/api/users/modelconfig/list"
let USERS_MODEL_CONFIG_ADD = "/api/users/modelconfig/add"
let USERS_MODEL_CONFIG_UPDATE = "/api/users/modelconfig/update"
let USERS_MODEL_CONFIG_DELETE = "/api/users/modelconfig/delete"
let USERS_MODEL_CONFIG_GET_BY_ID = "/api/users/modelconfig/getbyid"

// MARK: - 每日健康任务
let DAILY_TASK_LIST = "/api/users/dailytask/list"
let DAILY_TASK_SAVE_OR_UPDATE = "/api/users/dailytask/saveorupdate"
let DAILY_TASK_YEARLY_STATS = "/api/users/dailytask/yearlystats"
let DAILY_TASK_MONTHLY_STATS = "/api/users/dailytask/monthlystats"

// MARK: - 消息通知
let MESSAGE_UNREAD_COUNT = "/api/sys/message/unreadcount"
let MESSAGE_PAGE = "/api/sys/message/page"
let MESSAGE_READ_ALL = "/api/sys/message/readall"
let MESSAGE_READ = "/api/sys/message/read"
let MESSAGE_BATCH_DELETE = "/api/sys/message/batchdelete"

// MARK: - AI 聊天
let AI_CHAT_COMPLETIONS = "/ai/chat/completions/v1"
let AI_CHAT_HISTORY = "/ai/chat/history"
let AI_CHAT_DETAIL = "/ai/chat/detail"
let AI_CHAT_BATCH_DELETE = "/ai/chat/batchdelete"
let AI_CHAT_INTERRUPT = "/ai/chat/interrupt"
let AI_CHAT_OCR = "/ai/chat/ocr"

// 获取api地址
func apiUrl(_ urlStr: String) -> String {
    return ApiConfig.currentBasicUrl + urlStr;
}

func aiUrl(_ urlStr: String) -> String {
    return ApiConfig.currentAiUrl + urlStr;
}
