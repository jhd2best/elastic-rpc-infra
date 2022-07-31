package main

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"github.com/harmony-one/elastic-rpc-infra/pkg/kv-compare-master/compare"
	"github.com/syndtr/goleveldb/leveldb"
	"io/ioutil"
	"log"
	"net/http"
	_ "net/http/pprof"
	"os"
	"path/filepath"
	"strconv"
	"sync"
	"time"
)

/// REQUIRED envs:
/// SHARD_DATA_FOLDER which defaults to /data/harmony_sharddb_0 if other please pass another env variable
/// PD_HOST_PORT which defaults to 127:0.0.1:2379 if other please pass another env variable
/// SHARD_NUMBER which defaults to 0 if other please pass another env variable

const (
	safePointKey = "kv-compare-safe-point"
)

var shardIdxKey = []byte("__DB_SHARED_INDEX__")

func buildMultiDB(savePath string, diskCount int, diskShards int) *compare.MultiDBInstance {
	var err error
	var dbs = make([]compare.DBInstance, diskCount*diskShards)

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
	for i := 0; i < diskCount; i++ {
		for j := 0; j < diskShards; j++ {
			shardPath := filepath.Join(savePath, fmt.Sprintf("disk%02d", i), fmt.Sprintf("block%02d", j))
			dbIndex := i*diskShards + j
			wg.Add(1)
			go func() {
				defer wg.Done()

				ldb, err := compare.NewLevelDBInstance(shardPath)
				if err != nil {
					panic(err)
				}

				indexByte := make([]byte, 8)
				binary.BigEndian.PutUint64(indexByte, uint64(dbIndex))
				inDBIndex, getErr := ldb.Get(shardIdxKey)
				if getErr != nil {
					if getErr == leveldb.ErrNotFound {
						putErr := ldb.Add(shardIdxKey, indexByte)
						if putErr != nil {
							err = putErr
							return
						}
					} else {
						err = getErr
						return
					}
				} else if bytes.Compare(indexByte, inDBIndex) != 0 {
					err = fmt.Errorf("db shard index error, need %v, got %v", indexByte, inDBIndex)
					return
				}

				dbs[dbIndex] = ldb
			}()
		}
	}

	wg.Wait()

	return compare.NewMultiDBInstance(dbs)
}

func main() {
	go func() {
		http.ListenAndServe(":8649", nil)
	}()

	//instance, err := compare.NewLevelDBInstance("/data/harmony_db_0")
	//if err != nil {
	//	panic(err)
	//}
	//defer instance.Close()

	dir := EitherEnvOrDefault("SHARD_DATA_FOLDER", "/data/harmony_sharddb_0")
	log.Println(fmt.Sprintf("Syncing with dir: %s", dir))

	shardNum := EitherEnvOrDefaultInt("SHARD_NUMBER", 0)
	log.Println(fmt.Sprintf("Syncing with shard: %d", shardNum))

	tkivUrl := EitherEnvOrDefault("PD_HOST_PORT", "127:0.0.1:2379")
	log.Println(fmt.Sprintf("Syncing with tikv: %s", dir))

	instance := buildMultiDB(dir, 8, 4)
	defer instance.Close()

	prefixStr := []byte(fmt.Sprintf("harmony_tikv_%d/", shardNum))
	kvInstance, err := compare.NewTiKVInstance([]string{tkivUrl}, prefixStr)
	if err != nil {
		panic(err)
	}
	defer kvInstance.Close()

	kvCompare := compare.NewCompare(instance, kvInstance, 32)

	// load point
	file, err := ioutil.ReadFile(safePointKey)
	if err == nil {
		err = kvCompare.LoadSafePoint(file)
		if err != nil {
			panic(err)
		}
	}

	savePoint := func() {
		point, err := kvCompare.SaveSafePointAndGet()
		if err != nil {
			panic(err)
		}

		kvCompare.PrintProcess()

		err = ioutil.WriteFile(safePointKey, point, 0644)
		if err != nil {
			panic(err)
		}
	}

	// save point
	go func() {
		for tick := range time.Tick(time.Second * 10) {
			if time.Now().Sub(tick) < 5*time.Second {
				savePoint()
			}
		}
	}()
	kvCompare.Start()
	savePoint()
}

func EitherEnvOrDefault(env string, def string) string {
	if val, ok := os.LookupEnv(env); ok {
		return val
	} else {
		return def
	}
}

func EitherEnvOrDefaultInt(env string, def int) int {
	res := EitherEnvOrDefault(env, fmt.Sprintf("%d", def))
	resI, err := strconv.Atoi(res)
	if err != nil {
		panic(fmt.Sprintf("%s env variable should contain a number", env))
	}

	return resI
}
