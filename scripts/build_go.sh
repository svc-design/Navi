#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cd engine
case "$(go env GOOS)" in
  darwin) go build -buildmode=c-shared -o ../app/${LIBNAME:-libxda.dylib} ./ffi ;;
  linux)  go build -buildmode=c-shared -o ../app/${LIBNAME:-libxda.so} ./ffi ;;
  windows) go build -buildmode=c-shared -o ../app/${LIBNAME:-xda.dll} ./ffi ;;
  *) echo "Unsupported GOOS"; exit 1;;
esac
echo "Built shared library into app/${LIBNAME:-libxda.so}"
