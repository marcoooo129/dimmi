# dimmi 项目规则

## 构建纪律（2026-07-16 定，违反过一次：30+ 个 build 目录堆了 18GB）

- **唯一构建入口**：`./tools/dev-rebuild.sh`。它负责 编译 → 更新 dist → 重启。
- **唯一 derivedDataPath**：`./build`。禁止 `-derivedDataPath build_xxx` 之类新目录。
- **全机唯一的 dimmi**：`dist/dimmi.app`，由脚本 rsync 原地更新。
  禁止把 .app 拷到其他位置、禁止留多份副本。
- 直接调 xcodebuild 时也必须 `-derivedDataPath ./build`，构建完把产物
  rsync 进 `dist/dimmi.app`（参照脚本第 5 步），不要从 build 目录里直接 open。

## 为什么 dist 路径不能变

TCC（辅助功能授权）按「路径 + 代码身份」记忆应用。app 换路径 = 授权作废。
adhoc 签名已固定 designated requirement 为 `identifier "com.frase.app"`，
配合固定路径，划词授权可跨重建存活。

## 设置窗的「会话回滚」陷阱

设置窗是可撤销编辑会话（红色关闭 = 回滚快照）。任何**带系统副作用的开关**
（取词方式 sourceMode、授权状态）必须在 onChange 里同步写回 sessionSnapshot，
否则会被回滚制造"授权了但功能无效"的假故障。已修过两次，别再犯。

## 工程文件

- 工程由 `project.yml` + xcodegen 生成；新增/删除源文件后跑 `xcodegen generate`。
- 字体注册：Info.plist `ATSApplicationFontsPath = "Fonts"` + project.yml 里的
  `Resources/Fonts` folder 资源，两半缺一不可。
