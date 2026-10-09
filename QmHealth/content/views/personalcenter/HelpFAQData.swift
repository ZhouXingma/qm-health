//
//  HelpFAQData.swift
//  QmHealth
//
//  帮助与反馈 - 常见问题数据
//

import SwiftUI

struct FAQItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

struct FAQCategory: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let tint: Color
    let items: [FAQItem]
}

enum HelpFAQData {

    static let categories: [FAQCategory] = [

        // MARK: - 基础使用
        FAQCategory(
            icon: "person.crop.circle.fill",
            title: "基础使用",
            tint: .blue,
            items: [
                FAQItem(
                    question: "QmHealth 是一款什么样的应用？",
                    answer: "QmHealth 是一款面向个人健康管理的客户端应用，支持用药提醒、健康记录、检查报告管理、AI 健康问答等功能。开发者不提供、不运营任何公共网络服务，所有数据均由您自行掌控。"
                ),
                FAQItem(
                    question: "如何注册账号？",
                    answer: "打开应用后，在登录页底部点击「注册」标签，依次输入账号（手机号或邮箱）、密码、确认密码，勾选同意《用户协议》与《隐私政策》后点击「注册」即可。请使用您常用的联系方式，方便后续找回账号。"
                ),
                FAQItem(
                    question: "忘记密码怎么办？",
                    answer: "由于本应用采用自部署模式，您的账号信息保存在您自己部署的服务端。请通过您部署服务端时配置的密码找回流程（邮件验证码、找回链接等）进行处理。如您忘记了服务端管理密码，请联系您所在环境的运维负责人。"
                ),
                FAQItem(
                    question: "如何添加家人账号？",
                    answer: "在「我的」页面点击「切换账号」，进入账号管理页面后点击「添加新账号」卡片。可以为家人创建全新的账号，也可以让家人登录已有的账号。添加成功后，账号会出现在「其他账号」列表中，点击对应卡片即可切换。"
                ),
                FAQItem(
                    question: "支持多少个家人账号？",
                    answer: "在您部署的服务端能力范围内，您可以管理任意数量的账号。具体上限取决于您服务端所部署的设备性能与存储配置。"
                ),
                FAQItem(
                    question: "账号之间数据互通吗？",
                    answer: "默认情况下不同账号的数据相互隔离，确保每个人只能看到自己的健康信息。如您希望为家人代为管理健康档案，请使用对应的家人账号登录查看。"
                )
            ]
        ),

        // MARK: - 部署与服务
        FAQCategory(
            icon: "server.rack",
            title: "部署与服务",
            tint: .orange,
            items: [
                FAQItem(
                    question: "为什么我需要自己部署服务端？",
                    answer: "QmHealth 是一款客户端软件，不运营、不提供任何公共网络服务。您需要自行准备并部署配套的服务端（可部署在个人电脑、家庭服务器、私有云或局域网设备上），客户端才能完成账号、健康记录的同步与 AI 调用等全部功能。"
                ),
                FAQItem(
                    question: "如何部署服务端？",
                    answer: "请前往 QmHealth 官方仓库的服务端项目（qmhealth-server），按照 README 中的部署说明进行操作。常见方式包括：Docker 一键部署、docker Compose 编排部署，或直接在 Linux/macOS 主机上以进程方式运行。"
                ),
                FAQItem(
                    question: "如何配置客户端连接到我部署的服务端？",
                    answer: "首次启动客户端时，应用会引导您配置服务端地址。请填入您部署的服务端可访问的 URL（如 http://192.168.1.100:8080），并完成联通性测试。后续如需更换，可在「通用设置」中修改。"
                ),
                FAQItem(
                    question: "服务端需要什么样的硬件配置？",
                    answer: "仅做账号与健康记录管理时，一台树莓派、旧笔记本或入门级云服务器即可流畅运行。若同时部署本地 AI 模型，建议使用配备 Apple Silicon、NVidia GPU 或充足内存（≥16GB）的设备。"
                ),
                FAQItem(
                    question: "服务端必须暴露在公网吗？",
                    answer: "不一定。如果您和家人都处于同一局域网，仅在局域网内提供服务即可，更加安全。如需在异地访问，建议通过 VPN、ZeroTier、Tailscale 等组网方案回到局域网，避免将服务端直接暴露在公网。"
                ),
                FAQItem(
                    question: "服务端出现故障怎么办？",
                    answer: "请先确认服务端进程是否正常运行、磁盘空间是否充足、网络端口是否可达。客户端在网络异常时会给出明确的错误提示，根据提示排查即可。如服务端数据丢失，请使用您事先创建的备份进行恢复。"
                )
            ]
        ),

        // MARK: - 数据与隐私
        FAQCategory(
            icon: "lock.shield.fill",
            title: "数据与隐私",
            tint: .red,
            items: [
                FAQItem(
                    question: "我的健康数据保存在哪里？",
                    answer: "您录入的全部健康数据均保存在您自己部署的服务端，以及当前登录设备上。本应用不提供、不运营任何云端数据库，开发者也无法获取这些数据。"
                ),
                FAQItem(
                    question: "开发者会看到我的数据吗？",
                    answer: "不会。本应用客户端不包含任何向开发者域名的数据上报逻辑；服务端又是由您自己部署的，开发者无从访问。这意味着您的健康数据完全处于您本人掌控之下。"
                ),
                FAQItem(
                    question: "如何备份我的数据？",
                    answer: "推荐两种方式：(1) 在服务端定期备份数据库文件（SQLite/PostgreSQL/MySQL 均可按常规方式备份）；(2) 使用应用内的「导出健康记录」功能，将数据导出为通用 JSON/CSV 文件保存到您信任的存储介质。"
                ),
                FAQItem(
                    question: "如何彻底删除我的数据？",
                    answer: "(1) 在「我的」-「切换账号」中删除某个本地缓存的账号；(2) 在服务端管理界面中删除该账号的全部记录；(3) 在服务端主机上直接清空或销毁数据库；(4) 卸载客户端以删除本地缓存。以上操作均不可逆，请确认前先备份。"
                ),
                FAQItem(
                    question: "传输过程中数据会被截获吗？",
                    answer: "如您启用了 HTTPS（强烈推荐），客户端与服务端之间的通信将经过 TLS 加密，第三方无法在传输过程中读取内容。如您仅使用 HTTP，建议至少限制为局域网访问。"
                ),
                FAQItem(
                    question: "本地缓存的数据包含哪些内容？",
                    answer: "本地缓存仅包含登录令牌（保存在 iOS Keychain 中）、界面偏好设置（主题、语言等）以及最近浏览过的少量健康记录摘要。您可以随时在「通用设置」中清除本地缓存。"
                )
            ]
        ),

        // MARK: - AI 与模型
        FAQCategory(
            icon: "brain.head.profile",
            title: "AI 与模型",
            tint: .purple,
            items: [
                FAQItem(
                    question: "AI 健康问答是怎么工作的？",
                    answer: "当您主动发起一次 AI 健康问答时，客户端会将您的请求发送至您部署的服务端。服务端根据您的配置，选择调用本地部署的开源模型，或调用您配置的云端 API，将回答结果返回给客户端。整个过程中，开发者不参与数据传输或留存。"
                ),
                FAQItem(
                    question: "支持哪些 AI 模型？",
                    answer: "服务端兼容 OpenAI 协议，因此支持所有兼容该协议的模型来源，包括但不限于：OpenAI、Anthropic、DeepSeek、智谱 GLM、月之暗面 Kimi、Mistral、Qwen 等云端 API；以及通过 Ollama、LM Studio、vLLM 等框架本地运行的任意开源模型。"
                ),
                FAQItem(
                    question: "如何切换 AI 模型？",
                    answer: "在「通用设置」-「AI 模型配置」中，可以切换不同的模型来源、修改 API 地址、调整 Temperature、最大 Token 数等参数。配置修改后立即生效，无需重启。"
                ),
                FAQItem(
                    question: "AI 回答的医学建议可靠吗？",
                    answer: "不可靠。AI 健康问答仅供您参考，不能替代医生面诊、临床检查或专业医疗建议。请勿将 AI 回答作为诊断或治疗依据。任何与健康相关的决策，请咨询专业医生。"
                ),
                FAQItem(
                    question: "调用云端 API 时，我的健康数据会被服务商看到吗？",
                    answer: "如果您在服务端选择了调用云端 API，那么您自部署的服务端会向该服务商发送 AI 请求内容。是否、如何处理这些数据，完全由该服务商决定，与本应用和本应用开发者无关。请您在选择服务商前仔细阅读其隐私政策。"
                ),
                FAQItem(
                    question: "可以完全离线使用 AI 功能吗？",
                    answer: "可以。只需要在服务端部署本地开源模型（如通过 Ollama 运行 Llama、Qwen 等），即可实现完全离线的 AI 健康问答，不会有任何数据离开您的部署环境。"
                )
            ]
        ),

        // MARK: - 功能使用
        FAQCategory(
            icon: "heart.text.square.fill",
            title: "功能使用",
            tint: .pink,
            items: [
                FAQItem(
                    question: "如何记录一条健康数据？",
                    answer: "在首页对应模块（如用药、体征、就诊记录等）选择「添加」按钮，按提示填写必要信息后保存即可。每条记录都支持后续编辑、补充备注与删除。"
                ),
                FAQItem(
                    question: "如何导入已有的检查报告？",
                    answer: "在「健康档案」-「报告单」模块点击「添加报告单」，可以选择拍照、从相册导入或从文件选择器导入已有的检查报告图片。导入后您可以为报告补充诊断结论、就诊信息等文字内容。"
                ),
                FAQItem(
                    question: "用药提醒不生效怎么办？",
                    answer: "请检查：(1) 是否在系统设置中授予了本应用的「通知」权限；(2) 是否开启了「专注模式」或「免打扰」将通知屏蔽；(3) 是否在「用药设置」中开启了对应药品的提醒开关。三者均确认后提醒即可正常触发。"
                ),
                FAQItem(
                    question: "可以导出我的健康记录吗？",
                    answer: "可以。在「通用设置」-「数据导出」中，可以将您的健康记录导出为 JSON 或 CSV 格式，方便您备份、迁移或与其他工具配合使用。"
                ),
                FAQItem(
                    question: "支持深色模式吗？",
                    answer: "支持。QmHealth 完整适配了 iOS 系统的浅色与深色模式。在「显示设置」中可以选择「跟随系统」「始终浅色」「始终深色」三种模式。"
                )
            ]
        ),

        // MARK: - 故障排查
        FAQCategory(
            icon: "wrench.and.screwdriver.fill",
            title: "故障排查",
            tint: .gray,
            items: [
                FAQItem(
                    question: "登录时提示「无法连接服务器」怎么办？",
                    answer: "请按以下顺序排查：(1) 检查您的设备是否处于可联网状态；(2) 在「通用设置」中确认服务端地址是否正确；(3) 在浏览器中直接访问该地址，确认服务端是否正常运行；(4) 如服务端使用自签名证书，请在系统设置中信任该证书。"
                ),
                FAQItem(
                    question: "登录时提示「账号或密码错误」怎么办？",
                    answer: "请确认账号与密码输入无误，注意区分大小写。如确实遗忘，请通过服务端配置的密码找回流程进行处理。如反复出现此提示但密码正确，可能是服务端数据库出现异常，请联系您的运维人员排查。"
                ),
                FAQItem(
                    question: "AI 健康问答无响应怎么办？",
                    answer: "请先确认：(1) 服务端配置中 AI 模型已正确启用；(2) 模型 API 地址、API Key 填写正确；(3) 如使用云端 API，对应服务商账户有可用额度；(4) 如使用本地模型，模型文件已正确下载、显存充足。"
                ),
                FAQItem(
                    question: "切换账号后看不到之前的数据怎么办？",
                    answer: "请确认您是否切换到了正确的账号。如账号正确但数据仍缺失，可能是：(1) 切换前的账号数据存储在另一台设备或服务端，尚未同步；(2) 服务端数据被删除。请使用服务端管理后台确认数据状态。"
                ),
                FAQItem(
                    question: "应用闪退或卡顿怎么办？",
                    answer: "请尝试以下步骤：(1) 强制退出应用后重新打开；(2) 在「通用设置」中清除本地缓存；(3) 重启您的设备；(4) 如仍有问题，请通过应用内反馈入口上报日志与故障描述。"
                )
            ]
        )
    ]
}