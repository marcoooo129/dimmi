// 翻译服务：Anthropic + OpenAI 双引擎，统一返回 Result<TranslationResult, TranslationError>。
//
// 关键决策：
//   - 强制 JSON 输出：system prompt 里明确「只返回 JSON，不要任何前后缀、不要 markdown 代码块」
//   - 解析稳健性：模型偶尔会包 ```json 围栏或多余文字，先剥围栏再 decode
//   - 15s 超时：避免 hang 住浮层
//   - 错误分类：UI 上要分「请填 API Key」「网络问题」「模型返回异常」分别提示
//
// 阶段 10：多目标语 + 反向翻译
//   - 正向：中文（偶尔英文）→ TargetLanguage
//   - 反向：TargetLanguage → 中文
//   - 两种方向共用同一个 system prompt 模板，仅替换「外语角色」与「目标语说明」；
//     JSON 字段保持 { italian, colloquial, topic, note } 不变以兼容 Decodable。
//   - `translate(text:direction:target:)` 是入口；老 `translate(text:)` 路径
//     默认等价于正向 + 当前 AppState.targetLanguage。
import Foundation

enum TranslationError: LocalizedError {
    case missingAPIKey
    case invalidConfiguration(String)
    case network(String)
    case http(Int, String)
    case malformedResponse(String)
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:        return "未填写 API Key，请去「设置」里填上。"
        case .invalidConfiguration(let msg): return "配置无效：\(msg)"
        case .network(let msg):     return "网络异常：\(msg)"
        case .http(let code, _):    return "服务端返回 \(code)"
        case .malformedResponse(_): return "模型返回的不是合法 JSON。"
        case .emptyContent:         return "模型返回为空。"
        }
    }
}

/// 翻译方向：
///   - .forward  中文（少数情况英文） → targetLanguage
///   - .reverse  targetLanguage → 中文
enum TranslationDirection {
    case forward
    case reverse

    /// 用于 panel 文案 / 历史库 direction 字段。简短英文小写。
    var rawValue: String {
        switch self {
        case .forward: return "forward"
        case .reverse: return "reverse"
        }
    }
}

// MARK: - TargetLanguage（避免新增独立文件需要注册到 Xcode 工程）
//
// dimmi 支持的目标外语 —— 由「设置 → 翻译」切换。
//
// 每个 case 自带：
//   - rawValue     中文菜单里显示的标签
//   - nativeName   该语言自己的写法（用于浮窗 chip / 历史卡）
//   - isoCode      简短代码，写到历史库/通知里用于跨进程校验
//   - englishName  英文名，用于 system prompt 描述目标
//   - emoji        菜单栏 / chip 上的国旗
enum TargetLanguage: String, CaseIterable, Identifiable, Codable {
    case italian      = "意大利语"
    case english      = "英语"
    case french       = "法语"
    case german       = "德语"
    case spanish      = "西班牙语"
    case japanese     = "日语"
    case korean       = "韩语"
    case portuguese   = "葡萄牙语"

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .italian:    return "Italiano"
        case .english:    return "English"
        case .french:     return "Français"
        case .german:     return "Deutsch"
        case .spanish:    return "Español"
        case .japanese:   return "日本語"
        case .korean:     return "한국어"
        case .portuguese: return "Português"
        }
    }

    var isoCode: String {
        switch self {
        case .italian:    return "it"
        case .english:    return "en"
        case .french:     return "fr"
        case .german:     return "de"
        case .spanish:    return "es"
        case .japanese:   return "ja"
        case .korean:     return "ko"
        case .portuguese: return "pt"
        }
    }

    var englishName: String {
        switch self {
        case .italian:    return "Italian"
        case .english:    return "English"
        case .french:     return "French"
        case .german:     return "German"
        case .spanish:    return "Spanish"
        case .japanese:   return "Japanese"
        case .korean:     return "Korean"
        case .portuguese: return "Portuguese"
        }
    }

    var emoji: String {
        switch self {
        case .italian:    return "🇮🇹"
        case .english:    return "🇬🇧"
        case .french:     return "🇫🇷"
        case .german:     return "🇩🇪"
        case .spanish:    return "🇪🇸"
        case .japanese:   return "🇯🇵"
        case .korean:     return "🇰🇷"
        case .portuguese: return "🇵🇹"
        }
    }

    /// 用于浮窗 chip 的紧凑 label（大写 + tracking，匹配旧的 ITALIAN chip）
    var chipLabel: String {
        switch self {
        case .italian:    return "ITALIAN"
        case .english:    return "ENGLISH"
        case .french:     return "FRENCH"
        case .german:     return "GERMAN"
        case .spanish:    return "SPANISH"
        case .japanese:   return "JAPANESE"
        case .korean:     return "KOREAN"
        case .portuguese: return "PORTUGUESE"
        }
    }
}

actor TranslationService {
    static let shared = TranslationService()

    /// 阶段 10：根据方向 + 目标语构造 prompt。
    /// 正向：用户原文 = 中文（或英文）；要求把内容翻译成 <targetLanguage>。
    /// 反向：用户原文 = <targetLanguage>；要求把内容翻译成中文。
    /// JSON 字段保持 {italian, colloquial, topic, note} 不变，UI 层根据 direction
    /// 决定如何显示这两个字段。
    private static func buildSystemPrompt(direction: TranslationDirection, target: TargetLanguage) -> String {
        switch direction {
        case .forward:
            return """
            你是一位 \(target.rawValue)母语老师，服务中文母语的\(target.rawValue)初学者。
            用户给你一句或一段中文（偶尔英文）。请只返回一个 JSON 对象，不要任何解释、不要 markdown 代码块，字段如下：
            {
              "italian": "最自然地道的\(target.rawValue)说法（不是逐字直译）。多句输入必须逐句完整翻译，不许省略、概括或只译第一句",
              "colloquial": "更口语/更随意的变体；若与 italian 基本相同则返回 null",
              "topic": "必须从这个固定列表里精确选一个：日常寒暄|餐饮美食|出行旅行|工作学习|购物消费|情感表达|数字时间|健康身体|社交关系|其它",
              "note": "给初学者的用法或语法小提示（中文，25 字以内的短语级提示；禁止写完整例句——例句有专门的展示区），可为 null"
            }
            """
        case .reverse:
            return """
            你是经验丰富的\(target.rawValue)→中文翻译。用户给你一句或一段\(target.rawValue)（偶尔夹杂英文）。请只返回一个 JSON 对象，不要任何解释、不要 markdown 代码块，字段如下：
            {
              "italian": "最自然地道的简体中文译文（不是逐字直译）。多句输入必须逐句完整翻译，不许省略、概括或只译第一句",
              "colloquial": "更口语/更随意的中文变体；若与 italian 基本相同则返回 null",
              "topic": "必须从这个固定列表里精确选一个：日常寒暄|餐饮美食|出行旅行|工作学习|购物消费|情感表达|数字时间|健康身体|社交关系|其它",
              "note": "给中文读者的\(target.rawValue)用法或语法小提示（中文，25 字以内的短语级提示；可为 null）"
            }
            """
        }
    }

    private let session: URLSession
    private init() {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 15
        cfg.timeoutIntervalForResource = 20
        self.session = URLSession(configuration: cfg)
    }

    // MARK: - 对外入口（默认 = 正向 + 当前 target）

    /// 默认入口：中文 → 当前 AppState 选中的目标外语。
    func translate(text sourceText: String) async throws -> TranslationResult {
        let provider = await AppState.shared.provider
        let target = await AppState.shared.targetLanguage
        return try await translate(
            text: sourceText,
            direction: .forward,
            target: target,
            provider: provider
        )
    }

    /// 反向入口（菜单栏 / 全局快捷键 / 面板「反向」按钮走这里）：
    /// targetLanguage → 中文。
    func reverseTranslate(text sourceText: String) async throws -> TranslationResult {
        let provider = await AppState.shared.provider
        let target = await AppState.shared.targetLanguage
        return try await translate(
            text: sourceText,
            direction: .reverse,
            target: target,
            provider: provider
        )
    }

    /// 完整参数入口：所有调用方最终走这里。
    func translate(
        text sourceText: String,
        direction: TranslationDirection,
        target: TargetLanguage,
        provider: TranslationProvider
    ) async throws -> TranslationResult {
        let config = Secrets.config(for: provider)
        return try await translateUsingConfig(
            text: sourceText,
            direction: direction,
            target: target,
            provider: provider,
            config: config
        )
    }

    /// 已解析配置的统一请求入口。设置页测试草稿时也走这里，
    /// 从而避免为了测试连接而先污染用户已保存配置。
    private func translateUsingConfig(
        text sourceText: String,
        direction: TranslationDirection,
        target: TargetLanguage,
        provider: TranslationProvider,
        config: EngineConfig
    ) async throws -> TranslationResult {
        guard !provider.requiresAPIKey || !config.apiKey.isEmpty else {
            throw TranslationError.missingAPIKey
        }

        switch provider.apiProtocol {
        case .anthropicMessages:
            return try await translateWithAnthropic(
                text: sourceText, direction: direction, target: target, config: config
            )
        case .openAICompatible:
            return try await translateWithOpenAICompatible(
                provider: provider,
                text: sourceText,
                direction: direction,
                target: target,
                config: config
            )
        }
    }

    /// 设置 → 测试连接专用：调用方传 provider 进来，不读 AppState。
    /// 默认正向 + 目标意大利语（保证测试时即使目标已切到日语也仍能验证网络）。
    func translateForTest(text sourceText: String, provider: TranslationProvider) async throws -> TranslationResult {
        return try await translateForTest(
            text: sourceText,
            provider: provider,
            config: Secrets.storedConfig(for: provider)
        )
    }

    /// 测试设置页当前草稿，不写 UserDefaults。
    /// `effectiveConfig` 只补默认模型 / base URL 及现有 DeepSeek 运行期回退。
    func translateForTest(
        text sourceText: String,
        provider: TranslationProvider,
        config draft: EngineConfig
    ) async throws -> TranslationResult {
        let config = Secrets.effectiveConfig(draft: draft, for: provider)
        return try await translateUsingConfig(
            text: sourceText,
            direction: .forward,
            target: .italian,
            provider: provider,
            config: config
        )
    }

    // MARK: - Anthropic

    private func translateWithAnthropic(
        text sourceText: String,
        direction: TranslationDirection,
        target: TargetLanguage,
        config: EngineConfig
    ) async throws -> TranslationResult {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        // 阶段 8：Anthropic prompt caching。
        let systemPrompt = Self.buildSystemPrompt(direction: direction, target: target)
        let body: [String: Any] = [
            "model": config.model.isEmpty ? Secrets.defaultAnthropicModel : config.model,
            "max_tokens": 1200,
            "temperature": 0.3,
            "system": [
                [
                    "type": "text",
                    "text": systemPrompt,
                    "cache_control": ["type": "ephemeral"]
                ]
            ],
            "messages": [["role": "user", "content": sourceText]]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await performAndParseAnthropic(req: req)
    }

    // MARK: - OpenAI 兼容

    private func translateWithOpenAICompatible(
        provider: TranslationProvider,
        text sourceText: String,
        direction: TranslationDirection,
        target: TargetLanguage,
        config: EngineConfig
    ) async throws -> TranslationResult {
        let base = Secrets.normalizedBaseURL(
            config.baseURL,
            for: provider
        )
        let model = config.model.isEmpty ? provider.defaultModel : config.model
        guard !model.isEmpty else {
            throw TranslationError.invalidConfiguration("请填写 model ID")
        }
        guard !base.isEmpty,
              let components = URLComponents(string: base),
              let scheme = components.scheme?.lowercased(),
              (scheme == "https" || scheme == "http"),
              components.host != nil,
              let url = URL(string: "\(base)/chat/completions")
        else {
            throw TranslationError.invalidConfiguration("非法的 Base URL：\(base)")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        if !config.apiKey.isEmpty {
            req.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }
        req.setValue("application/json", forHTTPHeaderField: "content-type")

        let systemPrompt = Self.buildSystemPrompt(direction: direction, target: target)
        let usesReasoningShape = provider.usesReasoningRequestShape(model: model)
        let instructionRole = provider.instructionRole(model: model)
        var body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": instructionRole, "content": systemPrompt],
                ["role": "user", "content": sourceText]
            ]
        ]

        body[provider.tokenLimitParameter.rawValue] = 1200
        if provider.supportsJSONResponseFormat {
            body["response_format"] = ["type": "json_object"]
        }
        if usesReasoningShape {
            // OpenAI 推理模型不固定传 temperature，低延迟翻译使用 none。
            body["reasoning_effort"] = "none"
        } else {
            body["temperature"] = 0.3
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw TranslationError.network("无 HTTP 响应")
        }
        if !(200..<300).contains(http.statusCode) {
            let snippet = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
            throw TranslationError.http(http.statusCode, String(snippet))
        }

        struct OAChat: Decodable {
            struct Choice: Decodable {
                struct Msg: Decodable { let content: String? }
                let message: Msg
            }
            let choices: [Choice]
        }
        let parsed = try JSONDecoder().decode(OAChat.self, from: data)
        guard let text = parsed.choices.first?.message.content, !text.isEmpty else {
            throw TranslationError.emptyContent
        }
        return try parseTranslationJSON(text)
    }

    // MARK: - 通用：HTTP + 解 Anthropic 响应

    private func performAndParseAnthropic(req: URLRequest) async throws -> TranslationResult {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch let urlErr as URLError {
            throw TranslationError.network(urlErr.localizedDescription)
        } catch {
            throw TranslationError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw TranslationError.network("无 HTTP 响应")
        }
        if !(200..<300).contains(http.statusCode) {
            let snippet = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
            throw TranslationError.http(http.statusCode, String(snippet))
        }

        struct ARsp: Decodable {
            struct Block: Decodable { let text: String }
            let content: [Block]
            struct Usage: Decodable {
                let cache_creation_input_tokens: Int?
                let cache_read_input_tokens: Int?
                let input_tokens: Int?
                let output_tokens: Int?
            }
            let usage: Usage?
        }
        let parsed = try JSONDecoder().decode(ARsp.self, from: data)
        if let u = parsed.usage {
            let cached = u.cache_read_input_tokens ?? 0
            let created = u.cache_creation_input_tokens ?? 0
            NSLog("[dimmi][anthropic] usage input=\(u.input_tokens ?? 0) cached=\(cached) cache_created=\(created) output=\(u.output_tokens ?? 0)")
        }
        guard let raw = parsed.content.first?.text, !raw.isEmpty else {
            throw TranslationError.emptyContent
        }
        return try parseTranslationJSON(raw)
    }

    // MARK: - JSON 解析（含围栏剥离）

    private func parseTranslationJSON(_ raw: String) throws -> TranslationResult {
        let cleaned = Self.stripCodeFence(raw)
        guard let data = cleaned.data(using: .utf8) else {
            throw TranslationError.malformedResponse("无法编码为 UTF-8")
        }
        do {
            return try JSONDecoder().decode(TranslationResult.self, from: data)
        } catch {
            // 给点上下文方便排查
            let snippet = String(cleaned.prefix(200))
            throw TranslationError.malformedResponse("\(error.localizedDescription) · 内容: \(snippet)")
        }
    }

    /// 去掉模型偶尔包出来的 ```json ... ``` 围栏，以及首尾空白。
    /// 多数兼容厂商为了避免参数不兼容，不强制发 `response_format`；
    /// 因此这里也会从“以下是 JSON: {...}”之类回复中取出第一个
    /// 语法合法的 JSON object。
    static func stripCodeFence(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            t = t.replacingOccurrences(of: "```json", with: "", options: [.caseInsensitive])
            t = t.replacingOccurrences(of: "```", with: "")
            t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return firstJSONObject(in: t) ?? t
    }

    private static func firstJSONObject(in text: String) -> String? {
        var start: String.Index?
        var depth = 0
        var isInsideString = false
        var isEscaped = false

        for index in text.indices {
            let character = text[index]

            guard let objectStart = start else {
                if character == "{" {
                    start = index
                    depth = 1
                    isInsideString = false
                    isEscaped = false
                }
                continue
            }

            if isInsideString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    isInsideString = false
                }
                continue
            }

            switch character {
            case "\"":
                isInsideString = true
            case "{":
                depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    let candidate = String(text[objectStart...index])
                    if let data = candidate.data(using: .utf8),
                       (try? JSONSerialization.jsonObject(with: data)) is [String: Any] {
                        return candidate
                    }
                    start = nil
                }
            default:
                break
            }
        }
        return nil
    }
}
