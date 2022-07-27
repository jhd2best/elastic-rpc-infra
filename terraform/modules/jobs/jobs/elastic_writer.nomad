job "erpc-writer-${shard}" {
  datacenters = ["dc1"]
  type = "system"

  group "erpc-writer-${shard}" {
    update {
      max_parallel = 2
      min_healthy_time = "30s"
      healthy_deadline = "2m"
    }

    network {
      port "http" {}
      port "http_auth" {}
      port "wss" {}
      port "wss_auth" {}
      port "metrics" {}
      port "pprof" {}

      port "dnssync" { static = ${dns_port} }
      port "p2p" { static = ${p2p_port} }
      port "explorer" { static = ${explorer_init_port} }
    }


    task "erpc-writer-${shard}" {
      driver = "exec"

      config {
        command = "harmony"
        args = ["--config", "local/config.cfg"]
      }

      env {
        IS_CLUSTER_PUBLIC_ECHO = "${is_cluster_public}"
        random_number = "${random_number}"
      }

      artifact {
        source = "https://s3.us-west-1.amazonaws.com/pub.harmony.one/release/linux-x86_64/${binary_path}"
        destination = "local/harmony"
        mode = "file"
      }

      resources {
        cpu = 3500
        memory = 1700
        memory_max = 2200
      }

      template {
        change_mode = "noop"
        destination = "local/config.cfg"

        data = <<EOH
Version = "2.5.1"

[BLSKeys]
  KMSConfigFile = ""
  KMSConfigSrcType = "shared"
  KMSEnabled = false
  KeyDir = "local/.hmy/blskeys"
  KeyFiles = []
  MaxKeys = 10
  PassEnabled = true
  PassFile = ""
  PassSrcType = "auto"
  SavePassphrase = false

[DNSSync]
  Client = true
  LegacySyncing = false
  Port = {{ env "NOMAD_PORT_dnssync" }}
  Server = true
  ServerPort = {{ env "NOMAD_PORT_dnssync" }}
  Zone = "t.hmny.io"

[General]
  DataDir = "local"
  EnablePruneBeaconChain = false
  IsArchival = true
  IsBackup = false
  IsBeaconArchival = false
  IsOffline = false
  NoStaking = true
  NodeType = "explorer"
  ShardID = ${shard}
  RunElasticMode = true

[TiKV]
  Debug = false
  PDAddr = ${tkiv_addr}
  Role = "Writer"
  StateDBCacheSizeInMB = 1024
  StateDBCachePersistencePath = "local/fastcache"
  StateDBRedisServerAddr = ["${redis_addr}"]
  StateDBRedisLRUTimeInDay = 201

[HTTP]
  AuthPort = {{ env "NOMAD_PORT_http_auth" }}
  Enabled = true
  IP = "0.0.0.0"
  Port = {{ env "NOMAD_PORT_http" }}
  RosettaEnabled = false

[Log]
  FileName = "1.stdharmony.0"
  Folder = "alloc/logs"
  RotateCount = 0
  RotateMaxAge = 0
  RotateSize = 100
  Verbosity = 3
  [Log.VerbosePrints]
    Config = true

[Network]
  BootNodes = ["${boot_nodes}"]
  NetworkType = "${network_type}"

[P2P]
  DiscConcurrency = 0
  IP = "0.0.0.0"
  KeyFile = "local/.hmykey"
  MaxConnsPerIP = 10
  Port = {{ env "NOMAD_PORT_p2p" }}

[Pprof]
  Enabled = true
  Folder = "local/profiles"
  ListenAddr = "0.0.0.0:{{ env "NOMAD_PORT_pprof" }}"
  ProfileDebugValues = [0]
  ProfileIntervals = [600]
  ProfileNames = []

[RPCOpt]
  DebugEnabled = false
  EthRPCsEnabled = true
  StakingRPCsEnabled = true
  LegacyRPCsEnabled = true
  RateLimterEnabled = false
  RequestsPerSecond = 1000

[ShardData]
  CacheSize = 0
  CacheTime = 0
  DiskCount = 0
  EnableShardData = false
  ShardCount = 0

[Sync]
  Concurrency = 6
  DiscBatch = 8
  DiscHardLowCap = 6
  DiscHighCap = 128
  DiscSoftLowCap = 8
  Downloader = false
  Enabled = false
  InitStreams = 8
  MinPeers = 6

[TxPool]
  AccountSlots = 16
  BlacklistFile = "local/blacklist.txt"
  RosettaFixFile = ""

[WS]
  AuthPort = {{ env "NOMAD_PORT_wss_auth" }}
  Enabled = true
  IP = "0.0.0.0"
  Port = {{ env "NOMAD_PORT_wss" }}

[Prometheus]
  Enabled = true
  Port = {{ env "NOMAD_PORT_metrics" }}
  EnablePush = false
  IP = "0.0.0.0"
EOH
      }

      service {
          name = "nolog-erpc-writer-metrics"
          tags = ["erpc_writer", "enodetype=writer", "shard=${shard}"]
          port = "metrics"

          meta {
            port = "$${NOMAD_PORT_metrics}"
            public_ip = "$${attr.unique.platform.aws.public-ipv4}"
            private_ip = "$${attr.unique.platform.aws.local-ipv4}"
          }
      }

      service {
          name = "erpc-writer-s${shard}-http"
          tags = ["erpc_writer", "urlprefix-/s${shard}/writer", "enodetype=writer", "shard=${shard}"]
          port = "http_auth"
          check {
              type     = "http"
              port     = "http_auth"
              path     = "/metrics"
              interval = "15s"
              timeout  = "2s"
          }
          meta {
            port = "$${NOMAD_PORT_http_auth}"
            public_ip = "$${attr.unique.platform.aws.public-ipv4}"
            private_ip = "$${attr.unique.platform.aws.local-ipv4}"
          }
      }

    }
  }
}
