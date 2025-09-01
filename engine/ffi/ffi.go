//go:build cgo

package main

/*
#cgo CFLAGS: -std=c11
#include <stdlib.h>
*/
import "C"

import (
	"encoding/json"
	"unsafe"
	"github.com/example/xdesktopagent/engine/repo"
	"github.com/example/xdesktopagent/engine/rag"
)

//export XDA_Init
func XDA_Init(cfgJSON *C.char) C.int {
	var cfg struct{ DBPath string `json:"db_path"` }
	if err := json.Unmarshal([]byte(C.GoString(cfgJSON)), &cfg); err != nil {
		return 1
	}
	if err := repo.Init(cfg.DBPath); err != nil {
		return 2
	}
	return 0
}

//export XDA_RAG
func XDA_RAG(reqJSON *C.char) *C.char {
	var req struct{ Question string `json:"question"` }
	_ = json.Unmarshal([]byte(C.GoString(reqJSON)), &req)
	ans := rag.Run(req.Question)
	b, _ := json.MarshalIndent(ans, "", "  ")
	return C.CString(string(b))
}

//export XDA_Free
func XDA_Free(ptr *C.char) {
	C.free(unsafe.Pointer(ptr))
}

func main() {}
