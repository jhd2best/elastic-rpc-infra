package compare

import (
	"github.com/syndtr/goleveldb/leveldb/util"
	"hash/crc32"
	"sync"
)

type MultiDBInstance struct {
	dbs     []DBInstance
	dbCount uint32
}

func NewMultiDBInstance(dbs []DBInstance) *MultiDBInstance {
	return &MultiDBInstance{dbs: dbs, dbCount: uint32(len(dbs))}
}

func (m *MultiDBInstance) mapDB(key []byte) DBInstance {
	hash := crc32.ChecksumIEEE(key)
	return m.dbs[hash%m.dbCount]
}

func (m *MultiDBInstance) NewIterator(slice *util.Range) DBIterator {
	return NewMultiDBIterator(m, slice)
}

func (m *MultiDBInstance) Delete(key []byte) error {
	return m.mapDB(key).Delete(key)
}

func (m *MultiDBInstance) Add(key, val []byte) error {
	return m.mapDB(key).Add(key, val)
}

func (m *MultiDBInstance) Close() error {
	for _, db := range m.dbs {
		err := db.Close()
		if err != nil {
			return err
		}
	}

	return nil
}

func (m *MultiDBInstance) Flush() error {
	wg := sync.WaitGroup{}

	var flushErr error
	for _, db := range m.dbs {
		wg.Add(1)
		go func(db DBInstance) {
			defer wg.Done()

			err := db.Flush()
			if err != nil {
				flushErr = err
			}
		}(db)
	}

	wg.Wait()
	return flushErr
}
