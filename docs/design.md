Flutter 桌面模板（Dart FFI 调 Go 动态库）

Go FFI 引擎（SQLite 本地库、简易 RAG 流可跑通）

Rust 版 pg-wire shim（可 SELECT 1，并支持把简单 SELECT 透传到 SQLite）

初始化脚本（生成 data/xda.db、内置少量示例 chunk & “简易向量”）

Flow/Schemas、Makefile、README

下载：xdesktopagent_skeleton.zip

怎么跑（最短路径）
# 0) 解压
unzip xdesktopagent_skeleton.zip && cd xdesktopagent

# 1) 初始化本地 DB（./data/xda.db）
make init-db

# 2) 构建 Go FFI 动态库（输出到 app/ 下）
make build-go

# 3) 生成 Flutter 工程（一次性）
make flutter-create

# 4) 运行桌面应用（选择你的平台设备）
make flutter-run


运行后，在输入框里输入问题（比如 “what is XDesktopAgent?” / “How does Flutter FFI work?”），会基于本地 chunks 做一次“简易 RAG”召回并生成摘要（当前 demo 未连 LLM，只做检索+模板回答，便于验证数据流）。

可选：启动 pg-wire shim（Rust）
make build-pgshim
./target/debug/pgshim --db ./data/xda.db --listen 127.0.0.1:6432
# 另一个终端：
psql "host=127.0.0.1 port=6432 user=demo dbname=demo" -c "SELECT 1"
psql "host=127.0.0.1 port=6432 user=demo dbname=demo" -c "SELECT id,text FROM kb_chunk LIMIT 5"


说明：当前 shim 支持 SELECT 的基本透传，INSERT/UPDATE/事务 等可按需扩展。商店版请默认关闭监听。

下一步建议

把 Ollama 接入到 Go 侧（engine/adapters/ollama.go）替换 demo 的模板回答。

若系统装有 sqlite-vss，可在 scripts/init_db_sqlite.py 里把 vss0 初始化开放（现已容错）。

按蓝图接入 IMAP/Notes/Browser Native Messaging 作为 Source，填充 kb_chunk。

Mac App Store / MS Store 打包时，保留 SQLite tier，禁用 pgshim 背景监听。

需要我把 Ollama 适配器和一个真正的流式 UI（SSE/分块）也补上吗？ 

您说：
UI部分是否符合 这两个参考截图设计
ChatGPT 说：

我对比了你刚上传的两张参考截图（白底界面，中间一个小图标，下方是圆角输入框/气泡式消息列表），和当前生成的 Flutter UI 模板：

✅ 整体结构

顶部 AppBar + 输入框区域 → 可以删掉 AppBar，直接保留一个居中的 logo/图标。

输入框目前是 TextField + 按钮，截图里是圆角输入框居中、带 placeholder「Send a message」。

✅ 消息流样式

截图里的对话是气泡样式（左侧/右侧圆角小块），而我生成的只是一个长 Text。

Flutter 可以用 ListView + Align + Container(decoration: BoxDecoration(...)) 来实现类似 ChatGPT 的气泡。

✅ 底部控制区

参考图里在输入框右边有 模型选择下拉 + 开关按钮。目前模板里没有，可以在底部 Row 里加 DropdownButton（模型选择）和 IconButton（Turbo/Run）。

⚠️ 中间图标（小猫/羊驼形象）

Flutter 里需要放一张 SVG/PNG 资源或使用 Icon(Icons.pets) 占位，保持居中显示。

需要调整的点

去掉默认 AppBar，整体背景保持纯白。

在 Scaffold body 里用 Column：

上方 Expanded → 聊天气泡流（ListView）。

中间（当没有消息时）→ 显示一只占位图标（参考截图）。

下方 → 圆角输入框 + 发送按钮 + 模型选择下拉。

聊天气泡样式：左右对齐、背景色浅灰/浅蓝、圆角大。
