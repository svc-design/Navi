package rag

import (
	"github.com/example/navi/engine/repo"
	"math"
)

func decodeEmb(b []byte) []float64 {
	// inverse of scripts/init_db_sqlite.py quantization
	v := make([]float64, len(b))
	for i, by := range b {
		v[i] = (float64(by) / 127.5) - 1.0
	}
	return v
}

func embedQuery(q string) []float64 {
	// mirror python hasher (not identical but ok for demo)
	dim := 64
	out := make([]float64, dim)
	for _, tok := range split(q) {
		h := int(hash(tok)) % dim
		out[h] += 1
	}
	n := 0.0
	for _, x := range out {
		n += x * x
	}
	n = math.Sqrt(n)
	if n == 0 {
		n = 1
	}
	for i := range out {
		out[i] /= n
	}
	return out
}

func split(s string) []string {
	cur := ""
	res := []string{}
	for _, r := range []rune(s) {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') {
			cur += string(r)
		} else {
			if cur != "" {
				res = append(res, cur)
				cur = ""
			}
		}
	}
	if cur != "" {
		res = append(res, cur)
	}
	return res
}

func hash(s string) uint64 {
	var h uint64 = 1469598103934665603
	const FNV64 = 1099511628211
	for i := 0; i < len(s); i++ {
		h ^= uint64(s[i])
		h *= FNV64
	}
	return h
}

func cosine(a, b []float64) float64 {
	if len(a) != len(b) {
		return 0
	}
	dot := 0.0
	na := 0.0
	nb := 0.0
	for i := range a {
		dot += a[i] * b[i]
		na += a[i] * a[i]
		nb += b[i] * b[i]
	}
	if na == 0 || nb == 0 {
		return 0
	}
	return dot / (math.Sqrt(na) * math.Sqrt(nb))
}

type Answer struct {
	Question string    `json:"question"`
	Snippets []Snippet `json:"snippets"`
	Text     string    `json:"text"`
}

type Snippet struct {
	ID    string  `json:"id"`
	Score float64 `json:"score"`
	Text  string  `json:"text"`
}

func Run(question string) Answer {
	qEmb := embedQuery(question)
	chunks, _ := repo.AllChunks()
	// score
	type pair struct {
		s   float64
		idx int
	}
	ps := make([]pair, 0, len(chunks))
	for i, c := range chunks {
		ps = append(ps, pair{cosine(qEmb, decodeEmb(c.Emb)), i})
	}
	// top-k (k=3)
	k := 3
	for i := 0; i < len(ps); i++ {
		for j := i + 1; j < len(ps); j++ {
			if ps[j].s > ps[i].s {
				ps[i], ps[j] = ps[j], ps[i]
			}
		}
	}
	if len(ps) > k {
		ps = ps[:k]
	}
	snips := []Snippet{}
	ctx := ""
	for _, p := range ps {
		c := chunks[p.idx]
		snips = append(snips, Snippet{ID: c.ID, Score: p.s, Text: c.Text})
		ctx += "- " + c.Text + "\n"
	}
	answer := "Based on local notes, here is a brief:\n" + ctx
	return Answer{Question: question, Snippets: snips, Text: answer}
}
