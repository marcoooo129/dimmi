// 注解服务：根据"中文原词 + 目标语言译文"生成惯用表达注解。
//
// 设计原则：
//   - 与翻译请求**完全独立**：失败 / 超时都静默，绝不影响译文显示
//   - 强 JSON 输出：剥 ```json 围栏再 decode
//   - 3s 超时：超过直接当 hasNote:false
//   - 走 NoteCache 命中即跳过 HTTP
//   - 不直接发请求，给上游提供 fetch() 让它在合适的时机（拿到译文之后）调用
//
// 并行性：NoteService 本身不并发限流，由调用方控制：
//   - PanelController 持有 currentNoteTask，新请求前 .cancel()
//   - 注解先于译文到达的情况：phase 还在 loading 时收到 note → 暂存，
//     等 phase 切到 .idle 时再展开（viewModel 自己处理这个时序）
import Foundation

actor NoteService {
    static let shared = NoteService()

    /// 为目标语言生成教学 prompt。保持为 internal pure function，方便 XCTest
    /// 直接验证每种语言都没有写死的目标语言残留，也不需要启动 actor 或发网络请求。
    static func buildSystemPrompt(for target: TargetLanguage) -> String {
        """
        你是\(target.rawValue)教学助手，服务对象是中文母语的\(target.rawValue)初学者。
        当前目标语言是 \(target.nativeName)（英文名：\(target.englishName)，ISO：\(target.isoCode)）。

        给定一个中文词/短语，以及它的\(target.rawValue)译文，判断该译文是否是
        「值得单独解释的惯用表达或语言现象」。

        值得解释的情况：
        - \(target.rawValue)中的习语、惯用语或固定表达
        - 固定动词搭配、介词/助词搭配、特殊语序或固定句型
        - 该语言特有且不能按中文直觉直接推断的语法构造
        - 与中文直觉不符、容易误用或容易产生假朋友误解的表达
        - 语域差异明显（过于书面、过于口语、敬语或礼貌程度特殊）

        不值得解释的情况：
        - 普通名词、形容词的直接对应译法
        - 一一对应、无需拆解的高频基础动词或短语
        - 任何“解释了也等于没说”的情况

        只输出 JSON，不要 markdown 代码块，不要任何前言。hasNote 为 true 时结构如下：

        {
          "hasNote": true,
          "kind": "idiom",
          "breakdown": "用简体中文拆解目标语言表达",
          "usage": "用简体中文说明语域、固定搭配或易错点",
          "example": {
            "it": "自然的\(target.rawValue)例句",
            "zh": "例句的简体中文译文"
          }
        }

        kind 必须从 idiom、collocation、pronominal、falseFriend、register 中选一个。
        example.it 是为兼容现有数据结构保留的字段名，其内容必须使用
        \(target.rawValue)（\(target.nativeName)），不能写成其他语言。

        若不值得解释，只输出：
        {"hasNote": false}

        约束：
        - breakdown 不超过 30 字
        - usage 不超过 45 字，必须包含语域、搭配或具体易错点，不要空话
        - example 必须自然、日常、初学者能看懂，不要文学化
        - 除 example.it 外全部用简体中文解释；example.it 使用\(target.rawValue)
        """
    }

    /// 用户消息也由纯函数生成，避免请求正文继续写死“意大利语译文”。
    static func buildUserMessage(
        sourceText: String,
        translatedText: String,
        target: TargetLanguage
    ) -> String {
        "中文原文：\(sourceText)\n\(target.rawValue)译文（\(target.nativeName) / \(target.englishName)）：\(translatedText)"
    }

    /// 兼容旧测试/调用点；新代码应使用 buildSystemPrompt(for:)。
    @available(*, deprecated, message: "Use buildSystemPrompt(for:) with an explicit target language")
    static var systemPrompt: String { buildSystemPrompt(for: .italian) }

    private let session: URLSession

    private init() {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 4      // 单次连接超时
        cfg.timeoutIntervalForResource = 5     // 整体资源超时（含重试）
        self.session = URLSession(configuration: cfg)
    }

    // MARK: - 公开 API

    /// 主入口：拿一条 note。
    /// - 命中缓存 → 立刻返回
    /// - 未命中 → 走 HTTP，3s 预算超时
    /// - 任何异常 / 超时 → 返回 .none（不影响主流程）
    func fetch(
        sourceText: String,
        translatedText: String,
        target: TargetLanguage
    ) async -> PhraseNote {
        // 1) 缓存
        if let cached = await NoteCache.shared.get(
            sourceText: sourceText,
            translatedText: translatedText,
            target: target
        ) {
            return cached
        }

        // 2) HTTP
        do {
            let provider = await AppState.shared.provider
            let cfg = Secrets.config(for: provider)
            guard !provider.requiresAPIKey || !cfg.apiKey.isEmpty else {
                // 没配 key 直接当无注解，不落缓存（用户配了 key 后还能正常用）
                return .none
            }
            let note: PhraseNote = try await fetchWithTimeout(
                provider: provider, config: cfg,
                sourceText: sourceText,
                translatedText: translatedText,
                target: target,
                timeoutSeconds: 3.0
            )
            // 3) 落缓存（即便 hasNote=false 也缓存，避免每个普通词都打 API）
            await NoteCache.shared.set(
                note,
                sourceText: sourceText,
                translatedText: translatedText,
                target: target
            )
            return note
        } catch {
            NSLog("[dimmi][note] fetch failed: \(error.localizedDescription)")
            return .none
        }
    }

    /// 旧入口默认按意大利语处理，供 PanelController 迁移期间保持源码兼容。
    @available(*, deprecated, message: "Use fetch(sourceText:translatedText:target:)")
    func fetch(sourceText: String, italian: String) async -> PhraseNote {
        await fetch(sourceText: sourceText, translatedText: italian, target: .italian)
    }

    // MARK: - HTTP

    /// 整个 fetch 包了一层 3s 硬超时：内部抛错也算 timeout
    /// （让 gpt-4o-mini 这种"打满 20s 也不一定能跑完"的情况也能被裁掉）。
    private func fetchWithTimeout(
        provider: TranslationProvider,
        config: EngineConfig,
        sourceText: String,
        translatedText: String,
        target: TargetLanguage,
        timeoutSeconds: TimeInterval
    ) async throws -> PhraseNote {
        return try await withThrowingTaskGroup(of: PhraseNote.self) { group in
            group.addTask {
                try await self.performRequest(
                    provider: provider, config: config,
                    sourceText: sourceText,
                    translatedText: translatedText,
                    target: target
                )
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                throw NSError(domain: "NoteService.timeout", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "3s 超时"])
            }
            // 先到先得；cancel 掉另一个
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }

    private func performRequest(
        provider: TranslationProvider,
        config: EngineConfig,
        sourceText: String,
        translatedText: String,
        target: TargetLanguage
    ) async throws -> PhraseNote {
        let systemPrompt = Self.buildSystemPrompt(for: target)
        let userMsg = Self.buildUserMessage(
            sourceText: sourceText,
            translatedText: translatedText,
            target: target
        )
        switch provider.apiProtocol {
        case .anthropicMessages:
            return try await performAnthropic(
                apiKey: config.apiKey,
                model: config.model,
                systemPrompt: systemPrompt,
                userMsg: userMsg
            )
        case .openAICompatible:
            return try await performOpenAICompatible(
                provider: provider,
                config: config,
                systemPrompt: systemPrompt,
                userMsg: userMsg
            )
        }
    }

    // MARK: Anthropic

    private func performAnthropic(
        apiKey: String,
        model: String,
        systemPrompt: String,
        userMsg: String
    ) async throws -> PhraseNote {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        let body: [String: Any] = [
            "model": model.isEmpty ? Secrets.defaultAnthropicModel : model,
            "max_tokens": 350,
            "temperature": 0.2,
            "system": [
                [
                    "type": "text",
                    "text": systemPrompt,
                    "cache_control": ["type": "ephemeral"]
                ]
            ],
            "messages": [["role": "user", "content": userMsg]]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: req)
        try Self.throwIfHTTPNotOK(response: response, data: data)
        struct ARsp: Decodable {
            struct Block: Decodable { let text: String }
            let content: [Block]
        }
        let parsed = try JSONDecoder().decode(ARsp.self, from: data)
        guard let raw = parsed.content.first?.text, !raw.isEmpty else {
            throw NSError(domain: "NoteService", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Anthropic 返回为空"])
        }
        return parseNote(raw)
    }

    // MARK: OpenAI 兼容（OpenAI / DeepSeek / 自定义 base）

    private func performOpenAICompatible(
        provider: TranslationProvider,
        config: EngineConfig,
        systemPrompt: String,
        userMsg: String
    ) async throws -> PhraseNote {
        let base = Secrets.normalizedBaseURL(config.baseURL, for: provider)
        let model = config.model.isEmpty ? provider.defaultModel : config.model
        guard !model.isEmpty else {
            throw NSError(domain: "NoteService", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "请填写 model ID"])
        }
        guard !base.isEmpty,
              let components = URLComponents(string: base),
              let scheme = components.scheme?.lowercased(),
              (scheme == "https" || scheme == "http"),
              components.host != nil,
              let url = URL(string: "\(base)/chat/completions")
        else {
            throw NSError(domain: "NoteService", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "非法 baseURL: \(base)"])
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        if !config.apiKey.isEmpty {
            req.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        let usesReasoningShape = provider.usesReasoningRequestShape(model: model)
        let instructionRole = provider.instructionRole(model: model)
        var body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": instructionRole, "content": systemPrompt],
                ["role": "user", "content": userMsg]
            ]
        ]
        body[provider.tokenLimitParameter.rawValue] = 350
        if provider.supportsJSONResponseFormat {
            body["response_format"] = ["type": "json_object"]
        }
        if usesReasoningShape {
            body["reasoning_effort"] = "none"
        } else {
            body["temperature"] = 0.2
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: req)
        try Self.throwIfHTTPNotOK(response: response, data: data)
        struct OAChat: Decodable {
            struct Choice: Decodable {
                struct Msg: Decodable { let content: String? }
                let message: Msg
            }
            let choices: [Choice]
        }
        let parsed = try JSONDecoder().decode(OAChat.self, from: data)
        guard let text = parsed.choices.first?.message.content, !text.isEmpty else {
            throw NSError(domain: "NoteService", code: -4,
                          userInfo: [NSLocalizedDescriptionKey: "OpenAI 兼容返回为空"])
        }
        return parseNote(text)
    }

    // MARK: 工具

    private static func throwIfHTTPNotOK(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard !(200..<300).contains(http.statusCode) else { return }
        let snippet = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
        throw NSError(domain: "NoteService.http", code: http.statusCode,
                      userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode) · \(snippet)"])
    }

    private func parseNote(_ raw: String) -> PhraseNote {
        let cleaned = TranslationService.stripCodeFence(raw)
        guard let data = cleaned.data(using: .utf8) else { return .none }
        do {
            return try JSONDecoder().decode(PhraseNote.self, from: data)
        } catch {
            NSLog("[dimmi][note] parse failed: \(error.localizedDescription)")
            return .none
        }
    }
}
