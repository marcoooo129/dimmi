#!/usr/bin/env bash
# 诊断 dimmi 开发环境配置。
# 跑完会告诉你卡在哪一步。

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { printf "${GREEN}  ✅ %s${NC}\n" "$*"; }
warn() { printf "${YELLOW}  ⚠️  %s${NC}\n" "$*"; }
ng()   { printf "${RED}  ❌ %s${NC}\n" "$*"; }

printf "\n=== dimmi 开发环境诊断 ===\n\n"

# 1. macOS
printf "1. macOS\n"
os="$(sw_vers -productVersion)"
ok "$os"

# 2. Xcode 命令行工具
printf "\n2. Xcode CLT\n"
if xcode-select -p >/dev/null 2>&1; then
    ok "$(xcode-select -p)"
else
    ng "没装 Xcode CLT，跑 xcode-select --install"
fi

# 3. Xcode.app
printf "\n3. Xcode.app\n"
XCODE_APP="$(/usr/bin/mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" 2>/dev/null | head -1)"
if [ -n "$XCODE_APP" ]; then
    ok "$XCODE_APP"
else
    warn "没装 Xcode（这不是 blocker，只是不方便看 Signing UI）"
fi

# 4. Apple ID 登录（可选）
printf "\n4. Apple ID（可选，仅用于稳定开发签名）\n"
if defaults read com.apple.dt.Xcode DVTDeveloperAccountManagerAppleIDLists 2>/dev/null | grep -q "appleID"; then
    EMAIL="$(defaults read com.apple.dt.Xcode DVTDeveloperAccountManagerAppleIDLists 2>/dev/null \
             | grep -E "^\s+[a-zA-Z0-9._-]+@.* = " | head -1 | sed -E 's/.*"\s*([^"]+)".*/\1/')"
    ok "Apple ID 已登录：${EMAIL:-<未识别>}"
else
    warn "Xcode 没登录 Apple ID；dev-rebuild 会使用带显式稳定 DR 的 ad-hoc 签名。"
fi

# 5. Apple Development 证书
printf "\n5. Apple Development 证书\n"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "Apple Development"; then
    ok "$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development")"
else
    warn "还没生成 Apple Development 证书"
    printf "    dev-rebuild 会嵌入固定 bundle identifier DR；公开分发仍需 Developer ID。\n"
fi

# 6. 项目配置
printf "\n6. 项目配置\n"
cd "$(dirname "$0")/.."
if grep -q 'PRODUCT_BUNDLE_IDENTIFIER = com.frase.app' Frase.xcodeproj/project.pbxproj; then
    ok "Bundle ID = com.frase.app"
else
    ng "Bundle ID 不对"
fi
if xcodebuild -project Frase.xcodeproj -list 2>/dev/null | grep -Eq '^[[:space:]]+dimmi$'; then
    ok "Scheme = dimmi"
else
    ng "找不到 dimmi scheme"
fi
if grep -q 'CODE_SIGN_STYLE = Automatic' Frase.xcodeproj/project.pbxproj; then
    ok "CODE_SIGN_STYLE = Automatic"
else
    ng "签名风格不是 Automatic"
fi
if grep -q 'ENABLE_APP_SANDBOX = NO' Frase.xcodeproj/project.pbxproj; then
    ok "App Sandbox = NO（开发期正确）"
else
    warn "Sandbox = ON（测试时每次 build 都会重置 TCC？依然可以，只要签名稳定）"
fi

# 7. 现有 TCC 状态
printf "\n7. 现有 TCC 授权\n"
DB="$HOME/Library/Application Support/com.apple.TCC/TCC.db"
if [ -f "$DB" ]; then
    if sqlite3 "$DB" "SELECT service, client FROM access WHERE (client = 'com.frase.app' OR client LIKE '%dimmi%') AND auth_value=2" 2>/dev/null | grep -q .; then
        ok "TCC 已有 dimmi 授权条目："
        sqlite3 "$DB" "SELECT '    ' || service || ' ← ' || client FROM access WHERE (client = 'com.frase.app' OR client LIKE '%dimmi%') AND auth_value=2" 2>/dev/null | sed 's/$//'
    else
        printf "    （还没授权，第一次启动会弹窗）\n"
    fi
else
    printf "    TCC.db 不存在或无权限读\n"
fi

# 8. 上一次运行的 app 签名身份
printf "\n8. 上次 build 的 app 签名状态\n"
LAST_APP="$(/usr/bin/mdfind "kMDItemCFBundleIdentifier == 'com.frase.app'" 2>/dev/null | head -1)"
if [ -n "$LAST_APP" ]; then
    SIG="$(codesign -dvvv "$LAST_APP" 2>&1 | grep -E "Signature=|Identifier=|TeamIdentifier=")"
    DR="$(codesign -d -r- "$LAST_APP" 2>&1 | sed -n '/^[#[:space:]]*designated =>/p')"
    echo "$SIG" | sed 's/^/    /'
    printf "    DR=%s\n" "${DR:-<none>}"
    if echo "$SIG" | grep -q "adhoc"; then
        if [ "$DR" = 'designated => identifier "com.frase.app"' ]; then
            ok "当前是 ad-hoc 签名，且显式 DR 稳定（不依赖 cdhash）"
        else
            warn "当前是普通 ad-hoc 签名：DR 依赖 cdhash，重建后 TCC 可能重新询问。"
            printf "    请用 ./tools/dev-rebuild.sh 或 ./tools/release-package.sh 重建。\n"
        fi
    fi
else
    printf "    找不到 dimmi.app — 还从没 build 过\n"
fi

printf "\n=== 总结 ===\n\n"
if defaults read com.apple.dt.Xcode DVTDeveloperAccountManagerAppleIDLists 2>/dev/null | grep -q "appleID"; then
    ok "Apple ID 已登录。可直接运行：./tools/dev-rebuild.sh"
else
    ok "Apple ID 非必需。./tools/dev-rebuild.sh 将使用带显式稳定 DR 的 ad-hoc 签名。"
fi
