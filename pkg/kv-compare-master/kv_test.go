package kv_compare_master

import (
	"bytes"
	"crypto/md5"
	"fmt"
	"github.com/harmony-one/elastic-rpc-infra/pkg/kv-compare-master/compare"
	"github.com/syndtr/goleveldb/leveldb/util"
	"log"
	"math/rand"
	"os"
	"path/filepath"
	"strconv"
	"sync"
	"testing"
	"time"
)

func init() {
	rand.Seed(time.Now().Unix())
}

func makeLevelTestDB() compare.DBInstance {
	temp, err := os.MkdirTemp("", "kvt_ldb_")
	if err != nil {
		panic(err)
	}

	instance, err := compare.NewLevelDBInstance(temp)
	if err != nil {
		panic(err)
	}

	return instance
}

func makeTiKVTestDB() compare.DBInstance {
	prefixStr := []byte("kvt_test_" + strconv.Itoa(rand.Int()))
	kvInstance, err := compare.NewTiKVInstance([]string{"192.168.122.155:2379"}, prefixStr)
	if err != nil {
		panic(err)
	}

	return kvInstance
}

func makeMultiLevelTestDB() compare.DBInstance {
	var err error
	var dbs = make([]compare.DBInstance, 4*8)

	temp, err := os.MkdirTemp("", "kvt_lmdb_")
	if err != nil {
		panic(err)
	}

	// clean when error
	defer func() {
		if err != nil {
			for _, db := range dbs {
				if db != nil {
					_ = db.Close()
				}
			}
		}
	}()

	// async open
	wg := sync.WaitGroup{}
	for i := 0; i < 8; i++ {
		for j := 0; j < 4; j++ {
			shardPath := filepath.Join(temp, fmt.Sprintf("disk%02d", i), fmt.Sprintf("block%02d", j))
			dbIndex := i*4 + j
			wg.Add(1)
			go func() {
				defer wg.Done()

				ldb, err := compare.NewLevelDBInstance(shardPath)
				if err != nil {
					panic(err)
				}

				dbs[dbIndex] = ldb
			}()
		}
	}

	wg.Wait()

	return compare.NewMultiDBInstance(dbs)
}

func writeRandomData(db compare.DBInstance) {
	for i := 0; i < 1000000; i++ {
		var byt = make([]byte, 1024)

		rand.Read(byt)
		sum := md5.Sum(byt)

		err := db.Add(sum[:], byt)
		if err != nil {
			panic(err)
		}

		if i%100000 == 0 {
			log.Println("writeRandomData", i)
		}
	}

	err := db.Flush()
	if err != nil {
		panic(err)
	}
}

func cleanData(db compare.DBInstance) {
	iterator := db.NewIterator(&util.Range{})
	defer iterator.Release()

	for iterator.Next() {
		err := db.Delete(iterator.Key())
		if err != nil {
			panic(err)
		}
	}

	err := db.Flush()
	if err != nil {
		panic(err)
	}
}

func checkData(db compare.DBInstance) {
	//start := rand.Intn(205)
	//end := start + 50
	//
	//iterator := db.NewIterator(&util.Range{Start: []byte{byte(start)}, Limit: []byte{byte(end)}})
	//defer iterator.Release()

	iterator := db.NewIterator(&util.Range{})
	defer iterator.Release()

	count := 0
	for iterator.Next() {
		count++
		sum := md5.Sum(iterator.Value())

		if bytes.Compare(sum[:], iterator.Key()) != 0 {
			log.Panicf("data error: key: %v, sum: %v", iterator.Key(), sum)
		}
	}

	log.Printf("check %d data: ok", count)
}

func TestCleanData(t *testing.T) {
	kvInstance, err := compare.NewTiKVInstance([]string{"192.168.122.155:2379"}, nil)
	if err != nil {
		panic(err)
	}

	cleanData(kvInstance)
	kvInstance.Close()
}

func TestA(t *testing.T) {
	from := makeMultiLevelTestDB()
	to := makeTiKVTestDB()
	defer func() {
		from.Close()
		to.Close()
	}()

	writeRandomData(from)
	checkData(from)

	log.Printf("compare data")
	kvCompare := compare.NewCompare(from, to, 4)
	kvCompare.Start()
	kvCompare.PrintProcess()

	checkData(to)

	log.Printf("compare data round2")
	kvCompare = compare.NewCompare(from, to, 8)
	kvCompare.Start()
	kvCompare.PrintProcess()

	checkData(to)
}
