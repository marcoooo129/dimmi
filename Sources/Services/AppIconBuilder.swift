import Foundation

/// 品牌资源现在由 `tools/generate-brand-assets.swift` 在构建前显式生成，
/// App 运行时不再写回源码目录，避免 Debug 启动覆盖已确认的正式图标。
@MainActor
enum AppIconBuilder {
    @available(*, deprecated, message: "品牌资源由 Asset Catalog 管理，不应在运行时生成")
    static func buildIfNeeded() {
        NSLog("[dimmi] 忽略运行时图标生成：正式品牌资源由 Asset Catalog 管理。")
    }
}
