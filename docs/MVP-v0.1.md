SQLite 换成“PG-SQLite（本地嵌入式，暴露 PostgreSQL 协议）”完全可行。做法是：底层仍用 SQLite(+ 向量扩展) 存储，上层用一个轻量 PG-wire 兼容层（“pg-wire shim”）把 PG 协议请求转译为 SQLite 的 SQL / 自定义函数调用。这样：

你的应用内部继续走本地嵌入式 DB（体积小、可上架）。

外部/周边工具（psql、Grafana、通用 PG 客户端）可以连到 127.0.0.1 的 PG 端口进行只对本机的读写。

MAS / MS Store 合规：商店版本默认关闭监听（仅内嵌存储）；开发者版/独立分发可开启 --pg-wire。

下面给出落地要点与骨架。

方案总览

存储引擎：SQLite + sqlite-vss（或 sqlite-vec）承载向量；fts5 做全文；WAL 模式。

协议层：实现 PG-wire（建议 Rust pgwire/Go pgproto3 其一），只覆盖我们需要的子集（Query/Bind/Execute/Txn/Portal）。

类型/函数桥接：把 PG 的类型与操作符映射到 SQLite 列类型与函数（见下）。

语法改写：拦截 CREATE EXTENSION vector/vector(n)/<-> 操作符并改写为 SQLite 的等价实现。

架构开关：

--db=tierA-pgsqlite（默认不开 PG-wire，仅内嵌）

--pg-wire=127.0.0.1:6432（可选，开发版开启）

关键映射（示例）
PG 概念	PG-SQLite 映射
uuid	TEXT + 生成函数
timestamptz	TEXT(ISO8601) 或 INTEGER(unix ms)
jsonb	JSON（SQLite 原生 JSON）+ 辅助函数
vector(n)	BLOB（存浮点数组）+ 自定义 distance_*()
pg_trgm 相似	fts5 + LIKE/距离函数
INSERT..ON CONFLICT	SQLite 原生支持（等价）
物化视图	表 + 触发器/任务（模拟）
<->（pgvector 距离）	改写为 distance_cosine(emb, ?) 或走 vss_search()

兼容声明：不追求 100% PG 语义；CTE/复杂 planner/extension 将按白名单策略逐步覆盖。ORM 若使用 PG 私有语法，需在驱动层做兼容开关。

DDL/查询改写示例

原（PG 预期）

CREATE EXTENSION IF NOT EXISTS vector;
CREATE TABLE kb_chunk (
  id uuid PRIMARY KEY,
  kind text NOT NULL,
  text text NOT NULL,
  meta jsonb NOT NULL,
  embedding vector(1024)
);
-- 近邻检索
SELECT id, 1 - (embedding <-> $1) AS sim
FROM kb_chunk
ORDER BY embedding <-> $1
LIMIT 10;


改写（SQLite 承载）

-- EXTENSION 吞掉为 no-op
CREATE TABLE IF NOT EXISTS kb_chunk (
  id TEXT PRIMARY KEY,
  kind TEXT NOT NULL,
  text TEXT NOT NULL,
  meta JSON NOT NULL,
  embedding BLOB          -- float32[1024]
);
-- 通过 vss/vectors 或自定义距离函数
SELECT id, 1 - distance_cosine(embedding, :qemb) AS sim
FROM kb_chunk
ORDER BY distance_cosine(embedding, :qemb) ASC
LIMIT 10;

协议层（PG-wire shim）职责

握手/鉴权：只支持本地回环 + 明文/Trust（可选本地口令）。

SQL 解析与白名单路由：

能直通的 SQL（绝大多数 DML/简单 DDL）→ 直接交给 SQLite 执行。

需要改写的 SQL（如 <->、vector(n)、jsonb 专属函数）→ 语法树/正则改写再执行。

元信息视图：提供最小可用的 pg_catalog 只读行集（列、表、类型），糊住常见客户端探测。

扩展模拟：CREATE EXTENSION vector 返回 OK，pg_extension 里挂个只读行。

Prepared/Portal：支持 Bind/Execute（便于 ORMs）。

事务：BEGIN/COMMIT/ROLLBACK 直通 SQLite 事务。

语言建议：Rust 实现协议层更成熟（pgwire crate 广泛用于时序/流式数据库），底层用 rusqlite 调 SQLite；也可用 Go（jackc/pgproto3）实现，但需要多写一些协议细节。

向量检索接口

sqlite-vss：建 vss0 索引列，提供 vss_search(k, 'cosine')。

Shim 侧把 <-> 改写为 vss_search() 或 distance_cosine()。

嵌入向量存 float32[]→BLOB；编码/解码在适配器中完成。

运行与合规

macOS（MAS）：默认关闭 --pg-wire（避免“本机服务”被判定为后台服务）。仍可在应用内使用 SQLite。DevID 分发可开放本地 PG-wire（仅 127.0.0.1）。

Windows/Linux：可开 --pg-wire=127.0.0.1:6432。不启动外部守护，与主进程同生命周期。

端口可改 UDS/命名管道（更隐蔽且快）。

项目落地改动（对你现有蓝图）

--db 新增枚举：sqlite（旧）/pgsqlite（新，默认仍用 sqlite 存储）。

engine/repo：抽象保持不变；新增 repo_pgsqlite，对上层完全透明。

cmd：增加 --pg-wire 参数开关（Dev 版）。

tests：加一组 psql 端到端冒烟（DDL/CRUD/参数化查询/事务/向量 TOPK）。

快速 PoC 里程碑

协议层最小化：支持 SELECT 1、SHOW server_version、BEGIN/COMMIT。

直通查询：CREATE TABLE/INSERT/SELECT 到 SQLite。

JSON/向量改写：跑通 kb_chunk 的 TOP-K。

Catalog 视图：psql \d 可列出表与列。

稳定性：Prepared + Portal + 大字段流式。
