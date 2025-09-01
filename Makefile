SHELL := /bin/bash
ROOT := $(shell pwd)

GOOS ?= $(shell go env GOOS)
GOARCH ?= $(shell go env GOARCH)

LIBNAME :=   $(if $(filter $(GOOS),darwin),libxda.dylib,     $(if $(filter $(GOOS),linux),libxda.so,       $(if $(filter $(GOOS),windows),xda.dll,libxda.so)))

.PHONY: init-db build-go flutter-create flutter-run build-pgshim clean

init-db:
	python3 scripts/init_db_sqlite.py

build-go:
	bash scripts/build_go.sh

flutter-create:
	@if [ ! -f app/pubspec.yaml ]; then \
	  flutter create --platforms=macos,windows,linux app; \
	fi
	# Overwrite lib/main.dart and pubspec.yaml with our templates
	cp -f app_templates/main.dart app/lib/main.dart
	cp -f app_templates/pubspec.yaml app/pubspec.yaml
	@echo 'OK. Flutter app prepared.'

flutter-run:
	cd app && flutter run -d macos || flutter run -d windows || flutter run -d linux

build-pgshim:
	cd rust/pgshim && cargo build

clean:
	rm -rf data/xda.db target
