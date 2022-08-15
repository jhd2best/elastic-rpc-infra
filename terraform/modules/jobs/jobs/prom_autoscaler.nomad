job "prometheus-autoscaler" {
  datacenters = ["dc1"]
  type        = "service"

  constraint {
    attribute = "$${node.class}"
    value     = "client"
  }

  group "prometheus-autoscaler" {
    count = 1

    ephemeral_disk {
      size = 300
    }

    network {
      port "http" { static = 9090 }
      port "autoscaler" {}
    }


    task "autoscaler" {
      driver = "exec"

      config {
        command = "nomad-autoscaler"

        args = [
          "agent",
          "-config",
          "$${NOMAD_TASK_DIR}/config.hcl",
          "-http-bind-address",
          "0.0.0.0",
          "-http-bind-port",
          "$${NOMAD_PORT_autoscaler}",
          "-policy-dir",
          "$${NOMAD_TASK_DIR}/policies/",
          "-log-level",
          "TRACE" // Switch to TRACE for debugging purposes.
        ]
      }

      artifact {
        source = "https://releases.hashicorp.com/nomad-autoscaler/${autoscaler_version}/nomad-autoscaler_${autoscaler_version}_linux_amd64.zip"
        destination = "local"
      }

      template {
        data = <<EOF
nomad {
  address = "http://{{env "attr.unique.network.ip-address" }}:4646"
  token = "${token}"
}

apm "prometheus" {
  driver = "prometheus"
  config = {
    address = "http://127.0.0.1:9090"
  }
}

target "aws-asg" {
  driver = "aws-asg"
  config = {
    aws_region = "{{ $x := env "attr.platform.aws.placement.availability-zone" }}{{ $length := len $x |subtract 1 }}{{ slice $x 0 $length}}"
  }
}

strategy "threshold" {
  driver = "threshold"
}

strategy "target-value" {
  driver = "target-value"
}
EOF

        destination = "$${NOMAD_TASK_DIR}/config.hcl"
      }

      template {
        data = <<EOF

scaling "cpu_low" {
  enabled = true
  min     = ${client_min_nodes}
  max     = ${client_max_nodes}

  policy {
    cooldown            = "5m"
    evaluation_interval = "1m"
    on_check_error      = "fail"

    check "low_cpu_usage" {
      source = "prometheus"
      query  = "sum(nomad_client_allocated_cpu{node_class='${client_node_class}'}*100/(nomad_client_unallocated_cpu{node_class='${client_node_class}'}+nomad_client_allocated_cpu{node_class='${client_node_class}'}))/count(nomad_client_allocated_cpu{node_class='${client_node_class}'})"

      strategy "threshold" {
        upper_bound = ${client_low_cpu_target}
        lower_bound = 0

        # ...remove one instance.
        delta = -1
      }
    }

    target "aws-asg" {
      dry-run             = "false"
      aws_asg_name        = "${client_asg_name}"
      node_class          = "${client_node_class}"
      node_drain_deadline = "5m"
      node_selector_strategy = "least_busy"
    }
  }
}

scaling "cpu_high" {
  enabled = true
  min     = ${client_min_nodes}
  max     = ${client_max_nodes}

  policy {
    cooldown            = "4m"
    evaluation_interval = "1m"
    on_check_error      = "fail"

    check "high_cpu_usage" {
      source = "prometheus"
      query  = "sum(nomad_client_allocated_cpu{node_class='${client_node_class}'}*100/(nomad_client_unallocated_cpu{node_class='${client_node_class}'}+nomad_client_allocated_cpu{node_class='${client_node_class}'}))/count(nomad_client_allocated_cpu{node_class='${client_node_class}'})"

      strategy "threshold" {
        upper_bound = 100
        lower_bound = ${client_high_cpu_target}

        # ...add one instance.
        delta = 1
      }
    }

    target "aws-asg" {
      dry-run             = "false"
      aws_asg_name        = "${client_asg_name}"
      node_class          = "${client_node_class}"
      node_drain_deadline = "5m"
      node_selector_strategy = "least_busy"
    }
  }
}
EOF

        destination = "$${NOMAD_TASK_DIR}/policies/client.hcl"
      }

      resources {
        cpu    = 50
        memory = 80
      }

      service {
        name = "autoscaler"
        port = "autoscaler"

        check {
          type     = "http"
          path     = "/v1/health"
          interval = "5s"
          timeout  = "2s"
        }
      }
    }

    task "prometheus" {
      template {
        change_mode = "noop"
        destination = "local/prometheus.yml"

        data = <<EOH
---
global:
  scrape_interval: 60s
  scrape_timeout:  5s
  external_labels:
    cluster : erpc-${env}-${region}

scrape_configs:
#  - job_name: 'prometheus'
#    static_configs:
#      - targets:
#        - 'localhost:9090'
  - job_name: 'nomad'
    consul_sd_configs:
      - server: 'localhost:8500'
        services: ['nomad-client', 'nomad']
        token: '{{ key "consul/tokens/prometheus" }}'
    relabel_configs:
      - source_labels: ['__meta_consul_tags']
        regex: '(.*)http(.*)'
        action: keep
    metrics_path: /v1/metrics
    params:
      format: ['prometheus']
  - job_name: 'elastic_rpc_metrics'
    consul_sd_configs:
      - server: 'localhost:8500'
        services: ['nolog-erpc-reader-metrics', 'nolog-erpc-writer-metrics']
        token: '{{ key "consul/tokens/prometheus" }}'
    relabel_configs:
    - source_labels: [__meta_consul_tags]
      regex: '.*,enodetype=([^,]+),.*'
      replacement: '$1'
      target_label: 'erpc_type'
    - source_labels: [__meta_consul_tags]
      regex: '.*,shard=([^,]+),.*'
      replacement: '$1'
      target_label: 'shard'
    metrics_path: /metrics
  - job_name: 'elastic_rpc_metrics_eth'
    consul_sd_configs:
      - server: 'localhost:8500'
        services: ['nolog-erpc-reader-metrics', 'nolog-erpc-writer-metrics']
        token: '{{ key "consul/tokens/prometheus" }}'
    relabel_configs:
    - source_labels: [__meta_consul_tags]
      regex: '.*,enodetype=([^,]+),.*'
      replacement: '$1'
      target_label: 'enode_type'
    - source_labels: [__meta_consul_tags]
      regex: '.*,shard=([^,]+),.*'
      replacement: '$1'
      target_label: 'shard'
    metrics_path: /metrics/eth

remote_write:
  - url: https://prometheus-prod-10-prod-us-central-0.grafana.net/api/prom/push
    basic_auth:
      username: {{ key "consul/users/grafana" }}
      password: {{ key "consul/tokens/grafana-publisher" }}
EOH
      }

      resources {
        cpu    = 200
        memory = 300
      }

      driver = "exec"

      config {
        command = "prometheus-2.25.2.linux-amd64/prometheus"
        args = ["--config.file", "local/prometheus.yml"]
      }

      artifact {
        source = "https://github.com/prometheus/prometheus/releases/download/v2.25.2/prometheus-2.25.2.linux-amd64.tar.gz"
        destination = "local"
      }

      service {
        name = "prometheus"
        tags = ["urlprefix-/prom strip=/prom"]
        port = "http"

        check {
          name     = "alive"
          type     = "http"
          path     = "/-/healthy"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
