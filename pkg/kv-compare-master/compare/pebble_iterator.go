package compare

import "github.com/cockroachdb/pebble"

type PebbleIterator struct {
	*pebble.Iterator
}

func (p *PebbleIterator) Release() {
	p.Iterator.Close()
}
