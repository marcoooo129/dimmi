# dimmi · GitHub 上线检查表

这份文件用于审阅阶段，不代表已经发布。

## 已完成

- [x] 核对代码中的真实功能与系统要求
- [x] 重写 GitHub README
- [x] 创建零依赖 GitHub Pages 推广页
- [x] 创建网页与 Markdown 隐私说明
- [x] 页面使用干净素材，不公开个人桌面与开发窗口截图
- [x] 推广页适配桌面与移动端，并支持键盘焦点与减少动画
- [x] Release 安装说明明确标注 ad-hoc 签名与未公证状态

## 需要项目所有者确认

- [ ] 正确 GitHub 用户名
- [ ] 仓库名称（当前建议 dimmi）
- [ ] 仓库可见性：Public 或 Private
- [ ] 是否公开源码
- [ ] 是否确认采用 MIT License
- [ ] LICENSE 的版权公开署名（姓名、组织名或公开笔名）
- [ ] App 内 © 2026 Frase 是否保留，或与 LICENSE 统一

## 正式公开前的安全与产品事项

- [ ] 将 API Key 从 UserDefaults 迁移到 macOS Keychain
- [x] 正式 Release 日志不记录原文、译文或模型原始响应
- [ ] 确认“清空全部数据”是否需要同时清除历史、解析缓存和 API 配置
- [ ] 使用 Developer ID 签名并完成 Apple notarization，或明确长期保持 Beta 分发
- [ ] 优化 PhosphorSwift 资源体积（当前 App 约 100MB）
- [ ] 在一台干净 Mac 上完整验证首次安装、Gatekeeper、辅助功能授权和卸载

## GitHub 仓库创建前

- [ ] 初始化本地 Git 仓库
- [ ] 运行 secret scan
- [ ] 检查忽略文件，确保 tools/tmp、dev-diary、build、dist、个人工具配置和桌面截图未入库
- [ ] 确认 Package.resolved 已纳入版本控制
- [ ] 创建首次 commit，但不使用错误的 Git 身份

## GitHub Pages 发布前

- [ ] 在 docs/site-config.js 填写正确的 repository 与 release URL
- [ ] 将 reviewMode 改为 false
- [ ] 将页面 robots 从 noindex 改为允许索引
- [ ] 更新 docs/robots.txt
- [ ] 添加真实 canonical URL，并确保与 og:url 一致
- [ ] 生成并添加 1200×630 的绝对 URL Open Graph 图片
- [ ] 设置 Pages 来源为 main /docs
- [ ] 在真实 Pages URL 上验证社交分享卡片

## GitHub Release

- [ ] 创建 v0.1.0-beta.1 tag
- [ ] 创建 Draft Release
- [ ] 上传 dimmi-macOS.zip，不要把安装包提交到 Git 历史
- [ ] 添加 SHA-256 校验值
- [ ] 粘贴 CHANGELOG 中的发行说明
- [ ] 验证下载、解压、首次打开与版本号

