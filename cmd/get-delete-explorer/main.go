package main

import (
	"fmt"
	"github.com/harmony-one/elastic-rpc-infra/pkg/kv-compare-master/compare"
	"log"
	_ "net/http/pprof"
	"os"
	"strconv"
)

/// REQUIRED envs:
/// PD_HOST_PORT which defaults to 127:0.0.1:2379 if other please pass another env variable
/// SHARD_NUMBER which defaults to 0 if other please pass another env variable
/// OPERATION which defaults to get if other please pass another env variable
/// KEY which defaults to checkpoint_bitmap if other please pass another env variable

func main() {
	shardNum := EitherEnvOrDefaultInt("SHARD_NUMBER", 0)
	log.Println(fmt.Sprintf("Connecting with shard: %d", shardNum))

	tkivUrl := EitherEnvOrDefault("PD_HOST_PORT", "127:0.0.1:2379")
	log.Println(fmt.Sprintf("Connecting with tikv: %s", tkivUrl))

	prefixStr := []byte(fmt.Sprintf("explorer_tikv_%d/", shardNum))
	kvInstance, err := compare.NewTiKVInstance([]string{tkivUrl}, prefixStr)
	if err != nil {
		panic(err)
	}
	defer kvInstance.Close()
	op := EitherEnvOrDefault("OPERATION", "get")
	log.Println(fmt.Sprintf("Operation: %s", op))
	key := EitherEnvOrDefault("KEY", "checkpoint_bitmap")
	log.Println(fmt.Sprintf("Key: %s", key))

	if op == "get" {
		res, err := kvInstance.Get([]byte(key))
		log.Println(string(res), err)
		log.Println("done")
		return
	}
	if op == "delete" {
		log.Println(kvInstance.Delete([]byte(key)))
		log.Println(kvInstance.Flush())
		log.Println("done")
		return
	}

	log.Println("invalid operation", op)
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
