package compare

import (
	"encoding/json"
	"github.com/syndtr/goleveldb/leveldb/util"
	"log"
	"sync"
	"time"
)

type DBIterator interface {
	Next() bool
	Key() []byte
	Value() []byte
	Release()
}

type DBInstance interface {
	NewIterator(slice *util.Range) DBIterator
	Delete(key []byte) error
	Add(key, val []byte) error
	Close() error
	Flush() error
}

type Compare struct {
	from     DBInstance
	to       DBInstance
	parallel int
	children []*ChildCompare

	statistics struct {
		totalStatistics     []uint64
		totalStatisticsTime []time.Time
		startTotal          uint64
		startTime           time.Time
	}
}

func NewCompare(from DBInstance, to DBInstance, parallel int) *Compare {
	return &Compare{from: from, to: to, parallel: parallel, children: make([]*ChildCompare, 0)}
}

func (c *Compare) Start() {
	wg := sync.WaitGroup{}
	if len(c.children) == 0 {
		for i := 0; i < c.parallel; i++ {
			workerId := i
			start := []byte{byte(int(float64(i) / float64(c.parallel) * 255))}
			end := []byte{byte(int(float64(i+1) / float64(c.parallel) * 255))}
			if i == c.parallel-1 {
				end = nil
			} else if i == 0 {
				start = nil
			}

			child := &ChildCompare{
				parent:    c,
				workerId:  workerId,
				start:     start,
				end:       end,
				savePoint: &SavePoint{},
			}
			child.init()
			c.children = append(c.children, child)
			wg.Add(1)
		}
	} else {
		wg.Add(len(c.children))
	}

	for _, child := range c.children {
		child := child
		go func() {
			if err := child.compare(); err != nil {
				panic(err)
			}
			wg.Done()
		}()
	}
	wg.Wait()
}

func (c *Compare) SaveSafePointAndGet() ([]byte, error) {
	sps := make([][]byte, 0)
	for _, child := range c.children {
		point, err := child.SaveSafePointAndGet()
		if err != nil {
			return nil, err
		}

		sps = append(sps, point)
	}

	err := c.to.Flush()
	if err != nil {
		panic(err)
	}

	return json.Marshal(sps)
}

func (c *Compare) LoadSafePoint(b []byte) error {
	var sps [][]byte
	err := json.Unmarshal(b, &sps)
	if err != nil {
		return err
	}

	for i, sp := range sps {
		child := &ChildCompare{
			parent:    c,
			workerId:  i,
			savePoint: &SavePoint{},
		}
		err := child.LoadSafePoint(sp)
		if err != nil {
			return err
		}
		child.init()
		c.children = append(c.children, child)
	}

	return nil
}

func (c *Compare) PrintProcess() {
	log.Printf("============= PrintProcess =============")
	total := uint64(0)
	for i, child := range c.children {
		process := child.GetProcess()

		process.lock.RLock()
		if process.SafePoint != nil {
			log.Printf("worker-%02d: procesed: %d, changed: %d, current: %x, stoped: %t", i, process.ComparedNum, process.SafePoint.Changed, process.SafePoint.FromPoint, process.SafePoint.FromEnd && process.SafePoint.ToEnd)
		} else {
			log.Printf("worker-%02d: procesed: %d, no safe point", i, process.ComparedNum)
		}
		total += process.ComparedNum
		process.lock.RUnlock()
	}

	if len(c.statistics.totalStatistics) > 3 {
		log.Printf(
			"total: %d(+%d), avg: %.02f/s, avg(%v): %.02f/s",
			total,
			total-c.statistics.totalStatistics[len(c.statistics.totalStatistics)-1],
			float64(total-c.statistics.startTotal)/time.Now().Sub(c.statistics.startTime).Seconds(),
			time.Now().Sub(c.statistics.totalStatisticsTime[0]).Truncate(time.Second),
			float64(total-c.statistics.totalStatistics[0])/time.Now().Sub(c.statistics.totalStatisticsTime[0]).Seconds(),
		)
	} else {
		log.Printf("total: %d", total)
		c.statistics.startTotal = total
		c.statistics.startTime = time.Now()
	}

	c.statistics.totalStatistics = append(c.statistics.totalStatistics, total)
	c.statistics.totalStatisticsTime = append(c.statistics.totalStatisticsTime, time.Now())

deleteMore:
	if time.Now().Sub(c.statistics.totalStatisticsTime[0]) > 5*time.Minute {
		c.statistics.totalStatisticsTime = c.statistics.totalStatisticsTime[1:]
		c.statistics.totalStatistics = c.statistics.totalStatistics[1:]
		goto deleteMore
	}
}
