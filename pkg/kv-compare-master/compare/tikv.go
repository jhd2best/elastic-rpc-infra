package compare

import (
	"github.com/harmony-one/elastic-rpc-infra/pkg/kv-compare-master/compare/tikv"
	"github.com/syndtr/goleveldb/leveldb/util"
	"runtime"
	"sync"
	"sync/atomic"
	"time"
)

const (
	maxTiKVBatchSize = 32 * 1024 * 1024
)

type TiKVInstance struct {
	lock          sync.Mutex
	currentBatch  tikv.Batch
	db            *tikv.PrefixDatabase
	asyncWaitSize int64
}

func NewTiKVInstance(pdAddr []string, prefix []byte) (*TiKVInstance, error) {
	database, err := tikv.NewRemoteDatabase(pdAddr)
	if err != nil {
		return nil, err
	}

	ins := &TiKVInstance{
		db: tikv.NewPrefixDatabase(prefix, database),
	}
	ins.currentBatch = ins.db.NewBatch()

	return ins, nil
}

func (t *TiKVInstance) NewIterator(slice *util.Range) DBIterator {
	return t.db.NewIterator(slice.Start, slice.Limit)
}

func (t *TiKVInstance) Delete(key []byte) error {
	t.lock.Lock()
	defer t.lock.Unlock()

	t.currentBatch.Delete(key)
	if t.currentBatch.ValueSize() > maxTiKVBatchSize {
		return t.writeBatch(false)
	}
	return nil
}

func (t *TiKVInstance) Add(key, val []byte) error {
	t.lock.Lock()
	defer t.lock.Unlock()

	err := t.currentBatch.Put(key, val)
	if err != nil {
		return err
	}

	if t.currentBatch.ValueSize() > maxTiKVBatchSize {
		return t.writeBatch(false)
	}
	return nil
}

func (t *TiKVInstance) Get(key []byte) ([]byte, error) {
	t.lock.Lock()
	defer t.lock.Unlock()

	return t.db.Get(key)
}

func (t *TiKVInstance) Flush() error {
	t.lock.Lock()
	defer t.lock.Unlock()

	return t.writeBatch(true)
}

func (t *TiKVInstance) writeBatch(sync bool) error {
	for atomic.LoadInt64(&t.asyncWaitSize) >= 3 {
		time.Sleep(16 * time.Millisecond)
		runtime.Gosched()
	}

	if sync {
		err := t.currentBatch.Write()
		if err != nil {
			return err
		}

		t.currentBatch.Reset()

		for atomic.LoadInt64(&t.asyncWaitSize) != 0 {
			time.Sleep(16 * time.Millisecond)
			runtime.Gosched()
		}
	} else {
		batch := t.currentBatch
		t.currentBatch = t.db.NewBatch()

		atomic.AddInt64(&t.asyncWaitSize, 1)
		go t.asyncWrite(batch)
	}

	return nil
}

func (t *TiKVInstance) asyncWrite(batch tikv.Batch) {
	defer atomic.AddInt64(&t.asyncWaitSize, -1)

	err := batch.Write()
	if err != nil {
		panic(err)
	}
}

func (t *TiKVInstance) Close() error {
	err := t.Flush()
	if err != nil {
		return err
	}

	return t.db.Close()
}
