# Overview

架构图（Mermaid）与双层存储策略（默认 SQLite+VSS；可切 PG+pgvector/Timescale/AGE）。
DAG/flow 的 YAML 示例（email 助手的 RAG 流程）。
Go 引擎（FFI 导出 + 调度器骨架 + Ollama 适配器示例）。
Flutter 桌面端的 Dart FFI 绑定思路与「流式 UI」。
连接器设计：邮件（IMAP/Gmail/Outlook）、笔记文件夹、浏览器原生消息（Native Messaging）、WPS/Office（首版文件流为主）。
OTel 可观测性、隐私安全策略。
macOS/Windows/Linux 上架与打包要点（MAS/MSIX/Flatpak），以及脚本/目录结构和测试策略。
