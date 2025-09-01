package repo

import (
	"database/sql"
	"log"
	_ "modernc.org/sqlite"
)

var db *sql.DB

func Init(path string) error {
	var err error
	db, err = sql.Open("sqlite", path+"?_pragma=journal_mode(WAL)&_pragma=busy_timeout(5000)")
	if err != nil {
		return err
	}
	if err = db.Ping(); err != nil {
		return err
	}
	return nil
}

type Chunk struct {
	ID    string
	Text  string
	DocID string
	Kind  string
	Meta  string
	Emb   []byte
}

func AllChunks() ([]Chunk, error) {
	rows, err := db.Query("SELECT id, text, doc_id, kind, json(meta), embedding FROM kb_chunk")
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Chunk
	for rows.Next() {
		var c Chunk
		if err := rows.Scan(&c.ID, &c.Text, &c.DocID, &c.Kind, &c.Meta, &c.Emb); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func Must[T any](v T, err error) T {
	if err != nil {
		log.Panic(err)
	}
	return v
}
