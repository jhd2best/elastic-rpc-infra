package compare

import (
	"bytes"
	"encoding/json"
	"github.com/syndtr/goleveldb/leveldb/util"
	"log"
	"sync"
)

var EmptyValueStub = []byte("HarmonyTiKVEmptyValueStub")

type Point struct {
	FromPoint []byte
	ToPoint   []byte
	FromEnd   bool
	ToEnd     bool
	Changed   uint64
}

type SavePoint struct {
	lock     sync.RWMutex
	snapshot *Point

	SafePoint   *Point
	From        []byte
	To          []byte
	ComparedNum uint64
}

type ChildCompare struct {
	parent *Compare

	workerId  int
	start     []byte
	end       []byte
	savePoint *SavePoint

	fromStart, toStart           []byte
	fromEnd, toEnd               bool
	fromCurrentKey, toCurrentKey []byte
	fromCurrentVal, toCurrentVal []byte
	changed, processed           uint64
	fromIterator, toIterator     DBIterator
}

func (c *ChildCompare) init() {
	c.fromStart = c.start
	c.toStart = c.start
	if c.savePoint.SafePoint != nil {
		if c.savePoint.SafePoint.FromPoint != nil {
			c.fromStart = c.savePoint.SafePoint.FromPoint
		}

		if c.savePoint.SafePoint.ToPoint != nil {
			c.toStart = c.savePoint.SafePoint.ToPoint
		}

		c.start = c.savePoint.From
		c.end = c.savePoint.To
	}

	c.savePoint.From = c.fromStart
	c.savePoint.To = c.end

	if c.savePoint.SafePoint != nil {
		c.fromEnd = c.savePoint.SafePoint.FromEnd
		c.toEnd = c.savePoint.SafePoint.ToEnd
		c.changed = c.savePoint.SafePoint.Changed
		c.processed = c.savePoint.ComparedNum
	}

	c.fromIterator = c.parent.from.NewIterator(&util.Range{Start: c.fromStart, Limit: c.end})
	c.toIterator = c.parent.to.NewIterator(&util.Range{Start: c.toStart, Limit: c.end})
}

func (c *ChildCompare) fromNext() {
	if !c.fromIterator.Next() {
		c.fromEnd = true
		c.fromCurrentKey = nil
		c.fromCurrentVal = nil
		return
	} else {
		c.processed++
	}
	c.fromCurrentKey = c.fromIterator.Key()
	c.fromCurrentVal = c.fromIterator.Value()

	if len(c.fromCurrentVal) == 0 {
		c.fromCurrentVal = EmptyValueStub
	}
}

func (c *ChildCompare) toNext() {
	if !c.toIterator.Next() {
		c.toEnd = true
		c.toCurrentKey = nil
		c.toCurrentVal = nil
		return
	} else {
		c.processed++
	}
	c.toCurrentKey = c.toIterator.Key()
	c.toCurrentVal = c.toIterator.Value()
}

func (c *ChildCompare) saveSafePoint() {
	c.savePoint.lock.Lock()
	defer c.savePoint.lock.Unlock()

	c.savePoint.ComparedNum = c.processed
	c.savePoint.snapshot = &Point{
		FromPoint: append([]byte{}, c.fromCurrentKey...),
		ToPoint:   append([]byte{}, c.toCurrentKey...),
		FromEnd:   c.fromEnd,
		ToEnd:     c.toEnd,
		Changed:   c.changed,
	}
}

func (c *ChildCompare) compare() error {
	defer func() {
		err := c.parent.to.Flush()
		if err != nil {
			panic(err)
		}

		c.saveSafePoint()
		c.savePoint.SafePoint = c.savePoint.snapshot
	}()

	for i := uint64(0); ; i++ {
		// safe point
		if i%10000 == 0 {
			c.saveSafePoint()
		}

		if c.fromEnd == false && c.fromCurrentKey == nil {
			c.fromNext()
		} else if c.toEnd == false && c.toCurrentKey == nil {
			c.toNext()
		} else if c.fromEnd && c.toEnd {
			// 结束
			return nil
		} else if c.fromEnd {
			// 删除 toc.
			c.changed++
			err := c.parent.to.Delete(append([]byte{}, c.toCurrentKey...))
			if err != nil {
				return err
			}
			c.toNext()
		} else if c.toEnd {
			// 新增
			c.changed++
			err := c.parent.to.Add(append([]byte{}, c.fromCurrentKey...), append([]byte{}, c.fromCurrentVal...))
			if err != nil {
				return err
			}
			c.fromNext()
		} else {
			switch bytes.Compare(c.fromCurrentKey, c.toCurrentKey) {
			case -1:
				// from < to, 新增
				c.changed++
				err := c.parent.to.Add(append([]byte{}, c.fromCurrentKey...), append([]byte{}, c.fromCurrentVal...))
				if err != nil {
					return err
				}
				c.fromNext()
			case 1:
				// from > to, 删除
				c.changed++
				err := c.parent.to.Delete(append([]byte{}, c.toCurrentKey...))
				if err != nil {
					return err
				}
				c.toNext()
			case 0:
				// from  == to, 比较内容是否相同，不同则覆盖
				if bytes.Compare(c.fromCurrentVal, c.toCurrentVal) != 0 {
					c.changed++
					err := c.parent.to.Add(append([]byte{}, c.fromCurrentKey...), append([]byte{}, c.fromCurrentVal...))
					if err != nil {
						return err
					}
				}
				c.fromNext()
				c.toNext()
			}
		}
	}
}

func (c *ChildCompare) SaveSafePointAndGet() ([]byte, error) {
	c.savePoint.lock.Lock()
	defer c.savePoint.lock.Unlock()

	c.savePoint.SafePoint = c.savePoint.snapshot
	return json.Marshal(c.savePoint)
}

func (c *ChildCompare) GetProcess() *SavePoint {
	return c.savePoint
}

func (c *ChildCompare) LoadSafePoint(b []byte) error {
	err := json.Unmarshal(b, c.savePoint)
	if err != nil {
		return err
	}
	point := c.savePoint
	if point.SafePoint != nil {
		log.Printf("worker-%02d: %x => %x, from point %x[end: %t], to point %x[end: %t]", c.workerId, point.From, point.To, point.SafePoint.FromPoint, point.SafePoint.FromEnd, point.SafePoint.ToPoint, point.SafePoint.ToEnd)
	} else {
		log.Printf("worker-%02d: %x => %x", c.workerId, point.From, point.To)
	}
	return nil
}
