package tikv

import (
	"bytes"
)

type PrefixBatchReplay struct {
	prefix    []byte
	prefixLen int
	w         KeyValueWriter
}

func newPrefixBatchReplay(prefix []byte, w KeyValueWriter) *PrefixBatchReplay {
	return &PrefixBatchReplay{prefix: prefix, prefixLen: len(prefix), w: w}
}

func (p *PrefixBatchReplay) Put(key []byte, value []byte) error {
	if bytes.HasPrefix(key, p.prefix) {
		return p.w.Put(key[p.prefixLen:], value)
	} else {
		return p.w.Put(key, value)
	}
}

func (p *PrefixBatchReplay) Delete(key []byte) error {
	if bytes.HasPrefix(key, p.prefix) {
		return p.w.Delete(key[p.prefixLen:])
	} else {
		return p.w.Delete(key)
	}
}
