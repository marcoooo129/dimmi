# dimmi · 开发环境一次配置（30 秒）

## 为什么要做这一步

macOS 的 TCC（透明、同意和控制）数据库按 app 的签名身份识别 app。Xcode Debug 默认用 **adhoc 签名**，每次 build 都重新签，binary 哈希都变 → macOS 视为「不同的 app」→ **每次都要重新授权「辅助功能 / 屏幕录制」**。

解决：用你 Apple ID 的 **Apple Development** 证书签名，证书指纹稳定 → TCC 持久化授权。

只要 **0 元 Apple ID**（不需要付费 Apple Developer 账号）就够了。

---

## 一次性配置 30 秒

### 1. 打开 Xcode.app（不是 Cursor / VS Code）

```
open -a Xcode
```

### 2. 加 Apple ID

```
Xcode 菜单 → Settings…  (⌘,)
Accounts 标签
左下角点 ➕ 按钮
选  Apple ID
输入你的 Apple ID 和密码
点  Sign In
```

成功的话，**Apple ID** 那一行会出现你的邮箱、显示 `Personal Team`、带一个 10 位 team id（形如 `ABCDE12345`）。

### 3. 项目里选 Team

在 Xcode 打开本仓库：

```
文件 → 打开 → 选  意大利语快速翻译器/Frase.xcodeproj
```

等 Xcode 加载完：

```
左侧项目导航器 → 点最顶上的蓝色  Frase 项目图标
中间区域 → Signing & Capabilities 标签
Signing 里：
   Team:  ← 选你刚加的  Personal Team
勾选  Automatically manage signing  (默认就勾着)
```

`Bundle Identifier` 应该显示 `com.dimmi.app`（已经设好，不用改）。

Xcode 此时会自动下载 Apple Development 证书 + 注册 bundle id + 给 entitlements 配好。

### 4. 第一次 ⌘R

第一次会弹两次授权：

1. **辅助功能（Accessibility）**——读选中文本
2. **屏幕录制（Screen Recording）**——读屏幕坐标系的辅助

两步都点 **打开系统设置 → 隐私与安全 → 找到 dimmi → 打开开关 → 回到 Xcode 再跑一次**。

> macOS 上「屏幕录制」需要**完全退出并重启 app** 才会生效，所以第一次会要求你重 build。

### 5. 之后永远不用再授权

只要改代码 → Xcode ⌘R → **不再问授权**。
签名身份 = Apple ID 证书 × bundle id × machine identity，跨 build 稳定。

---

## 一个快捷脚本

为了避免每次都在 Xcode 改完回到终端手工 `xcodebuild`，可以用：

```bash
./tools/dev-rebuild.sh
```

自动找 Xcode 选的 Apple ID Team → 用 xcodebuild 编译 → 启动 app。

---

## 常见疑问

**问：要不要付费 Apple Developer Program（$99/年）？**
答：不要。免费 Apple ID 就能拿到 `Apple Development` 证书，足以 dev 阶段调试。$99 是发布到 Mac App Store 或公证用的，那是后期的事。

**问：换台机器 / 重装系统呢？**
答：新的 Apple ID 登录会拿到新证书，tcc 会重置授权。这没办法。

**问：adhoc 真的不行吗？**
答：adhoc 没有 CA 锚点，TCC 数据库无法稳定识别，每次 binary 内容变就重置。不行。

---

## 验证你已经搞定

跑：

```bash
./tools/check-env.sh
```

应该全部打 ✅。

