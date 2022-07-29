package compare

import (
	"github.com/cockroachdb/pebble"
	"github.com/syndtr/goleveldb/leveldb/util"
	"sync"
)

type PebbleInstance struct {
	lock         sync.Mutex
	db           *pebble.DB
	currentBatch *pebble.Batch
}

func NewPebbleInstance(path string) (*PebbleInstance, error) {
	db, err := pebble.Open(path, &pebble.Options{
		BytesPerSync:                16 << 20,  // 16MB
		MemTableSize:                128 << 20, // 128MB
		MemTableStopWritesThreshold: 4,
		MaxConcurrentCompactions:    4,
	})
	if err != nil {
		return nil, err
	}
	return &PebbleInstance{
		db:           db,
		currentBatch: db.NewBatch(),
	}, nil
}

func (p *PebbleInstance) NewIterator(slice *util.Range) DBIterator {
	return &PebbleIterator{Iterator: p.db.NewIter(&pebble.IterOptions{
		LowerBound: slice.Start,
		UpperBound: slice.Limit,
	})}
}

func (p *PebbleInstance) Delete(key []byte) error {
	p.lock.Lock()
	defer p.lock.Unlock()

	if p.currentBatch.Count() > 10000 {
		err := p.writeBatch()
		if err != nil {
			return err
		}
	}
	return p.currentBatch.Delete(key, nil)
}

func (p *PebbleInstance) Add(key, val []byte) error {
	p.lock.Lock()
	defer p.lock.Unlock()

	if p.currentBatch.Count() > 10000 {
		err := p.writeBatch()
		if err != nil {
			return err
		}
	}

	return p.currentBatch.Set(key, val, nil)
}

func (p *PebbleInstance) Close() error {
	err := p.writeBatch()
	if err != nil {
		return err
	}

	return p.db.Close()
}

func (p *PebbleInstance) writeBatch() error {
	err := p.currentBatch.Commit(pebble.NoSync)
	if err != nil {
		return err
	}

	p.currentBatch.Reset()
	return nil
}

func (p *PebbleInstance) Flush() error {
	p.lock.Lock()
	defer p.lock.Unlock()

	return p.writeBatch()
}
