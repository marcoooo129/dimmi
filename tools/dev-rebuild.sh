#!/usr/bin/env bash
# 开发期快速 rebuild + 启动 dimmi
#
# 用法（在仓库根目录）：
#     ./tools/dev-rebuild.sh
#
# 行为：
#   1. 有 Apple Development 证书时使用稳定开发签名
#   2. 无证书时使用带显式 designated requirement 的 ad-hoc 签名
#   3. 从证书 / 项目配置读取 DEVELOPMENT_TEAM（可选）
#   4. 先杀旧实例，再 build，再启动，输出 PID
#
# 这个脚本等价于 Xcode 里 ⌘R，但可以直接从终端跑，CI / 远程会话也能用。

set -euo pipefail

cd "$(dirname "$0")/.."

BUNDLE_ID="com.frase.app"
SCHEME="dimmi"
CONFIG="Debug"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { printf "${GREEN}[dev-rebuild]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[dev-rebuild]${NC} %s\n" "$*"; }
fail() { printf "${RED}[dev-rebuild]${NC} %s\n" "$*" >&2; exit 1; }

# 1) 取 Apple Development 证书中的 Team ID；没有也不阻塞本地构建。
TEAM="$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -nE '/Apple Development/s/.*\(([A-Z0-9]{10})\).*/\1/p' \
    | head -1 || true)"

if [ -n "$TEAM" ]; then
    log "使用 Apple Development 签名（Team ${TEAM}）"
else
    warn "未找到 Apple Development 证书，将使用带稳定 DR 的 ad-hoc 签名。"
fi

# 3) 杀掉旧的
killall dimmi 2>/dev/null || true
sleep 0.3

# 4) 编译
log "开始 xcodebuild (${CONFIG}) …"
mkdir -p ./build
BUILD_ARGS=(
    -project Frase.xcodeproj
    -scheme "$SCHEME"
    -configuration "$CONFIG"
    -destination "platform=macOS"
    -derivedDataPath ./build
)
if [ -n "$TEAM" ]; then
    BUILD_ARGS+=(
        CODE_SIGN_IDENTITY="Apple Development"
        CODE_SIGN_STYLE=Automatic
        DEVELOPMENT_TEAM="$TEAM"
    )
else
    BUILD_ARGS+=(
        CODE_SIGNING_ALLOWED=NO
        CODE_SIGNING_REQUIRED=NO
    )
fi

xcodebuild "${BUILD_ARGS[@]}" build 2>&1 | tee ./build/build.log | tail -5
grep -E "BUILD (SUCCEEDED|FAILED)" ./build/build.log >/dev/null \
    || fail "看不到 BUILD SUCCEEDED 行"

# 5) 原地更新唯一产物 dist/dimmi.app（2026-07-16 定的铁律：
#    全机只保留这一份 dimmi，构建产物 rsync 进去，不再新增副本/新 build 目录。
#    TCC 辅助功能授权按「路径 + 代码身份」记忆——app 永远在同一路径，授权才稳。）
PRODUCT="./build/Build/Products/Debug/dimmi.app"
[ -d "$PRODUCT" ] || fail "产物不存在：$PRODUCT"

if [ -z "$TEAM" ]; then
    ./tools/sign-local.sh "$PRODUCT"
else
    codesign --verify --deep --strict --verbose=2 "$PRODUCT"
fi

APP="./dist/dimmi.app"
mkdir -p ./dist
rsync -a --delete "$PRODUCT/" "$APP/"
log "已原地更新 $APP"

log "启动 dimmi.app ..."
open "$APP"
sleep 1

PID="$(pgrep -x dimmi | head -1 || true)"
if [ -n "$PID" ]; then
    log "✅ PID $PID  ·  BUNDLE_ID $BUNDLE_ID"
    if [ -n "$TEAM" ]; then
        log "Apple Development 签名稳定，TCC 授权通常可跨重建保留。"
    else
        log "ad-hoc 签名已固定 DR：designated => identifier \"$BUNDLE_ID\""
        log "后续重建的 cdhash 可变，但代码身份要求保持一致。"
    fi
else
    fail "启动了但找不到 dimmi 进程（看 Console.app）"
fi
