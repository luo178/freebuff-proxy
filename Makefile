# Makefile — thin wrapper over Taskfile.yml (the canonical runner, issue #299).
# `task --list` shows the full set; these mirrors exist only for muscle memory.

.PHONY: all build web-build build-proxy test test-race lint web-dev dev-proxy verify verify-full clean \
        build-current build-windows build-linux build-linux-arm build-macos build-macos-arm build-all

all: build

web-build:
	task frontend:build

build-proxy:
	task go:build

build:
	task build

# 跨平台构建快捷目标
build-current:
	task go:build

build-windows:
	task go:build:windows:amd64

build-linux:
	task go:build:linux:amd64

build-linux-arm:
	task go:build:linux:arm64

build-macos:
	task go:build:darwin:amd64

build-macos-arm:
	task go:build:darwin:arm64

build-all:
	task go:build:all

test:
	task test

test-race:
	task test:race

lint:
	task lint

web-dev:
	task frontend:dev

dev-proxy:
	task dev

clean:
	task clean

verify:
	task verify

verify-full:
	task verify:full
