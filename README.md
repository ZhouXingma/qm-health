# 青木健康 iOS 客户端

青木健康（QmHealth）是一款个人 / 家庭的健康管理 App，覆盖**健康档案、健康指标、健康曲线、就诊记录、用药管理与 AI 问诊**等场景。客户端使用 SwiftUI 编写，界面采用 iOS 26 的原生液态玻璃（Liquid Glass）风格，配合自研的弥散渐变背景、玻璃卡片与自绘图表，形成统一的视觉体系。

---

## 一、项目概览

| 项目 | 说明 |
| --- | --- |
| 应用名 / Bundle ID | 青木健康 / `cn.woodpoles.QmHealth` |
| 开发平台 | iOS，最低版本 **iOS 26.0**（App target），工程级 `IPHONEOS_DEPLOYMENT_TARGET = 18.2` |
| 语言 / UI 框架 | Swift 5、SwiftUI |
| 界面风格 | iOS 26 原生 `.glassEffect`（液态玻璃）+ 自研设计令牌 |
| 第三方依赖 | [Alamofire](https://github.com/Alamofire/Alamofire) ≥ 5.10.2（网络）、[SwiftMath](https://github.com/mgriebling/SwiftMath) ≥ 1.7.3（LaTeX 公式渲染） |
| 代码规模 | 约 244 个 Swift 文件、6.5 万行 |
| 设备 | iPhone / iPad（`TARGETED_DEVICE_FAMILY = 1,2`） |
| 版本 | 1.0 |

### 运行环境

- Xcode 26 及以上（依赖 iOS 26 的 `Tab(role:)`、`.glassEffect` 等 API）
- Swift Package Manager 管理依赖，首次打开工程会自动拉取 Alamofire 与 SwiftMath
- 需要本地或内网已启动的后端服务（默认 `http://127.0.0.1:8080`）

### 快速开始

1. 用 Xcode 打开 `QmHealth.xcodeproj`，等待 SPM 依赖解析完成。
2. 在「编辑 Scheme」中确认运行设备，直接 `⌘R` 运行。
3. 首次启动进入登录页；若后端地址不是默认值，可在**登录页的「请求地址」入口**或登录后的**通用设置 → 请求地址**中修改。

---

## 二、目录结构

```
QmHealth/
├── QmHealthApp.swift          # @main 入口，注入主题
├── ContentView.swift          # 按登录态路由到 Login / 初始建档 / 主界面
├── Info.plist
├── config/                    # 配置：接口地址、接口清单、常量、请求头常量
│   └── consts/
├── content/                   # 业务内容
│   ├── components/            # 系统级公共组件
│   │   ├── charts/            # 自绘折线图
│   │   ├── common/            # 通用 UI 组件（日历、进度、Markdown、导航等）
│   │   ├── flow/              # 水平/垂直流式布局
│   │   ├── pop/               # 全局弹窗
│   │   ├── subpop/            # Sheet 内作用域子弹层
│   │   └── style/             # 设计令牌 + 液态玻璃样式
│   ├── models/                # 仅页面级模型（如 MedicalVisitDiseaseParam）
│   └── views/                 # 业务页面
│       ├── common/            # 主框架：Index、登录、初始建档、公共业务组件
│       ├── home/              # 首页及其子模块（AI、健康曲线、指标、档案、饮水）
│       ├── medicalRecords/    # 就诊记录
│       ├── medicine/          # 用药记录与计划
│       └── personalcenter/    # 个人中心与各类设置
├── models/                    # 数据模型
│   ├── bizdtos/               # 与后端交互的 DTO
│   ├── common/                # 全局 Model、网络响应、通用扩展
│   └── enums/                 # 枚举（性别、民族、血型、疾病、健康指标等）
├── tools/                     # 业务相关工具
│   ├── apitools/              # 接口封装
│   ├── database/              # 数据库（当前未启用）
│   ├── dic/                   # 字典数据（城市）
│   ├── functions/             # 业务公共方法
│   ├── performance/           # 性能基准
│   └── storage/
├── utils/                     # 与业务无关的通用工具
└── Assets.xcassets/           # 颜色、图标、表情、人物头像等资源
```

---

## 三、应用框架与导航

应用入口 [QmHealthApp.swift](QmHealth/QmHealthApp.swift) → [ContentView.swift](QmHealth/ContentView.swift)，按全局状态路由：

```
未登录                     → Login()                  登录 / 注册
已登录但未完成建档         → InitialProfileSetupView() 首次填写基本信息
已登录且已建档             → Index()                  主界面
```

主界面 [Index.swift](QmHealth/content/views/common/index/Index.swift) 为原生 `TabView`，共 5 个 Tab：

| Tab | 图标 | 页面 | 说明 |
| --- | --- | --- | --- |
| 首页 | `house.fill` | `Home()` | 档案概览、每日任务、健康曲线、饮水、指标 |
| 就诊 | `heart.text.clipboard.fill` | `MedicalRecordsView()` | 就诊记录、就诊提醒、就诊报告 |
| 用药 | `pill.fill` | `MedicineMainView()` | 用药记录与用药计划 |
| 个人 | `person.fill` | `PersonalCenter()` | 资料、账号、显示 / 通用设置、帮助反馈 |
| AI | `sparkles.2` | `AiChatMain()` | 以 `role: .prominent` 突出的中部按钮，进入全屏聊天 |

另有一套自研的液态玻璃底栏 `SubBar2`（首页等页面复用）。

### 全局状态与单例

| 对象 | 位置 | 职责 |
| --- | --- | --- |
| `GlobalModel.shared` | `models/common/GlobalModel.swift` | 登录态、当前用户、暗色模式、子栏显隐、待跳转的 AI 会话 ID |
| `ThemeManager.shared` | `utils/ThemeManager.swift` | 主题色与深浅外观，切换后全局即时生效 |
| `HomeRefreshBus.shared` | `utils/HomeRefreshBus.swift` | 首页刷新事件总线，子组件监听后自行刷新（如切换账号后） |
| `PopManager` / `SubPopManager` | `content/components/pop|subpop/` | 全局弹窗与 Sheet 内子弹层 |

---

## 四、功能模块

### 1. 登录与建档（`content/views/common`）

- **登录 / 注册**：登录页为双 Tab（密码登录、注册），含用户协议与隐私政策页面。未登录状态下也可进入「请求地址」修改后端地址，方便联调。
- **初始建档**：首次登录后填写姓名、性别、生日并上传头像，完成后才进入主界面。

### 2. 首页（`content/views/home`）

首页是一个可下拉刷新的聚合页，由若干卡片组成：

- **患者档案头**：基本信息 / 疾病 / 过敏 三个分页，含档案完整度提示。
- **每日健康任务**：当日待办与打卡。
- **健康曲线**：BMI、腰臀比、身高、体重、腰围、臀围等趋势概览，可进入单项详情；支持**AI 生成减重 / 健康管理计划**（流式生成，含保守 / 均衡 / 激进三档方案）。
- **饮水打卡**：当日饮水量进度与记录，可设置目标、补录记录。
- **健康指标**：指标列表、搜索、分类与增删改查。
- **消息通知**：顶部入口与未读徽标，点击可跳转到对应的 AI 会话。
- **患者档案详情**（`home/person`）：基本信息、疾病史（筛选 + 分页）、过敏史、家族史、档案信息及其编辑页。

### 3. AI 问诊（`content/views/home/ai`）

应用的核心模块，基于 SSE 的流式对话：

- **流式渲染**：服务端事件协议 `RUN_STARTED / THINKING / TOOL_CALL / TEXT / TOOL_RESULT / RUN_FINISHED / PERMISSION_ASKING`，按 `runId` 分组渲染；支持中断（`AI_CHAT_INTERRUPT`）与历史会话恢复。
- **文本节奏控制**：`StreamingTextPacer` + `ChatStreamAccumulator` 将「数据到达节奏」与「渲染节奏」解耦，Markdown 逐字呈现；数学公式由 SwiftMath 渲染 LaTeX。
- **多模态输入**：多行文本、图片（最多 5 张）、**拍照**（AVFoundation，含裁剪与马赛克编辑）、**语音输入**（`SFSpeechRecognizer` 实时转写）、文件上传。
- **工具调用与推理**：推理链展示、工具授权确认条、`ask_user` 交互式追问、模型配置管理。
- **历史会话**：分页加载，运行中的会话轮询刷新。

### 4. 就诊记录（`content/views/medicalRecords`）

三个分页：**就诊记录**、**就诊提醒**（可确认已就诊）、**就诊报告**（按就诊聚合的时间线，PDFKit 预览）。支持按年份分组与分页。

新建 / 编辑就诊记录时可填写医院、科室、医生、诊断、症状、小结，上传报告文件（照片 / PDF），支持 **OCR 识别**与**语音录入**，并可关联用药计划。当某次就诊有多个诊断时，会进入疾病选择页。

### 5. 用药管理（`content/views/medicine`）

- **用药记录**：日历标记 + 当日用药情况，可补录。
- **用药计划**：搜索与计划卡片；新增计划支持剂型、规格、服药频率（每天 / 循环 / 每隔 N 天）、服药时间点、来源与医嘱，并对同名药品给出候选提示。可从就诊记录页以「草稿模式」新建。

### 6. 个人中心（`content/views/personalcenter`）

资料编辑、多账号切换与添加、显示设置（主题，走 `ThemeManager`）、通用设置（AI 模型、请求地址、自动创建每日任务）、帮助与反馈（FAQ）。退出登录会在服务端确认成功后才切换本地账号状态。

---

## 五、基础设施

### 网络层

统一的请求封装 [BgResultNetWorkUtils.swift](QmHealth/utils/BgResultNetWorkUtils.swift)，基于 Alamofire，链式调用：

```swift
BgResultNetWork.post(apiUrl(USER_GET), params: param)
    .complicationHand { data in /* 成功 */ }
    .errorHandle { result, error in /* 失败 */ }
    .finalHandleFunc { result in /* 结束 */ }
    .responseDecodable()
```

- 统一响应结构 `BgResult<T>`（`code` / `message` / `data`），仅当 `code == 200` 走成功回调。
- 统一请求头（`token` / `Accept` / `Accept-Encoding`）由 `buildHeader()` 注入。
- **401 全局处理**：自动提示登录失效、清 token 并重置为未登录态。
- 错误被归一化为 `BgResultNetWorkError`（超时 / 网络 / 参数 / 解析 / HTTP / 校验等），未指定 `errorHandle` 时默认弹窗提示。
- 默认请求超时 5 秒；禁用本地缓存（`reloadIgnoringLocalAndRemoteCacheData`）。

### AI 流式链路

`utils/SSEClient.swift` 基于 `URLSession` + `URLSessionDataDelegate` 手写 SSE 客户端（事件解析、连接状态、自动重连），`tools/apitools/SseApi.swift` 负责装配请求与回调，供 AI 问诊与 AI 计划生成复用。

### 接口配置

后端地址为**动态配置**，持久化在 `UserDefaults`，修改后无需重启进程即刻生效（[ApiConfig.swift](QmHealth/config/ApiConfig.swift)）：

| 配置项 | 默认值 | 用途 |
| --- | --- | --- |
| 业务 API | `http://127.0.0.1:8080` | 用户、档案、指标、就诊、用药等业务接口 |
| 智能体 API | `http://127.0.0.1:8082` | AI 对话与流式接口 |

接口清单集中在 [Apis.swift](QmHealth/config/Apis.swift)，按业务域用 `// MARK:` 分组；URL 通过 `apiUrl(path)` / `aiUrl(path)` 拼接。

> **注意**：默认地址为 `http://`，依赖 ATS 对回环地址的豁免。若改为**非本机**的 http 地址（内网 / 局域网），需要在工程中补充 App Transport Security 例外配置。

### 主题与设计系统

- **主题色**：`ThemeManager` 提供 5 套主题色（经典橙 / 苹果蓝 / 薄荷绿 / 苹果绿 / 葡萄紫），每套含主色、辅色与图表色（各有亮 / 暗变体）；外观支持跟随系统 / 浅色 / 深色。颜色经 `Color.theme(_:)` 动态解析，切换后全局生效。
- **液态玻璃**：`content/components/style/commViewStyle.swift` 统一封装 iOS 26 原生 `.glassEffect`（`appGlass` / `glassCardStyle` / `glassPill` 等语义样式；玻璃效果常驻开启），并集中定义间距、圆角、高度、阴影、颜色等设计令牌。
- **通用组件**（`content/components/common/`）：日历、卡尺式刻度选择、日期 / 月 / 年导航、日期范围与时间选择、胶囊分段选择器、环形 / 线性 / 半圆进度、弥散渐变背景、头像选择、Markdown 渲染、AI「思考中」波波动画等。
- **图表**：`charts/` 下为自绘的可滚动折线图（单序列 / 多序列），未使用系统 Charts。

### 数据与本地存储

| 存储 | 用途 |
| --- | --- |
| Keychain | 登录 token（service `com.qmhealth`，按账号区分） |
| UserDefaults | 后端地址、主题、当前账号与多账号列表、暗色模式等偏好设置 |
| Documents 目录 | 头像、报告等本地文件（`UIFileSharingEnabled`，可在「文件」App 中访问） |

> 本地数据库当前**未启用**：`tools/database/DatabaseManager.swift` 整体处于注释状态，SQLite 相关代码未接入，数据以服务端为准。

---

## 六、项目约定

- **与后端保持一致的字段拼写**：接口常量或响应结构中若存在后端拼写错误（如 `USER_UPATE`、`USER_TAG_SAVE = ".../saveorppdate"`、`HEALTH_INFICATOR_CONFIG`），客户端**原样保留、不做修正或兜底**，由后端修正。
- **页面背景**：弥散渐变等动画背景仅用于底部 4 个主 Tab 页面，其余页面使用纯色背景。
- **玻璃效果**：使用 `.appGlass` 前先 `.fill(Color.clear)`，避免玻璃 tint 染色异常。
- **修改后编译验证**：修改 Swift 代码后需编译通过再交付。
