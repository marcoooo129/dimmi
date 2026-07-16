// API Key / 模型选择 / base URL：MVP 先存 UserDefaults，避免一上来就引入 Keychain 复杂度。
// 真要进 MAS 商店再统一改 Keychain + App Sandbox 例外。
import Foundation

/// 供应商的网络协议。新增供应商时，服务层只依赖这个值，
/// 不再需要为每个 OpenAI-compatible 厂商新写一套 client。
enum TranslationAPIProtocol: String, Codable {
    case anthropicMessages
    case openAICompatible
}

/// OpenAI-compatible 厂商对 token 上限字段的差异。
enum OpenAITokenLimitParameter: String {
    case maxTokens = "max_tokens"
    case maxCompletionTokens = "max_completion_tokens"
}

/// 翻译引擎供应商。
///
/// 现有三个 case 的 rawValue 不能改：`dimmi.provider` 的旧版本正是用
/// rawValue 持久化，保留它们才能无损读取 OpenAI / DeepSeek 旧配置。
enum TranslationProvider: String, CaseIterable, Identifiable, Codable {
    case anthropic    = "Anthropic Claude"
    case openai       = "OpenAI"
    case deepseek     = "DeepSeek"
    case googleGemini = "Google Gemini"
    case xAI          = "xAI Grok"
    case groq         = "Groq"
    case mistral      = "Mistral AI"
    case openRouter   = "OpenRouter"
    case togetherAI   = "Together AI"
    case fireworksAI  = "Fireworks AI"
    case siliconFlow  = "硅基流动 SiliconFlow"
    case alibabaQwen  = "阿里云通义千问"
    case moonshot     = "Moonshot 月之暗面"
    case zhipu        = "智谱 GLM"
    case perplexity   = "Perplexity"
    case cerebras     = "Cerebras"
    case nvidia       = "NVIDIA NIM"
    case sambanova    = "SambaNova"
    case cohere       = "Cohere"
    case githubModels = "GitHub Models"
    case huggingFace  = "Hugging Face"
    case customCompatible = "自定义兼容接口"

    /// 不随 UI 文案变化的稳定 ID，同时是 UserDefaults namespace。
    var storageID: String {
        switch self {
        case .anthropic:    return "anthropic"
        case .openai:       return "openai"
        case .deepseek:     return "deepseek"
        case .googleGemini: return "google-gemini"
        case .xAI:          return "xai"
        case .groq:         return "groq"
        case .mistral:      return "mistral"
        case .openRouter:   return "openrouter"
        case .togetherAI:   return "together-ai"
        case .fireworksAI:  return "fireworks-ai"
        case .siliconFlow:  return "siliconflow"
        case .alibabaQwen:  return "alibaba-qwen"
        case .moonshot:     return "moonshot"
        case .zhipu:        return "zhipu"
        case .perplexity:   return "perplexity"
        case .cerebras:     return "cerebras"
        case .nvidia:       return "nvidia"
        case .sambanova:    return "sambanova"
        case .cohere:       return "cohere"
        case .githubModels: return "github-models"
        case .huggingFace:  return "huggingface"
        case .customCompatible: return "custom-compatible"
        }
    }

    var id: String { storageID }

    var apiProtocol: TranslationAPIProtocol {
        self == .anthropic ? .anthropicMessages : .openAICompatible
    }

    /// Anthropic 目前只走官方 Messages API；其他厂商均允许用户覆盖
    /// OpenAI-compatible base URL，便于使用代理、企业网关或地域端点。
    var supportsCustomBaseURL: Bool { apiProtocol == .openAICompatible }

    var defaultBaseURL: String {
        switch self {
        case .anthropic:    return ""
        case .openai:       return "https://api.openai.com/v1"
        case .deepseek:     return "https://api.deepseek.com/v1"
        case .googleGemini: return "https://generativelanguage.googleapis.com/v1beta/openai"
        case .xAI:          return "https://api.x.ai/v1"
        case .groq:         return "https://api.groq.com/openai/v1"
        case .mistral:      return "https://api.mistral.ai/v1"
        case .openRouter:   return "https://openrouter.ai/api/v1"
        case .togetherAI:   return "https://api.together.ai/v1"
        case .fireworksAI:  return "https://api.fireworks.ai/inference/v1"
        case .siliconFlow:  return "https://api.siliconflow.cn/v1"
        case .alibabaQwen:  return "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
        case .moonshot:     return "https://api.moonshot.cn/v1"
        case .zhipu:        return "https://open.bigmodel.cn/api/paas/v4"
        case .perplexity:   return "https://api.perplexity.ai"
        case .cerebras:     return "https://api.cerebras.ai/v1"
        case .nvidia:       return "https://integrate.api.nvidia.com/v1"
        case .sambanova:    return "https://api.sambanova.ai/v1"
        case .cohere:       return "https://api.cohere.ai/compatibility/v1"
        case .githubModels: return "https://models.github.ai/inference"
        case .huggingFace:  return "https://router.huggingface.co/v1"
        case .customCompatible: return ""
        }
    }

    var defaultModel: String {
        switch self {
        case .anthropic:    return "claude-haiku-4-5-20251001"
        case .openai:       return "gpt-4o-mini"
        case .deepseek:     return "deepseek-v4-flash"
        case .googleGemini: return "gemini-3.1-flash-lite"
        case .xAI:          return "grok-4.3"
        case .groq:         return "qwen/qwen3.6-27b"
        case .mistral:      return "mistral-small-2603"
        case .openRouter:   return "openai/gpt-4o-mini"
        case .togetherAI:   return "Qwen/Qwen3.5-9B"
        case .fireworksAI:  return "accounts/fireworks/models/qwen3p7-plus"
        case .siliconFlow:  return "deepseek-ai/DeepSeek-V4-Flash"
        case .alibabaQwen:  return "qwen3.6-flash"
        case .moonshot:     return "kimi-k2.6"
        case .zhipu:        return "glm-4.7-flashx"
        case .perplexity:   return "sonar"
        case .cerebras:     return "gpt-oss-120b"
        case .nvidia:       return "deepseek-ai/deepseek-v4-flash"
        case .sambanova:    return "DeepSeek-V3.1"
        case .cohere:       return "command-a-translate-08-2025"
        case .githubModels: return "openai/gpt-4.1-mini"
        case .huggingFace:  return "CohereLabs/command-a-translate-08-2025"
        case .customCompatible: return ""
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .anthropic:    return "sk-ant-…"
        case .openai, .deepseek, .siliconFlow, .alibabaQwen, .moonshot: return "sk-…"
        case .googleGemini: return "AIza…"
        case .xAI:          return "xai-…"
        case .groq:         return "gsk_…"
        case .openRouter:   return "sk-or-v1-…"
        case .fireworksAI:  return "fw_…"
        case .perplexity:   return "pplx-…"
        case .cerebras:     return "csk-…"
        case .nvidia:       return "nvapi-…"
        case .githubModels: return "github_pat_…"
        case .huggingFace:  return "hf_…"
        case .mistral, .togetherAI, .zhipu, .sambanova, .cohere, .customCompatible:
            return "API Key"
        }
    }

    var configurationHint: String {
        switch self {
        case .anthropic:    return "Anthropic Messages API"
        case .openai:       return "OpenAI 官方 API"
        case .deepseek:     return "DeepSeek 官方 OpenAI 兼容接口"
        case .googleGemini: return "Gemini OpenAI 兼容接口"
        case .alibabaQwen:  return "API Key 必须与 Base URL 所属区域一致"
        case .perplexity:   return "搜索型模型，纯翻译成本可能较高"
        case .githubModels: return "预览服务；GitHub PAT 需要 Models: read 权限"
        case .huggingFace:  return "使用 hf token；model ID 可添加 provider 路由后缀"
        case .customCompatible: return "自定义 OpenAI Chat Completions 端点"
        default:            return "\(rawValue) OpenAI 兼容接口"
        }
    }

    /// 自定义端点可以指向本机 Ollama / vLLM；此时允许不填 key，
    /// 并且请求不会写入空的 Authorization header。
    var requiresAPIKey: Bool { self != .customCompatible }

    /// OpenAI 官方新模型使用 `max_completion_tokens`；其他兼容厂商
    /// 优先使用覆盖面最广的 `max_tokens`。
    var tokenLimitParameter: OpenAITokenLimitParameter {
        // Cerebras 当前 Chat Completions 规格只公开
        // `max_completion_tokens`，不接收旧的 `max_tokens`。
        self == .openai || self == .cerebras ? .maxCompletionTokens : .maxTokens
    }

    /// 只对已在现有版本验证过的厂商强制 JSON mode。
    /// 其他兼容服务仍由 prompt 要求 JSON，避免部分网关因不识别
    /// `response_format` 而直接返回 400。
    var supportsJSONResponseFormat: Bool {
        self == .openai || self == .deepseek
    }

    func usesReasoningRequestShape(model: String) -> Bool {
        guard self == .openai else { return false }
        let id = model.lowercased()
        return id.hasPrefix("gpt-5") || id.hasPrefix("o1") ||
            id.hasPrefix("o3") || id.hasPrefix("o4")
    }

    func instructionRole(model: String) -> String {
        self == .cohere || usesReasoningRequestShape(model: model) ? "developer" : "system"
    }
}

/// 引擎配置：Key + 模型 + 可选自定义 base URL。
/// DeepSeek / 其他 OpenAI-兼容服务（Groq、OpenRouter、硅基流动…）复用 OpenAI 协议，
/// 只需要改 baseURL 即可。
struct EngineConfig: Codable, Equatable {
    var apiKey: String = ""
    var model: String = ""
    var baseURL: String = ""
}

/// 设置页可直接消费的模型条目。`id` 始终是供应商 API 接受的 model ID。
struct TranslationModelOption: Identifiable, Equatable {
    enum Lifecycle: Equatable {
        case current
        case legacy(String)
    }

    let id: String
    let name: String
    let summary: String
    let isRecommended: Bool
    let lifecycle: Lifecycle

    init(
        id: String,
        name: String,
        summary: String,
        isRecommended: Bool = false,
        lifecycle: Lifecycle = .current
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.isRecommended = isRecommended
        self.lifecycle = lifecycle
    }

    var isLegacy: Bool {
        if case .legacy = lifecycle { return true }
        return false
    }
}

/// 模型选择器只需绑定这个值；不在目录内的已保存 model ID 会自动落到 `.custom`。
enum TranslationModelSelection: Hashable, Identifiable {
    case preset(String)
    case custom

    var id: String {
        switch self {
        case .preset(let modelID): return "preset:\(modelID)"
        case .custom:               return "custom"
        }
    }
}

/// 仅列入项目当前请求协议可直接调用的文本模型；自定义 model ID 始终保留。
enum TranslationModelCatalog {
    static func options(for provider: TranslationProvider) -> [TranslationModelOption] {
        switch provider {
        case .anthropic:
            return [
                .init(
                    id: "claude-haiku-4-5-20251001",
                    name: "Claude Haiku 4.5",
                    summary: "速度最快，适合高频翻译",
                    isRecommended: true
                ),
                .init(
                    id: "claude-sonnet-5",
                    name: "Claude Sonnet 5",
                    summary: "速度与质量均衡"
                ),
                .init(
                    id: "claude-opus-4-8",
                    name: "Claude Opus 4.8",
                    summary: "复杂文本与高质量表达"
                ),
                .init(
                    id: "claude-fable-5",
                    name: "Claude Fable 5",
                    summary: "长任务与最高能力，成本较高"
                )
            ]

        case .openai:
            return [
                .init(
                    id: "gpt-4o-mini",
                    name: "GPT-4o mini",
                    summary: "轻量低成本，适合日常翻译",
                    isRecommended: true
                ),
                .init(
                    id: "gpt-5.4-mini",
                    name: "GPT-5.4 mini",
                    summary: "高吞吐量的新一代 mini 模型"
                ),
                .init(
                    id: "gpt-5.6-luna",
                    name: "GPT-5.6 Luna",
                    summary: "GPT-5.6 的成本敏感型选择"
                ),
                .init(
                    id: "gpt-5.6-terra",
                    name: "GPT-5.6 Terra",
                    summary: "能力与成本平衡"
                ),
                .init(
                    id: "gpt-5.6-sol",
                    name: "GPT-5.6 Sol",
                    summary: "旗舰能力，适合复杂内容"
                ),
                .init(
                    id: "gpt-4.1-mini",
                    name: "GPT-4.1 mini",
                    summary: "低延迟的非推理模型"
                )
            ]

        case .deepseek:
            let retirement = "兼容旧配置；2026-07-24 停止服务"
            return [
                .init(
                    id: "deepseek-v4-flash",
                    name: "DeepSeek V4 Flash",
                    summary: "低成本、高吞吐，适合日常翻译",
                    isRecommended: true
                ),
                .init(
                    id: "deepseek-v4-pro",
                    name: "DeepSeek V4 Pro",
                    summary: "更高质量与复杂推理"
                ),
                .init(
                    id: "deepseek-chat",
                    name: "DeepSeek Chat（旧）",
                    summary: retirement,
                    lifecycle: .legacy(retirement)
                ),
                .init(
                    id: "deepseek-reasoner",
                    name: "DeepSeek Reasoner（旧）",
                    summary: retirement,
                    lifecycle: .legacy(retirement)
                )
            ]

        case .googleGemini:
            return [
                .init(
                    id: "gemini-3.1-flash-lite",
                    name: "Gemini 3.1 Flash-Lite",
                    summary: "低延迟、低成本，官方推荐用于翻译",
                    isRecommended: true
                ),
                .init(
                    id: "gemini-3.5-flash",
                    name: "Gemini 3.5 Flash",
                    summary: "速度与质量均衡"
                ),
                .init(
                    id: "gemini-3.1-pro-preview",
                    name: "Gemini 3.1 Pro Preview",
                    summary: "复杂长文本与高质量表达"
                ),
                .init(
                    id: "gemini-2.5-flash",
                    name: "Gemini 2.5 Flash",
                    summary: "稳定兼容的上一代 Flash"
                )
            ]

        case .xAI:
            return [
                .init(
                    id: "grok-4.3",
                    name: "Grok 4.3",
                    summary: "快速文本模型，适合日常翻译",
                    isRecommended: true
                ),
                .init(
                    id: "grok-4.5",
                    name: "Grok 4.5",
                    summary: "旗舰质量，适合复杂内容"
                )
            ]

        case .groq:
            let retirement = "兼容旧配置；2026-08-16 停止开发者层服务"
            return [
                .init(
                    id: "qwen/qwen3.6-27b",
                    name: "Qwen 3.6 27B",
                    summary: "高速多语言模型，适合翻译",
                    isRecommended: true
                ),
                .init(
                    id: "openai/gpt-oss-20b",
                    name: "GPT-OSS 20B",
                    summary: "体量小、响应快"
                ),
                .init(
                    id: "openai/gpt-oss-120b",
                    name: "GPT-OSS 120B",
                    summary: "更高质量的开放权重模型"
                ),
                .init(
                    id: "llama-3.3-70b-versatile",
                    name: "Llama 3.3 70B（旧）",
                    summary: retirement,
                    lifecycle: .legacy(retirement)
                )
            ]

        case .mistral:
            return [
                .init(
                    id: "mistral-small-2603",
                    name: "Mistral Small 2603",
                    summary: "低延迟与成本平衡，适合日常翻译",
                    isRecommended: true
                ),
                .init(
                    id: "mistral-medium-3-5",
                    name: "Mistral Medium 3.5",
                    summary: "质量与速度均衡"
                ),
                .init(
                    id: "mistral-large-2512",
                    name: "Mistral Large 2512",
                    summary: "复杂文本与高质量表达"
                ),
                .init(
                    id: "ministral-8b-2512",
                    name: "Ministral 8B 2512",
                    summary: "轻量快速"
                ),
                .init(
                    id: "ministral-14b-2512",
                    name: "Ministral 14B 2512",
                    summary: "轻量模型中的更高质量选项"
                )
            ]

        case .openRouter:
            return [
                .init(
                    id: "openai/gpt-4o-mini",
                    name: "OpenAI GPT-4o mini",
                    summary: "稳定、低成本的默认路由",
                    isRecommended: true
                ),
                .init(
                    id: "google/gemini-3.1-flash-lite",
                    name: "Google Gemini 3.1 Flash-Lite",
                    summary: "高频翻译与低延迟"
                ),
                .init(
                    id: "google/gemini-3.5-flash",
                    name: "Google Gemini 3.5 Flash",
                    summary: "速度与质量均衡"
                ),
                .init(
                    id: "openai/gpt-5.6-luna",
                    name: "OpenAI GPT-5.6 Luna",
                    summary: "新一代高吞吐模型"
                ),
                .init(
                    id: "anthropic/claude-haiku-4.5",
                    name: "Anthropic Claude Haiku 4.5",
                    summary: "快速自然的多语言表达"
                ),
                .init(
                    id: "deepseek/deepseek-v4-flash",
                    name: "DeepSeek V4 Flash",
                    summary: "中文语境与低成本"
                ),
                .init(
                    id: "mistralai/mistral-small-2603",
                    name: "Mistral Small 2603",
                    summary: "欧洲厂商的轻量多语言模型"
                )
            ]

        case .togetherAI:
            return [
                .init(
                    id: "Qwen/Qwen3.5-9B",
                    name: "Qwen 3.5 9B",
                    summary: "小型快速，适合高频短句",
                    isRecommended: true
                ),
                .init(
                    id: "Qwen/Qwen3.5-397B-A17B",
                    name: "Qwen 3.5 397B A17B",
                    summary: "更强的多语言与复杂文本能力"
                ),
                .init(
                    id: "moonshotai/Kimi-K2.6",
                    name: "Kimi K2.6",
                    summary: "长文本与中文语境"
                ),
                .init(
                    id: "zai-org/GLM-5.1",
                    name: "GLM 5.1",
                    summary: "高质量中文与多语言任务"
                ),
                .init(
                    id: "openai/gpt-oss-20b",
                    name: "GPT-OSS 20B",
                    summary: "轻量开放模型"
                ),
                .init(
                    id: "meta-llama/Llama-3.3-70B-Instruct-Turbo",
                    name: "Llama 3.3 70B Turbo",
                    summary: "成熟的多语言指令模型"
                )
            ]

        case .fireworksAI:
            return [
                .init(
                    id: "accounts/fireworks/models/qwen3p7-plus",
                    name: "Qwen 3.7 Plus",
                    summary: "高速、多语言，适合翻译",
                    isRecommended: true
                ),
                .init(
                    id: "accounts/fireworks/models/kimi-k2p6",
                    name: "Kimi K2.6",
                    summary: "中文与长文本能力强"
                ),
                .init(
                    id: "accounts/fireworks/models/glm-5p2",
                    name: "GLM 5.2",
                    summary: "复杂文本和高质量表达"
                ),
                .init(
                    id: "accounts/fireworks/models/gpt-oss-120b",
                    name: "GPT-OSS 120B",
                    summary: "高质量开放权重模型"
                )
            ]

        case .siliconFlow:
            return [
                .init(
                    id: "deepseek-ai/DeepSeek-V4-Flash",
                    name: "DeepSeek V4 Flash",
                    summary: "低成本、高吞吐，适合翻译",
                    isRecommended: true
                ),
                .init(
                    id: "deepseek-ai/DeepSeek-V4-Pro",
                    name: "DeepSeek V4 Pro",
                    summary: "复杂文本与高质量表达"
                ),
                .init(
                    id: "Qwen/Qwen3.5-397B-A17B",
                    name: "Qwen 3.5 397B A17B",
                    summary: "多语言与中文语境"
                ),
                .init(
                    id: "Qwen/Qwen3.6-35B-A3B",
                    name: "Qwen 3.6 35B A3B",
                    summary: "速度与质量平衡"
                ),
                .init(
                    id: "Pro/moonshotai/Kimi-K2.6",
                    name: "Kimi K2.6 Pro",
                    summary: "长文本与自然表达"
                ),
                .init(
                    id: "zai-org/GLM-5.2",
                    name: "GLM 5.2",
                    summary: "高质量中文与多语言模型"
                )
            ]

        case .alibabaQwen:
            return [
                .init(
                    id: "qwen3.6-flash",
                    name: "Qwen 3.6 Flash",
                    summary: "低延迟、高频翻译",
                    isRecommended: true
                ),
                .init(
                    id: "qwen3.7-plus",
                    name: "Qwen 3.7 Plus",
                    summary: "速度与翻译质量均衡"
                ),
                .init(
                    id: "qwen3.7-max",
                    name: "Qwen 3.7 Max",
                    summary: "复杂内容与最高质量"
                ),
                .init(
                    id: "qwen3.6-plus",
                    name: "Qwen 3.6 Plus",
                    summary: "稳定兼容的通用模型"
                )
            ]

        case .moonshot:
            return [
                .init(
                    id: "kimi-k2.6",
                    name: "Kimi K2.6",
                    summary: "中文语境与自然表达，适合翻译",
                    isRecommended: true
                ),
                .init(
                    id: "kimi-k2.5",
                    name: "Kimi K2.5",
                    summary: "稳定通用模型"
                ),
                .init(
                    id: "moonshot-v1-8k",
                    name: "Moonshot V1 8K",
                    summary: "短文本低延迟"
                ),
                .init(
                    id: "moonshot-v1-32k",
                    name: "Moonshot V1 32K",
                    summary: "中长文本"
                ),
                .init(
                    id: "moonshot-v1-128k",
                    name: "Moonshot V1 128K",
                    summary: "超长上下文"
                )
            ]

        case .zhipu:
            return [
                .init(
                    id: "glm-4.7-flashx",
                    name: "GLM 4.7 FlashX",
                    summary: "官方标注适合翻译的轻量高速模型",
                    isRecommended: true
                ),
                .init(
                    id: "glm-5.2",
                    name: "GLM 5.2",
                    summary: "复杂内容与高质量表达"
                ),
                .init(
                    id: "glm-4.7",
                    name: "GLM 4.7",
                    summary: "高质量通用模型"
                ),
                .init(
                    id: "glm-4.7-flash",
                    name: "GLM 4.7 Flash",
                    summary: "高频低成本"
                ),
                .init(
                    id: "glm-4.6",
                    name: "GLM 4.6",
                    summary: "稳定兼容的上一代模型"
                )
            ]

        case .perplexity:
            return [
                .init(
                    id: "sonar",
                    name: "Sonar",
                    summary: "轻量搜索增强模型",
                    isRecommended: true
                ),
                .init(
                    id: "sonar-pro",
                    name: "Sonar Pro",
                    summary: "更高质量的搜索增强回答"
                ),
                .init(
                    id: "sonar-reasoning-pro",
                    name: "Sonar Reasoning Pro",
                    summary: "复杂推理，翻译场景成本较高"
                ),
                .init(
                    id: "sonar-deep-research",
                    name: "Sonar Deep Research",
                    summary: "深度研究用途，纯翻译通常不需要"
                )
            ]

        case .cerebras:
            return [
                .init(
                    id: "gpt-oss-120b",
                    name: "GPT-OSS 120B",
                    summary: "高速高质量开放模型",
                    isRecommended: true
                ),
                .init(
                    id: "zai-glm-4.7",
                    name: "GLM 4.7 Preview",
                    summary: "预览模型，适合尝鲜"
                )
            ]

        case .nvidia:
            return [
                .init(
                    id: "deepseek-ai/deepseek-v4-flash",
                    name: "DeepSeek V4 Flash",
                    summary: "低延迟、多语言，适合翻译",
                    isRecommended: true
                ),
                .init(
                    id: "qwen/qwen3.5-122b-a10b",
                    name: "Qwen 3.5 122B A10B",
                    summary: "中文与多语言能力强"
                ),
                .init(
                    id: "meta/llama-3.3-70b-instruct",
                    name: "Llama 3.3 70B Instruct",
                    summary: "成熟多语言指令模型"
                ),
                .init(
                    id: "z-ai/glm-5.2",
                    name: "GLM 5.2",
                    summary: "高质量中文与复杂文本"
                )
            ]

        case .sambanova:
            return [
                .init(
                    id: "DeepSeek-V3.1",
                    name: "DeepSeek V3.1",
                    summary: "生产级中文与多语言模型",
                    isRecommended: true
                ),
                .init(
                    id: "Meta-Llama-3.3-70B-Instruct",
                    name: "Llama 3.3 70B Instruct",
                    summary: "成熟多语言模型"
                ),
                .init(
                    id: "gpt-oss-120b",
                    name: "GPT-OSS 120B",
                    summary: "高质量开放模型"
                ),
                .init(
                    id: "MiniMax-M2.7",
                    name: "MiniMax M2.7",
                    summary: "自然表达与长文本"
                )
            ]

        case .cohere:
            return [
                .init(
                    id: "command-a-translate-08-2025",
                    name: "Command A Translate",
                    summary: "覆盖中文、意大利语等 23 种语言的专用翻译模型",
                    isRecommended: true
                ),
                .init(
                    id: "command-a-plus-05-2026",
                    name: "Command A Plus",
                    summary: "高质量通用文本模型"
                ),
                .init(
                    id: "command-a-03-2025",
                    name: "Command A",
                    summary: "稳定通用模型"
                ),
                .init(
                    id: "command-r7b-12-2024",
                    name: "Command R7B",
                    summary: "轻量低延迟"
                )
            ]

        case .githubModels:
            return [
                .init(
                    id: "openai/gpt-4.1-mini",
                    name: "OpenAI GPT-4.1 mini",
                    summary: "稳定、低延迟，适合翻译",
                    isRecommended: true
                ),
                .init(
                    id: "openai/gpt-4o-mini",
                    name: "OpenAI GPT-4o mini",
                    summary: "低成本通用模型"
                ),
                .init(
                    id: "meta/llama-3.3-70b-instruct",
                    name: "Llama 3.3 70B Instruct",
                    summary: "多语言开放模型"
                ),
                .init(
                    id: "cohere/cohere-command-a",
                    name: "Cohere Command A",
                    summary: "自然语言与多语言任务"
                )
            ]

        case .huggingFace:
            return [
                .init(
                    id: "CohereLabs/command-a-translate-08-2025",
                    name: "Command A Translate",
                    summary: "中文与意大利语专用翻译模型",
                    isRecommended: true
                ),
                .init(
                    id: "Qwen/Qwen3.5-9B",
                    name: "Qwen 3.5 9B",
                    summary: "轻量多语言模型"
                ),
                .init(
                    id: "deepseek-ai/DeepSeek-V4-Flash",
                    name: "DeepSeek V4 Flash",
                    summary: "低成本、高吞吐"
                ),
                .init(
                    id: "google/gemma-4-31B-it",
                    name: "Gemma 4 31B IT",
                    summary: "开放多语言指令模型"
                )
            ]

        case .customCompatible:
            return []
        }
    }

    static func option(
        modelID: String,
        for provider: TranslationProvider
    ) -> TranslationModelOption? {
        let normalized = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        return options(for: provider).first { $0.id == normalized }
    }

    static func recommendedOption(for provider: TranslationProvider) -> TranslationModelOption? {
        let models = options(for: provider)
        return models.first(where: \.isRecommended) ?? models.first
    }

    /// 空值沿用应用默认模型；目录外的 model ID 进入“自定义”而不是被覆盖。
    static func selection(
        for modelID: String,
        provider: TranslationProvider
    ) -> TranslationModelSelection {
        let normalized = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        if provider == .customCompatible { return .custom }
        let effectiveID = normalized.isEmpty ? Secrets.defaultModel(for: provider) : normalized
        return option(modelID: effectiveID, for: provider) == nil
            ? .custom
            : .preset(effectiveID)
    }

    /// 保存前统一清理输入；自定义框留空时仍回退到应用默认模型。
    static func resolvedModelID(
        selection: TranslationModelSelection,
        customModelID: String,
        provider: TranslationProvider
    ) -> String {
        switch selection {
        case .preset(let modelID):
            let normalized = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.isEmpty ? Secrets.defaultModel(for: provider) : normalized
        case .custom:
            let normalized = customModelID.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.isEmpty ? Secrets.defaultModel(for: provider) : normalized
        }
    }
}

enum Secrets {
    private static let providerKey = "dimmi.provider"

    /// 前三个 provider 生成的 key 与旧版本完全相同：
    /// `dimmi.openai.apiKey` / `dimmi.deepseek.model` 等，因此无需破坏性迁移。
    private static func configKey(_ field: String, for provider: TranslationProvider) -> String {
        "dimmi.\(provider.storageID).\(field)"
    }

    /// 默认模型：文档里写死了 claude-haiku-4-5-20251001（必须含日期后缀）。
    static let defaultAnthropicModel = TranslationProvider.anthropic.defaultModel
    static let defaultOpenAIModel    = TranslationProvider.openai.defaultModel
    static let defaultDeepSeekModel  = TranslationProvider.deepseek.defaultModel
    static let defaultDeepSeekBase   = TranslationProvider.deepseek.defaultBaseURL

    // MARK: - 内置 Key（2026-07-14 任务：用户私钥）
    //
    // 设置窗口里粘贴 key 仍受支持；如果 UserDefaults 没存，就回退到这个内置常量。
    // ⚠️ 安全提示：填入真实 key 后请勿提交到公开仓库；建议在发版前移到 Keychain 或服务端代理。
    /// DeepSeek API Key。留空字符串 = 没有内置 key，必须让用户在设置里粘贴。
    ///
    /// ⚠️ 公开发布版**必须**保持为空：任何写进这里的 key 都会被编译进二进制，
    /// 任何人下载 .app 后用 `strings` 就能提取。个人开发期如需内置，
    /// 只在本地改，绝不提交（.gitignore 挡不住已 add 的改动，靠自觉 + review）。
    static let embeddedDeepSeekKey: String = {
        return ""
    }()

    // MARK: - 读
    static func currentProvider(defaults: UserDefaults = .standard) -> TranslationProvider {
        guard let raw = defaults.string(forKey: providerKey) else { return .deepseek }
        // 旧版本存 rawValue；同时接受稳定 storageID，为未来 UI 改名留出迁移路径。
        return TranslationProvider(rawValue: raw)
            ?? TranslationProvider.allCases.first { $0.storageID == raw }
            ?? .deepseek
    }

    /// 只读用户真正保存的配置，不注入 embedded key。
    /// 设置页必须用这个入口，否则会把内置 key 展示到输入框。
    static func storedConfig(
        for provider: TranslationProvider,
        defaults: UserDefaults = .standard
    ) -> EngineConfig {
        let legacyDeepSeekBase = provider == .deepseek ? provider.defaultBaseURL : ""
        return EngineConfig(
            apiKey: defaults.string(forKey: configKey("apiKey", for: provider)) ?? "",
            model: defaults.string(forKey: configKey("model", for: provider))
                ?? provider.defaultModel,
            baseURL: defaults.string(forKey: configKey("baseURL", for: provider))
                ?? legacyDeepSeekBase
        )
    }

    /// 运行期配置：在 stored config 上补默认模型 / base URL，
    /// DeepSeek 没有用户 key 时保持现有 embedded-key 回退行为。
    static func config(for provider: TranslationProvider) -> EngineConfig {
        effectiveConfig(draft: storedConfig(for: provider), for: provider)
    }

    /// 把设置页尚未落盘的草稿变成一次请求可用的配置。
    /// 这个函数纯计算，不会写 UserDefaults。
    static func effectiveConfig(draft: EngineConfig, for provider: TranslationProvider) -> EngineConfig {
        var apiKey = draft.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        var model = draft.model.trimmingCharacters(in: .whitespacesAndNewlines)

        if model.isEmpty { model = provider.defaultModel }
        if provider == .deepseek, apiKey.isEmpty {
            apiKey = embeddedDeepSeekKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return EngineConfig(
            apiKey: apiKey,
            model: model,
            baseURL: normalizedBaseURL(draft.baseURL, for: provider)
        )
    }

    static func defaultModel(for provider: TranslationProvider) -> String {
        provider.defaultModel
    }

    /// OpenAI 兼容端点的唯一标准化入口。
    /// 接受用户粘贴的 `.../chat/completions` 或尾随 `/`，
    /// 返回不带请求 path 和尾斜杠的 base URL。
    static func normalizedBaseURL(_ rawValue: String, for provider: TranslationProvider) -> String {
        guard provider.supportsCustomBaseURL else { return "" }

        let fallback = provider.defaultBaseURL
        var base = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.isEmpty { base = fallback }

        while base.hasSuffix("/") { base.removeLast() }
        let completionsPath = "/chat/completions"
        if base.lowercased().hasSuffix(completionsPath) {
            base.removeLast(completionsPath.count)
        }
        while base.hasSuffix("/") { base.removeLast() }
        return base
    }

    // MARK: - 写
    static func setProvider(_ provider: TranslationProvider, defaults: UserDefaults = .standard) {
        defaults.set(provider.rawValue, forKey: providerKey)
    }

    static func setConfig(
        _ config: EngineConfig,
        for provider: TranslationProvider,
        defaults: UserDefaults = .standard
    ) {
        let apiKey = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = config.model.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(apiKey, forKey: configKey("apiKey", for: provider))
        defaults.set(model, forKey: configKey("model", for: provider))
        if provider.supportsCustomBaseURL {
            defaults.set(baseURL, forKey: configKey("baseURL", for: provider))
        }
    }

    /// 检查当前 provider 是否有 Key，没有就给 UI 提示用。
    static var hasKeyForCurrentProvider: Bool {
        let provider = currentProvider()
        return !provider.requiresAPIKey || !config(for: provider).apiKey.isEmpty
    }

    /// 当前 provider 的默认 base URL，仅用于 UI 提示。
    static func defaultBaseURL(for provider: TranslationProvider) -> String {
        provider.defaultBaseURL
    }
}
