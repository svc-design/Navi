SHELL := /bin/bash
ROOT  := $(shell pwd)

# ===== Go 平台与主机识别 =====
GOOS   ?= $(shell go env GOOS)
GOARCH ?= $(shell go env GOARCH)
# uname 在 Windows(MSYS/Cygwin) 会是 MINGW*；在 GitHub Actions Windows 原生是 OS=Windows_NT
UNAME_S := $(shell uname -s 2>/dev/null || echo Unknown)
OS_VAR  := $(OS)  # Windows 原生命令行下会有 OS=Windows_NT
ifeq ($(OS_VAR),Windows_NT)
  HOST_OS := Windows
else ifneq (,$(findstring MINGW,$(UNAME_S)))
  HOST_OS := Windows
else
  HOST_OS := $(UNAME_S) # Darwin / Linux / ...
endif

LIBNAME := $(if $(filter $(GOOS),darwin),libnavi_engine.dylib,\
	   $(if $(filter $(GOOS),linux),libnavi_engine.so,\
	   $(if $(filter $(GOOS),windows),navi_engine.dll,libnavi_engine.so)))

.DEFAULT_GOAL := build

.PHONY: all build init-db deps-go deps-linux build-go test-go build-pgshim \
	flutter-create flutter-build-host flutter-build-macos flutter-build-linux \
	flutter-build-windows run run-macos run-linux run-windows \
	flutter-run package package-host package-macos package-linux \
	package-windows clean doctor

all: build

# ===== 0) 环境自检（可选）=====
doctor:
	@echo "Host OS  : $(HOST_OS)"
	@echo "GOOS/ARCH: $(GOOS)/$(GOARCH)"
	@flutter --version || true
	@go version || true
	@rustc --version || true

# ===== 1) 初始化本地 SQLite（如有 data 目录可在脚本里处理不存在则创建）=====
init-db:
	python3 scripts/init_db_sqlite.py

# ===== 2) 准备 Go 依赖 =====
deps-go:
	cd engine && rm -f go.sum && go mod tidy && go mod verify

# 额外：Linux 桌面构建所需系统依赖
deps-linux:
	if command -v apt-get >/dev/null; then \
		sudo apt-get update && \
		sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev; \
	elif command -v dnf >/dev/null; then \
		sudo dnf install -y clang cmake ninja-build pkgconfig gtk3-devel xz-devel; \
	elif command -v zypper >/dev/null; then \
		sudo zypper install -y clang cmake ninja pkgconf-pkg-config gtk3-devel xz; \
	else \
		echo "Skip deps-linux (no supported package manager)"; \
	fi

# ===== 3) 构建 Go 引擎 =====
build-go:
	bash scripts/build_go.sh

# ===== 4) 运行 Go 测试 =====
test-go:
	cd engine && go test ./...

# ===== 5) 构建 Rust pgshim（release 模式）=====
# 使用：make build-pgshim            # 稳定工具链
# 或 USE_NIGHTLY=1 make build-pgshim  # 夜间工具链
build-pgshim:
	cd rust/pgshim && \
	if [ "$${USE_NIGHTLY:-0}" = "1" ]; then \
	  RUSTUP_TOOLCHAIN=nightly cargo build --release; \
	else \
	  cargo build --release; \
	fi

# ===== 6) 确保 Flutter 工程存在 & 补齐桌面平台（幂等）=====
flutter-create:
	@if [ ! -f app/pubspec.yaml ]; then \
	  echo "[create] init flutter app"; \
	  flutter create --platforms=macos,windows,linux app; \
	else \
	  echo "[upgrade] ensure desktop platforms exist"; \
	  (cd app && flutter create --platforms=macos,windows,linux .); \
	fi
	@if [ -f app_templates/main.dart ]; then \
	  cp -f app_templates/main.dart app/lib/main.dart; \
	fi
	@if [ -f app_templates/pubspec.yaml ]; then \
	  cp -f app_templates/pubspec.yaml app/pubspec.yaml; \
	fi
	@echo 'OK. Flutter app prepared (desktop enabled).'

# ===== 7) 按主机 OS 选择正确的 Flutter 桌面构建目标 =====
flutter-build-host: build-go build-pgshim flutter-create
ifeq ($(HOST_OS),Darwin)
	$(MAKE) flutter-build-macos
else ifeq ($(HOST_OS),Linux)
	$(MAKE) flutter-build-linux
else ifeq ($(HOST_OS),Windows)
	$(MAKE) flutter-build-windows
else
	@echo "Unsupported host OS: $(HOST_OS)"; exit 1
endif

flutter-build-macos: flutter-create
	cd app && flutter config --enable-macos-desktop && flutter build macos

flutter-build-linux: deps-linux flutter-create
	cd app && flutter config --enable-linux-desktop && flutter build linux

flutter-build-windows: flutter-create
	cd app && flutter config --enable-windows-desktop && flutter build windows

# ===== 8) 一键构建：数据库 -> Go -> Rust -> Flutter(按主机选择) =====
build: init-db deps-go build-go test-go build-pgshim flutter-build-host
	@echo "✅ Build done for $(HOST_OS) ($(GOOS)/$(GOARCH))."

# ===== 9) 便捷运行 =====
run: flutter-run

flutter-run:
	# 优先按主机平台运行，失败则尝试其他桌面目标
ifneq ($(HOST_OS),Windows)
	cd app && (flutter run -d $(if $(filter $(HOST_OS),Darwin),macOS,linux)) || flutter run -d windows || flutter run -d linux || flutter run -d macos
else
	cd app && flutter run -d windows || flutter run -d linux || flutter run -d macos
endif

run-macos:
	cd app && flutter run -d macos

run-linux:
	cd app && flutter run -d linux

run-windows:
	cd app && flutter run -d windows

# ===== 10) Package artifacts =====
package: package-host

package-host:
ifeq ($(HOST_OS),Darwin)
	$(MAKE) package-macos
else ifeq ($(HOST_OS),Linux)
	$(MAKE) package-linux
else ifeq ($(HOST_OS),Windows)
	$(MAKE) package-windows
else
	@echo "Unsupported host OS: $(HOST_OS)"; exit 1
endif

package-macos:
	OUT_DIR=app/build/macos/Build/Products/Release; \
	NAME=navi-macos-$(GOARCH); \
	if [ ! -d "$$OUT_DIR/Navi.app" ]; then echo "Not built yet. Run: make flutter-build-macos"; exit 1; fi; \
	hdiutil create -volname Navi -srcfolder "$$OUT_DIR/Navi.app" -ov -format UDZO "$$NAME.dmg"

package-linux:
	OUT_DIR=app/build/linux/$(if $(filter $(GOARCH),amd64),x64,$(GOARCH))/release/bundle; \
	NAME=navi-linux-$(GOARCH); \
	if [ ! -d "$$OUT_DIR" ]; then echo "Not built yet. Run: make flutter-build-linux"; exit 1; fi; \
	tar -C "$$OUT_DIR" -czf "$$NAME.tar.gz" .

package-windows:
	OUT_DIR=app/build/windows/$(if $(filter $(GOARCH),amd64),x64,$(GOARCH))/runner/Release; \
	NAME=navi-windows-$(GOARCH); \
	if [ ! -d "$$OUT_DIR" ]; then echo "Not built yet. Run: make flutter-build-windows"; exit 1; fi; \
	(cd "$$OUT_DIR" && 7z a "$$NAME.zip" .)

# ===== 11) 清理 =====
clean:
	rm -rf data/xda.db target
	# 如需清理 Flutter 构建产物，可追加：
	# rm -rf app/build app/linux app/macos app/windows
