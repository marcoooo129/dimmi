// 登录项：用 Apple 推荐的 SMAppService（macOS 13+） 注册/反注册登录项。
// 不引入第三方依赖（SettingsLoginItems 已被 SPM 推荐替代为 SMAppService）。
import Foundation
import ServiceManagement

@MainActor
enum LaunchAtLoginService {
    /// 打包 macOS App 到 /Applications 时此机制才真正可用；DEBUG 跑 build/DerivedData 不生效但也不会崩。
    static var current: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    /// 设置登录项，并返回系统回读到的真实开启状态。
    /// `.requiresApproval` 不是成功开启：此时返回 false，由 UI 引导用户
    /// 前往「系统设置 → 通用 → 登录项」批准。注册 / 反注册失败则向上抛出。
    @discardableResult
    static func set(_ enabled: Bool) throws -> Bool {
        let service = SMAppService.mainApp

        if enabled {
            if service.status == .enabled { return true }
            if service.status == .requiresApproval { return false }
            try service.register()
        } else {
            // requiresApproval 也是一个已登记但未被用户批准的状态；
            // 关闭时同样反注册，不留一个悬空登录项。
            if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
            }
        }
        return service.status == .enabled
    }
}
