#!/usr/bin/env python3
import os, sqlite3, json, math, random, time, pathlib

root = os.path.dirname(os.path.dirname(__file__))
db_path = os.path.join(root, "data", "xda.db")
os.makedirs(os.path.join(root, "data"), exist_ok=True)

def embed(text, dim=64):
    # Naive bag-of-words hashing to float vector
    vec = [0.0] * dim
    for tok in text.lower().split():
        h = hash(tok) % dim
        vec[h] += 1.0
    # l2 normalize
    norm = math.sqrt(sum(v*v for v in vec)) or 1.0
    return [v / norm for v in vec]

conn = sqlite3.connect(db_path)
c = conn.cursor()

# Enable JSON1
c.execute("PRAGMA journal_mode=WAL;")

# Try loading sqlite-vss if present (won't fail if missing)
try:
    c.execute("SELECT load_extension('vss0')")
except Exception:
    pass

c.executescript("""CREATE TABLE IF NOT EXISTS kb_doc (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  kind TEXT NOT NULL,
  meta JSON
);
CREATE TABLE IF NOT EXISTS kb_chunk (
  id TEXT PRIMARY KEY,
  doc_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  text TEXT NOT NULL,
  meta JSON NOT NULL,
  embedding BLOB
);
""")

docs = [
    ("doc-hello", "Welcome Note", "note", {"src":"seed"}),
    ("doc-flutter", "Flutter FFI Tips", "note", {"src":"seed"}),
    ("doc-email", "Email Workflow", "note", {"src":"seed"}),
]

chunks = [
    ("c1","doc-hello","note","XDesktopAgent is a local-first AI desktop agent with dataflow and FP principles.",{"lang":"en"}),
    ("c2","doc-flutter","note","Flutter desktop uses Dart FFI to call Go shared libraries for fast local processing.",{"lang":"en"}),
    ("c3","doc-email","note","The RAG pipeline retrieves local notes and emails and assembles a prompt for LLM.",{"lang":"en"}),
]

for d in docs:
    c.execute("INSERT OR REPLACE INTO kb_doc(id,title,kind,meta) VALUES (?,?,?,json(?))", (d[0], d[1], d[2], json.dumps(d[3])))

for cid, did, kind, text, meta in chunks:
    emb = bytes(bytearray(int((v+1)*127.5) for v in embed(text)))  # quantize [-1,1] -> [0,255] approx
    c.execute("INSERT OR REPLACE INTO kb_chunk(id,doc_id,kind,text,meta,embedding) VALUES (?,?,?,?,json(?),?)",
              (cid, did, kind, text, json.dumps(meta), emb))

conn.commit()
conn.close()

print(f"Initialized DB at {db_path}")
