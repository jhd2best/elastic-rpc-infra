package compare

import (
	"github.com/syndtr/goleveldb/leveldb"
	"github.com/syndtr/goleveldb/leveldb/filter"
	"github.com/syndtr/goleveldb/leveldb/opt"
	"github.com/syndtr/goleveldb/leveldb/util"
	"sync"
)

type LevelDBInstance struct {
	lock         sync.Mutex
	db           *leveldb.DB
	currentBatch *leveldb.Batch
}

func NewLevelDBInstance(path string) (*LevelDBInstance, error) {
	db, err := leveldb.OpenFile(path, &opt.Options{
		OpenFilesCacheCapacity: 128,
		WriteBuffer:            8 << 20,  //8MB, max memory occupyv = 8*2*diskCount*diskShards
		BlockCacheCapacity:     16 << 20, //16MB
		Filter:                 filter.NewBloomFilter(8),
	})
	if err != nil {
		return nil, err
	}
	return &LevelDBInstance{db: db, currentBatch: &leveldb.Batch{}}, nil
}

func (l *LevelDBInstance) NewIterator(slice *util.Range) DBIterator {
	return l.db.NewIterator(slice, nil)
}

func (l *LevelDBInstance) Delete(key []byte) error {
	l.lock.Lock()
	defer l.lock.Unlock()

	l.currentBatch.Delete(key)
	if len(l.currentBatch.Dump()) > 3<<20 { // 3MB
		return l.writeBatch()
	}
	return nil
}

func (l *LevelDBInstance) Get(key []byte) ([]byte, error) {
	l.lock.Lock()
	defer l.lock.Unlock()

	return l.db.Get(key, nil)
}

func (l *LevelDBInstance) Add(key, val []byte) error {
	l.lock.Lock()
	defer l.lock.Unlock()

	l.currentBatch.Put(key, val)
	if len(l.currentBatch.Dump()) > 3<<20 { // 3MB
		return l.writeBatch()
	}
	return nil
}

func (l *LevelDBInstance) Flush() error {
	l.lock.Lock()
	defer l.lock.Unlock()

	return l.writeBatch()
}

func (l *LevelDBInstance) writeBatch() error {
	err := l.db.Write(l.currentBatch, nil)
	if err != nil {
		return err
	}

	l.currentBatch.Reset()
	return nil
}

func (l *LevelDBInstance) Close() error {
	err := l.writeBatch()
	if err != nil {
		return err
	}

	return l.db.Close()
}
