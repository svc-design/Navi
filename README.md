# Navi Assistant — Minimal Runnable Skeleton (Dataflow×FP, Local-first)

This repository is a **minimal runnable** scaffold aligned with the blueprint:
- Flutter desktop shell (UI) with **Dart FFI** calling a Go shared library.
- Go engine (FFI) with a tiny **RAG** pipeline on **SQLite** (local).
- Optional **pg-wire shim (Rust)** skeleton (compiles; simple SELECT 1; SQLite passthrough is TODO).
- Schema/flow files and scripts to init demo DB with a few chunks.

> Goal: after prerequisites, you can *run the Flutter app*, type a query, and get a RAG answer from local chunks.

## Prerequisites
- Flutter SDK (3.22+), Dart 3+
- Go 1.21+
- Rust (cargo), nightly not required
- SQLite3 (CLI) — optional, for inspection

## Quick start

```bash
# 1) Init demo DB (creates ./data/xda.db with sample docs & embeddings)
make init-db

# 2) Build Go FFI shared lib
make build-go

# 3) Create Flutter app scaffolding & run
make flutter-create           # one-time
make flutter-run              # runs in debug

# (Optional) Build Rust pg-wire shim (listens on 127.0.0.1:6432)
make build-pgshim
./target/debug/pgshim --db ./data/xda.db --listen 127.0.0.1:6432
```

### Notes
- The RAG flow uses a **naive bag-of-words embedding** to avoid external models. Replace with Ollama later.
- If `sqlite-vss` is present, init script attempts to create a VSS index; otherwise it falls back silently.
- Mac App Store builds should **not** run `pgshim` (no background listener).

## Layout

```
navi/
├─ app/                   # Flutter app (created by make flutter-create)
│  ├─ lib/main.dart
│  └─ pubspec.yaml
├─ engine/                # Go FFI + minimal RAG
│  ├─ ffi/ffi.go
│  ├─ repo/sqlite_repo.go
│  ├─ rag/simple.go
│  └─ go.mod
├─ rust/pgshim/           # Rust PG-wire shim (skeleton)
│  ├─ Cargo.toml
│  └─ src/main.rs
├─ flows/rag_email.yaml
├─ schemas/
│  └─ event_envelope.json
├─ scripts/
│  ├─ init_db_sqlite.py
│  └─ build_go.sh
├─ data/                  # created at runtime
├─ Makefile
└─ README.md
```

## License
GNU General Public License v3.0
