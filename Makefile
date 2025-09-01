SHELL := /bin/bash
ROOT  := $(shell pwd)

GOOS   ?= $(shell go env GOOS)
GOARCH ?= $(shell go env GOARCH)
HOST_OS := $(shell uname -s)

LIBNAME := $(if $(filter $(GOOS),darwin),libnavi_engine.dylib,\
	   $(if $(filter $(GOOS),linux),libnavi_engine.so,\
	   $(if $(filter $(GOOS),windows),navi_engine.dll,libnavi_engine.so)))

.DEFAULT_GOAL := build

.PHONY: all build init-db deps-go build-go test-go build-pgshim flutter-create \
	flutter-build-host flutter-build-macos flutter-build-linux \
	flutter-build-windows run run-macos run-linux run-windows \
	flutter-run clean

all: build

# 1) 初始化本地 SQLite（如有 data 目录可在脚本里处理不存在则创建）
init-db:
	python3 scripts/init_db_sqlite.py

# 2) 准备 Go 依赖
deps-go:
	cd engine && rm -f go.sum && go mod tidy && go mod verify

# 3) 构建 Go 引擎（你的脚本里可产出 $(LIBNAME)）
build-go:
	bash scripts/build_go.sh

# 4) 运行 Go 测试
test-go:
	cd engine && go test ./...

# 5) 构建 Rust pgshim（release 模式）
# 使用：make build-pgshim            # 稳定工具链
# 或 USE_NIGHTLY=1 make build-pgshim  # 夜间工具链
build-pgshim:
	cd rust/pgshim && \
	if [ "$${USE_NIGHTLY:-0}" = "1" ]; then \
	  RUSTUP_TOOLCHAIN=nightly cargo build --release; \
	else \
	  cargo build --release; \
	fi

# 6) 确保 Flutter 工程已存在并覆盖模板
flutter-create:
	@if [ ! -f app/pubspec.yaml ]; then \
	  flutter create --platforms=macos,windows,linux app; \
	fi
	cp -f app_templates/main.dart app/lib/main.dart
	cp -f app_templates/pubspec.yaml app/pubspec.yaml
	@echo 'OK. Flutter app prepared.'

# 7) 按主机 OS 选择正确的 Flutter 桌面构建目标
flutter-build-host: build-go build-pgshim
ifeq ($(HOST_OS),Darwin)
	$(MAKE) flutter-build-macos
else ifeq ($(HOST_OS),Linux)
	$(MAKE) flutter-build-linux
else ifneq (,$(findstring MINGW,$(HOST_OS)))
	$(MAKE) flutter-build-windows
else
	@echo "Unsupported host OS: $(HOST_OS)"; exit 1
endif

flutter-build-macos:
	cd app && flutter build macos

flutter-build-linux:
	cd app && flutter build linux

flutter-build-windows:
	cd app && flutter build windows

# 8) 一键构建：数据库 -> Go -> Rust -> Flutter(按主机选择)
build: init-db deps-go build-go test-go build-pgshim flutter-build-host
	@echo "✅ Build done for $(HOST_OS) ($(GOOS)/$(GOARCH))."

# 便捷运行
run: flutter-run

flutter-run:
	cd app && flutter run -d macos || flutter run -d windows || flutter run -d linux

run-macos:
	cd app && flutter run -d macos

run-linux:
	cd app && flutter run -d linux

run-windows:
	cd app && flutter run -d windows

# 清理（保留 Flutter 工程；若要清理 app/build 可追加）
clean:
	rm -rf data/xda.db target
