// Motion：全 App 统一动画常量。
//
// 铁律：所有 hover / press / appear 微交互必须引用 Motion，不允许散落魔法数字。
// 生长/浮现由 RevealRenderer progress 时间线驱动，不在此文件。
import SwiftUI

enum Motion {
    /// hover 进入/离开
    static let hover: Animation = .easeOut(duration: 0.15)
    /// 点击按下
    static let press: Animation = .easeOut(duration: 0.10)
    /// 开关切换（玻璃开关圆钮滑动）
    static let toggle: Animation = .spring(response: 0.28, dampingFraction: 0.80)
    /// 视图初次出现（弹簧）
    static let appear: Animation = .spring(response: 0.30, dampingFraction: 0.85)
}
