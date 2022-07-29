package tikv

type PrefixIterator struct {
	prefix    []byte
	prefixLen int

	it Iterator
}

func newPrefixIterator(prefix []byte, it Iterator) *PrefixIterator {
	return &PrefixIterator{prefix: prefix, prefixLen: len(prefix), it: it}
}

func (i *PrefixIterator) Next() bool {
	return i.it.Next()
}

func (i *PrefixIterator) Error() error {
	return i.it.Error()
}

func (i *PrefixIterator) Key() []byte {
	key := i.it.Key()
	if len(key) < i.prefixLen {
		return nil
	}

	return key[i.prefixLen:]
}

func (i *PrefixIterator) Value() []byte {
	return i.it.Value()
}

func (i *PrefixIterator) Release() {
	i.it.Release()
}
