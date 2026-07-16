// 固定话题清单：禁止模型自由生成话题名，只能从这里选，
// 否则历史库里会出现「吃饭 / 用餐」这种近义重复类。
import Foundation

enum Topic: String, CaseIterable, Codable, Identifiable {
    case greetings   = "日常寒暄"
    case food        = "餐饮美食"
    case travel      = "出行旅行"
    case work        = "工作学习"
    case shopping    = "购物消费"
    case emotions    = "情感表达"
    case numbersTime = "数字时间"
    case health      = "健康身体"
    case social      = "社交关系"
    case other       = "其它"

    var id: String { rawValue }

    /// 兜底：模型返回了不在固定清单里的值时统一归到「其它」。
    static func from(_ raw: String?) -> Topic {
        guard let raw, let t = Topic(rawValue: raw) else { return .other }
        return t
    }
}