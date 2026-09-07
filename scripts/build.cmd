@echo off
REM build.cmd — 一键编译 freebuff-proxy (Windows CMD)
REM 用法:
REM   build.cmd                 当前平台
REM   build.cmd linux           Linux amd64
REM   build.cmd all             全部平台
REM   set VERSION=1.2.3&& build.cmd

setlocal enabledelayedexpansion

cd /d "%~dp0.."

set BIN_NAME=freebuff-proxy
set OUT_DIR=bin
set VERSION=%VERSION%

if "!VERSION!" == "" set VERSION=dev
if "!VERSION!" == "dev" (
    for /f "tokens=*" %%t in ('git describe --tags --abbrev=0 2^>nul') do set GIT_TAG=%%t
    if not "!GIT_TAG!" == "" set VERSION=!GIT_TAG:v=!
)

set LD_FLAGS=-s -w -X main.version=!VERSION!

echo [INFO]  Version: !VERSION!

REM 前置检查
where go    >nul 2>&1 || (echo [ERROR] 缺少 go，请先安装 Go 1.21+ & exit /b 1)
where node  >nul 2>&1 || (echo [ERROR] 缺少 node，请先安装 Node.js 18+ & exit /b 1)
where npm   >nul 2>&1 || (echo [ERROR] 缺少 npm & exit /b 1)

REM 前端构建
echo [INFO]  Building frontend...
cd frontend
if not exist node_modules (
    echo [INFO]  Installing npm dependencies...
    npm install --prefer-offline
)
npx vite build
cd ..
echo [ OK ]  Frontend built

REM 创建输出目录
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

REM 按目标编译
set TARGET=%~1

if "!TARGET!" == "" set TARGET=current
if "!TARGET!" == "all" goto :build_all

if "!TARGET!" == "current" (
    for /f "tokens=1,2" %%a in ('go env GOOS GOARCH') do (
        set GOOS=%%a & set GOARCH=%%b
    )
    call :build_go
) else if "!TARGET!" == "windows" (
    set GOOS=windows & set GOARCH=amd64
    call :build_go
) else if "!TARGET!" == "linux" (
    set GOOS=linux & set GOARCH=amd64
    call :build_go
) else if "!TARGET!" == "linux-arm64" (
    set GOOS=linux & set GOARCH=arm64
    call :build_go
) else (
    echo [ERROR] 未知目标: !TARGET!
    echo Usage: build.cmd [current^|windows^|linux^|linux-arm64^|all]
    exit /b 1
)
goto :done

:build_all
echo [INFO]  Cross-compiling all platforms...
for %%p in (windows/amd64 windows/arm64 linux/amd64 linux/arm64 darwin/amd64 darwin/arm64) do (
    for /f "tokens=1,2 delims=/" %%a in ("%%p") do (
        set GOOS=%%a & set GOARCH=%%b
        call :build_go
    )
)
goto :done

:build_go
set SUFFIX=
if "!GOOS!" == "windows" set SUFFIX=.exe
set OUT_FILE=%BIN_NAME%_!VERSION!_!GOOS!_!GOARCH!%SUFFIX%
echo [INFO]  Compiling !GOOS!/!GOARCH! -> !OUT_FILE!
set GOOS=!GOOS!
set GOARCH=!GOARCH!
set CGO_ENABLED=0
go build -ldflags "%LD_FLAGS%" -o "%OUT_DIR%\!OUT_FILE!" ./backend/cmd/freebuff-proxy
for %%f in ("%OUT_DIR%\!OUT_FILE!") do echo [ OK ]  !OUT_FILE! (%%~zf bytes)
goto :eof

:done
echo.
echo Done. Binaries in: %CD%\%OUT_DIR%\
endlocal
