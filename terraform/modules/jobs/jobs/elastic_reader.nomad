job "erpc-reader-s${shard}" {
  datacenters = ["dc1"]

  constraint {
    attribute = "$${node.class}"
    value     = "client"
  }

  group "erpc-reader-s${shard}" {
    scaling {
      min = ${min}
      max = 30
      enabled = true

      policy {
        evaluation_interval = "1m"
        cooldown = "5m"

        check "cpu_utilization" {
          source = "prometheus"
          query = "sum(sum_over_time(nomad_client_allocs_cpu_total_ticks{task='erpc-reader-${shard}'}[190s])*100/sum_over_time(nomad_client_allocs_cpu_allocated{task='erpc-reader-${shard}'}[190s]))/count(nomad_client_allocs_cpu_allocated{task='erpc-reader-${shard}'})"

          strategy "target-value" {
            target    = 80
            threshold = 0.2
          }
        }
      }
    }

    update {
      max_parallel = 1
      min_healthy_time = "10s"
      healthy_deadline = "1m"
    }

    network {
      port "http" {}
      port "http_auth" {}
      port "wss" {}
      port "wss_auth" {}
      port "metrics" {}
      port "pprof" {}

      port "dnssync" {}
      port "p2p" {}
    }

    restart {
      attempts = 3
      delay    = "10s"
      interval = "10m"
      mode     = "fail"
    }

    task "erpc-reader-s${shard}" {
      driver = "docker"

      shutdown_delay = "7s"
      kill_timeout = "120s"

      logs {
        max_files     = 3
        max_file_size = 5
      }

      config {
        image = "diego1q2w/harmony:amd"
        command = "harmony"
        args = ["--config", "/local/config.cfg"]
        ports = ["wss_auth", "http_auth", "http", "wss", "metrics", "pprof", "dnssync", "p2p"]
      }

      env {
        // used for init redis cache
        // If redis is empty, the hit rate will be too low and the synchronization block speed will be slow
        // set LOAD_PRE_FETCH to yes can significantly improve this.
        // run this the setting [TKIV] Debug = true
        // LOAD_PRE_FETCH = "yes"
        IS_CLUSTER_PUBLIC_ECHO = "${is_cluster_public}"
        random_number = "${random_number}"
      }

      artifact {
        source = "https://s3.us-west-1.amazonaws.com/pub.harmony.one/release/linux-x86_64/${binary_path}"
        destination = "local/harmony"
        mode = "file"
      }

      resources {
        cpu = 49000
        memory = 28300
        memory_max = 28500
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
  KeyDir = "/local/.hmy/blskeys"
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
  Zone = "${dns_zone}"

[General]
  DataDir = "/local"
  EnablePruneBeaconChain = false
  IsArchival = true
  IsBackup = false
  IsBeaconArchival = false
  IsOffline = true
  NoStaking = true
  NodeType = "explorer"
  ShardID = ${shard}
  RunElasticMode = true

[TiKV]
  Debug = false
  PDAddr = ${tkiv_addr}
  Role = "Reader"
  StateDBCacheSizeInMB = 1024
  StateDBCachePersistencePath = "/local/fastcache"
  StateDBRedisServerAddr = ["${redis_addr}"]
  StateDBRedisLRUTimeInDay = 35

[HTTP]
  AuthPort = {{ env "NOMAD_PORT_http_auth" }}
  Enabled = true
  IP = "0.0.0.0"
  Port = {{ env "NOMAD_PORT_http" }}
  RosettaEnabled = false

[Log]
  Console = true
  FileName = "1.stdharmony.0"
  Folder = "alloc/logs"
  RotateCount = 3
  RotateMaxAge = 1
  RotateSize = 30
  Verbosity = 3
  [Log.VerbosePrints]
    Config = true

[Network]
  BootNodes = ["${boot_nodes}"]
  NetworkType = "${network_type}"

[P2P]
  DiscConcurrency = 0
  IP = "0.0.0.0"
  KeyFile = "/local/.hmykey"
  MaxConnsPerIP = 10
  Port = {{ env "NOMAD_PORT_p2p" }}

[Pprof]
  Enabled = true
  Folder = "/local/profiles"
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
  BlacklistFile = "/local/blacklist.txt"
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
          name = "nolog-erpc-reader-metrics"
          tags = ["erpc_reader", "enodetype=reader", "shard=${shard}"]
          port = "metrics"
          meta {
            port = "$${NOMAD_PORT_metrics}"
            public_ip = "$${attr.unique.platform.aws.public-ipv4}"
            private_ip = "$${attr.unique.platform.aws.local-ipv4}"
          }
      }

      service {
          name = "erpc-reader-s${shard}-http"
          tags = ["erpc_reader", "urlprefix-${http_domain}/", "enodetype=reader", "shard=${shard}"]
          port = "http_auth"
          check {
              type     = "http"
              port     = "http_auth"
              path     = "/metrics"
              interval = "15s"
              timeout  = "5s"

              check_restart {
                limit = 1
                grace = "60s"
                ignore_warnings = false
              }
          }
          meta {
            port = "$${NOMAD_PORT_http_auth}"
            public_ip = "$${attr.unique.platform.aws.public-ipv4}"
            private_ip = "$${attr.unique.platform.aws.local-ipv4}"
          }
      }

      %{~ for id, domain in http_domains  ~}
          service {
            name = "nolog-erpc-reader-s${shard}-http-${id}"
            tags = ["erpc_reader", "urlprefix-${domain}/", "enodetype=reader", "shard=${shard}"]
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
        %{~ endfor ~}

      service {
          name = "nolog-erpc-reader-s${shard}-wss"
          tags = ["erpc_reader", "urlprefix-${wss_domain}/", "enodetype=reader", "shard=${shard}"]
          port = "wss_auth"

          check {
            type     = "http"
            port     = "http_auth"
            path     = "/metrics"
            interval = "15s"
            timeout  = "2s"
          }

          meta {
            port = "$${NOMAD_PORT_wss_auth}"
            public_ip = "$${attr.unique.platform.aws.public-ipv4}"
            private_ip = "$${attr.unique.platform.aws.local-ipv4}"
          }
      }

      %{~ for id, domain in wss_domains  ~}
        service {
          name = "nolog-erpc-reader-s${shard}-wss-${id}"
          tags = ["erpc_reader", "urlprefix-${domain}/", "enode_type=reader", "shard=${shard}"]
          port = "wss_auth"
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
      %{~ endfor ~}
    }
  }
}
