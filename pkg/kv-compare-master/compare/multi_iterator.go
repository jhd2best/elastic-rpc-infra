package compare

import (
	"bytes"
	"github.com/syndtr/goleveldb/leveldb/util"
)

type MultiDBIteratorStete int

const (
	_ MultiDBIteratorStete = iota
	IterCanNext
	IterUsed
	IterEnd
)

type MultiDBIteratorSort struct {
	index int
	db    DBIterator
	key   []byte
}

type MultiDBIterator struct {
	instance *MultiDBInstance
	slice    *util.Range

	lastIter               int
	iters                  []DBIterator
	iterState              []MultiDBIteratorStete
	currentKey, currentVal []byte
	iterSortList           []MultiDBIteratorSort
}

func NewMultiDBIterator(instance *MultiDBInstance, slice *util.Range) *MultiDBIterator {
	m := &MultiDBIterator{instance: instance, slice: slice}

	m.init()
	return m
}

func (m *MultiDBIterator) init() {
	m.iters = make([]DBIterator, m.instance.dbCount)
	m.iterState = make([]MultiDBIteratorStete, m.instance.dbCount)
	m.iterSortList = make([]MultiDBIteratorSort, 0, m.instance.dbCount)
	m.lastIter = -1

	for i, db := range m.instance.dbs {
		iter := db.NewIterator(m.slice)
		m.iters[i] = iter

		if iter.Next() {
			m.iterState[i] = IterCanNext
			m.addAndSort(i, iter)
		} else {
			m.iterState[i] = IterEnd
		}
	}
}

func (m *MultiDBIterator) addAndSort(index int, iter DBIterator) {
	sortKey := iter.Key()
	sortItem := MultiDBIteratorSort{
		index: index,
		db:    iter,
		key:   sortKey,
	}
	// todo opti? binary search
	for i, item := range m.iterSortList {
		switch bytes.Compare(item.key, sortKey) {
		case -1:
			continue
		case 0, 1:
			m.iterSortList = append(m.iterSortList, MultiDBIteratorSort{})
			copy(m.iterSortList[i+1:], m.iterSortList[i:])
			m.iterSortList[i] = sortItem
			return
		}
	}

	m.iterSortList = append(m.iterSortList, sortItem)
}

func (m *MultiDBIterator) Next() bool {
	if m.lastIter >= 0 {
		if m.iterState[m.lastIter] == IterUsed {
			lastIter := m.iters[m.lastIter]
			if lastIter.Next() {
				m.iterState[m.lastIter] = IterCanNext
				m.addAndSort(m.lastIter, lastIter)
			} else {
				m.iterState[m.lastIter] = IterEnd
			}
			m.lastIter = -1
		}
	}

	if len(m.iterSortList) == 0 {
		return false
	}

	item := m.iterSortList[0]
	m.iterSortList = m.iterSortList[1:]
	m.lastIter = item.index
	m.iterState[item.index] = IterUsed

	m.currentKey = item.db.Key()
	m.currentVal = item.db.Value()
	return true
}

func (m *MultiDBIterator) Key() []byte {
	return m.currentKey
}

func (m *MultiDBIterator) Value() []byte {
	return m.currentVal
}

func (m *MultiDBIterator) Release() {
	for _, iter := range m.iters {
		iter.Release()
	}

	m.iters = m.iters[:0]
	m.currentVal = nil
	m.currentKey = nil
}
