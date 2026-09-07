#!/usr/bin/env bash
# build.sh — 一键编译 freebuff-proxy（Linux / macOS / WSL）
# 用法:
#   ./scripts/build.sh              # 当前平台
#   ./scripts/build.sh linux        # 指定平台
#   ./scripts/build.sh all          # 全部平台
#   VERSION=1.2.3 ./scripts/build.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_NAME="freebuff-proxy"
OUT_DIR="$REPO_ROOT/bin"

# 版本号：优先使用环境变量，其次从 git tag 读取，否则 dev
VERSION="${VERSION:-dev}"
if [ "$VERSION" = "dev" ] && command -v git &>/dev/null; then
  GIT_TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"
  [ -n "$GIT_TAG" ] && VERSION="$GIT_TAG"
fi

LD_FLAGS="-s -w -X main.version=${VERSION}"

# ── 颜色输出 ──────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*" >&2; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
ok()    { echo -e "${GREEN}[ OK ]${NC}  $*"; }

# ── 前置检查 ──────────────────────────────────────────────────
check_deps() {
  command -v go    &>/dev/null || error "缺少 go，请先安装 Go 1.21+"
  command -v node  &>/dev/null || error "缺少 node，请先安装 Node.js 18+"
  command -v npm   &>/dev/null || error "缺少 npm"
}

# ── 前端构建 ──────────────────────────────────────────────────
build_frontend() {
  info "Building frontend (Svelte 5 SPA)..."
  cd "$REPO_ROOT/frontend"
  if [ ! -d node_modules ]; then
    info "Installing frontend dependencies..."
    npm install --prefer-offline
  fi
  npx vite build
  ok "Frontend built → backend/internal/dashboard/dist/"
  cd "$REPO_ROOT"
}

# ── Go 编译 ───────────────────────────────────────────────────
build_go() {
  local goos="$1" arch="$2"
  local suffix=""
  [ "$goos" = "windows" ] && suffix=".exe"

  local out_file="${BIN_NAME}_${VERSION}_${goos}_${arch}${suffix}"
  local out_path="${OUT_DIR}/${out_file}"

  mkdir -p "$OUT_DIR"
  info "Compiling ${goos}/${arch} → ${out_file}"

  GOOS="$goos" GOARCH="$arch" CGO_ENABLED=0 \
    go build -ldflags "${LD_FLAGS}" \
    -o "$out_path" \
    ./backend/cmd/freebuff-proxy

  ok "Binary: ${out_path} ($(du -h "$out_path" | cut -f1))"
  echo "$out_path"
}

# ── 全平台编译 ────────────────────────────────────────────────
PLATFORMS=(
  "windows/amd64"
  "windows/arm64"
  "linux/amd64"
  "linux/arm64"
  "darwin/amd64"
  "darwin/arm64"
)

build_all() {
  info "Cross-compiling all platforms..."
  local outputs=()
  for p in "${PLATFORMS[@]}"; do
    IFS='/' read -r goos arch <<< "$p"
    out="$(build_go "$goos" "$arch")"
    outputs+=("$out")
  done
  echo ""
  ok "All binaries:"
  for f in "${outputs[@]}"; do
    echo "  ${f}"
  done
}

# ── 主入口 ────────────────────────────────────────────────────
main() {
  local target="${1:-current}"

  check_deps
  build_frontend

  case "$target" in
    current|.)
      # 探测当前 OS/ARCH
      local goos goarch
      goos="$(go env GOOS)"
      goarch="$(go env GOARCH)"
      build_go "$goos" "$goarch"
      ;;
    linux)      build_go linux amd64 ;;
    linux-arm)  build_go linux arm64 ;;
    macos)      build_go darwin amd64 ;;
    macos-arm)  build_go darwin arm64 ;;
    windows)    build_go windows amd64 ;;
    all)        build_all ;;
    *)
      error "未知目标: $target

用法:
  $0 [current|linux|linux-arm|macos|macos-arm|windows|all]

环境变量:
  VERSION=1.2.3   指定版本号（默认 dev 或 git tag）
"
      ;;
  esac
}

main "$@"
