package tikv

type NopRemoteBatch struct {
}

func newNopRemoteBatch(db *RemoteDatabase) *NopRemoteBatch {
	return &NopRemoteBatch{}
}

func (b *NopRemoteBatch) Put(key []byte, value []byte) error {
	return nil
}

func (b *NopRemoteBatch) Delete(key []byte) error {
	return nil
}

func (b *NopRemoteBatch) ValueSize() int {
	return 0
}

func (b *NopRemoteBatch) Write() error {
	return nil
}

func (b *NopRemoteBatch) Reset() {
}

func (b *NopRemoteBatch) Replay(w KeyValueWriter) error {
	return nil
}
