#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cd engine
case "$(go env GOOS)" in
  darwin) go build -buildmode=c-shared -o ../app/${LIBNAME:-libnavi_engine.dylib} ./ffi ;;
  linux)  go build -buildmode=c-shared -o ../app/${LIBNAME:-libnavi_engine.so} ./ffi ;;
  windows) go build -buildmode=c-shared -o ../app/${LIBNAME:-navi_engine.dll} ./ffi ;;
  *) echo "Unsupported GOOS"; exit 1;;
esac
echo "Built shared library into app/${LIBNAME:-libnavi_engine.so}"
