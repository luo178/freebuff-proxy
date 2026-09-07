<#
.SYNOPSIS
    一键编译 freebuff-proxy（Windows / PowerShell Core）
.DESCRIPTION
    支持当前平台和交叉编译全平台，版本注入到二进制。

    用法:
      .\scripts\build.ps1                       # 当前平台
      .\scripts\build.ps1 -Target linux         # Linux amd64
      .\scripts\build.ps1 -Target all           # 全部 6 平台
      $env:VERSION = "1.2.3"; .\scripts\build.ps1
#>

[CmdletBinding()]
param(
    [ValidateSet('current', 'windows', 'linux', 'linux-arm64', 'darwin', 'darwin-arm64', 'all')]
    [string]$Target = 'current',

    [string]$Version = $env:VERSION
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot | Split-Path -Parent
$BinName  = 'freebuff-proxy'
$OutDir   = Join-Path $RepoRoot 'bin'

# ── 颜色 ──────────────────────────────────────────────────────
function Write-Info  { Write-Host "[INFO]  $args" -ForegroundColor Cyan }
function Write-Warn  { Write-Host "[WARN]  $args" -ForegroundColor Yellow }
function Write-Error $($args) { Write-Host "[ERROR] $args" -ForegroundColor Red; exit 1 }
function Write-Ok    { Write-Host " [ OK ] $args" -ForegroundColor Green }

# ── 版本 ──────────────────────────────────────────────────────
if (-not $Version -or $Version -eq 'dev') {
    $gitTag = git describe --tags --abbrev=0 2>$null
    if ($gitTag) { $Version = $gitTag.Substring(1) }  # 去掉 v 前缀
    if (-not $Version -or $Version -eq 'dev') { $Version = 'dev' }
}
$Env:VERSION_VAR = $Version

$ldFlags = "-s -w -X main.version=$Version"

# ── 依赖检查 ──────────────────────────────────────────────────
function Test-Cmd($cmd) {
    return $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
}
if (-not (Test-Cmd go))    { Write-Error "缺少 go，请先安装 Go 1.21+" }
if (-not (Test-Cmd node))  { Write-Error "缺少 node，请先安装 Node.js 18+" }
if (-not (Test-Cmd npm))   { Write-Error "缺少 npm" }
if (-not (Test-Cmd npx))   { Write-Error "缺少 npx" }

# ── 前端构建 ──────────────────────────────────────────────────
function Build-Frontend {
    Write-Info 'Building frontend (Svelte 5 SPA)...'
    Push-Location (Join-Path $RepoRoot 'frontend')
    try {
        if (-not (Test-Path 'node_modules')) {
            Write-Info 'Installing frontend dependencies...'
            npm install --prefer-offline
        }
        npx vite build
    } finally {
        Pop-Location
    }
    Write-Ok 'Frontend built → backend/internal/dashboard/dist/'
}

# ── Go 编译 ───────────────────────────────────────────────────
function Build-Go($goos, $goarch) {
    $suffix = if ($goos -eq 'windows') { '.exe' } else { '' }
    $outFile = "$BinName`_${Version}`_${goos}`_${goarch}${suffix}"
    $outPath = Join-Path $OutDir $outFile

    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

    Write-Info "Compiling ${goos}/${goarch} → ${outFile}"
    $env:GOOS    = $goos
    $env:GOARCH  = $goarch
    $env:CGO_ENABLED = '0'

    & go build -ldflags $ldFlags -o $outPath ./backend/cmd/freebuff-proxy

    $size = (Get-Item $outPath).Length
    Write-Ok "Binary: $outPath  ($([math]::Round($size/1MB, 1)) MB)"
    return $outPath
}

# ── 全平台 ────────────────────────────────────────────────────
$Platforms = @(
    @{ os='windows'; arch='amd64' },
    @{ os='windows'; arch='arm64'  },
    @{ os='linux'  ; arch='amd64'  },
    @{ os='linux'  ; arch='arm64'  },
    @{ os='darwin' ; arch='amd64'  },
    @{ os='darwin' ; arch='arm64'  }
)

function Build-All {
    Write-Info 'Cross-compiling all platforms...'
    $outputs = @()
    foreach ($p in $Platforms) {
        $outputs += Build-Go $p.os $p.arch
    }
    Write-Host ''
    Write-Ok 'All binaries:'
    $outputs | ForEach-Object { Write-Host "  $_" }
}

# ── 主入口 ────────────────────────────────────────────────────
Build-Frontend

switch ($Target) {
    'current'  {
        $goos    = (go env GOOS)
        $goarch  = (go env GOARCH)
        Build-Go $goos $goarch
    }
    'windows'  { Build-Go 'windows' 'amd64' }
    'linux'    { Build-Go 'linux'  'amd64' }
    'linux-arm64' { Build-Go 'linux' 'arm64' }
    'darwin'   { Build-Go 'darwin' 'amd64' }
    'darwin-arm64' { Build-Go 'darwin' 'arm64' }
    'all'      { Build-All }
}
