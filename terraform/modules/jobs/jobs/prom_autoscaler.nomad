job "prometheus-autoscaler" {
  datacenters = ["dc1"]
  type        = "service"

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
          "INFO" // Switch to TRACE for debugging purposes.
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
EOF

        destination = "$${NOMAD_TASK_DIR}/config.hcl"
      }

      template {
        data = <<EOF
scaling "memory_low" {
  enabled = true
  min     = 1
  max     = ${client_max_nodes}

  policy {
    cooldown            = "3m"
    evaluation_interval = "1m"
    on_check_error      = "fail"

    check "low_memory_usage" {
      source = "prometheus"
      query  = "sum(nomad_client_allocated_memory*100/(nomad_client_unallocated_memory+nomad_client_allocated_memory))/count(nomad_client_allocated_memory)"

      strategy "threshold" {
        upper_bound = ${client_low_memory_target}
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

scaling "cpu_low" {
  enabled = true
  min     = 1
  max     = ${client_max_nodes}

  policy {
    cooldown            = "5m"
    evaluation_interval = "1m"
    on_check_error      = "fail"

    check "low_cpu_usage" {
      source = "prometheus"
      query  = "sum(nomad_client_allocated_cpu*100/(nomad_client_unallocated_cpu+nomad_client_allocated_cpu))/count(nomad_client_allocated_cpu)"

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

scaling "metrics_high" {
  enabled = true
  min     = 1
  max     = ${client_max_nodes}

  policy {
    cooldown            = "3m"
    evaluation_interval = "1m"
    on_check_error      = "fail"

    check "high_cpu_usage" {
      source = "prometheus"
      query  = "sum(nomad_client_allocated_cpu*100/(nomad_client_unallocated_cpu+nomad_client_allocated_cpu))/count(nomad_client_allocated_cpu)"

      strategy "threshold" {
        upper_bound = 100
        lower_bound = ${client_high_cpu_target}

        # ...add one instance.
        delta = 1
      }
    }

    check "high_memory_usage" {
      source = "prometheus"
      query  = "sum(nomad_client_allocated_memory*100/(nomad_client_unallocated_memory+nomad_client_allocated_memory))/count(nomad_client_allocated_memory)"

      strategy "threshold" {
        upper_bound = 100
        lower_bound = ${client_high_memory_target}

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
  scrape_interval: 15s
  scrape_timeout:  5s
  external_labels:
    nomad_cluster: ${nomad_cluster}
    region : ${region}
    env : ${env}

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets:
        - 'localhost:9090'
  - job_name: 'nomad'
    consul_sd_configs:
      - server: 'localhost:8500'
        services: ['nomad-client', 'nomad']
        token: '{{ key "consul/tokens/prometheus" }}'
    relabel_configs:
      - source_labels: ['__meta_consul_tags']
        regex: '(.*)http(.*)'
        action: keep
    scrape_interval: 5s
    metrics_path: /v1/metrics
    params:
      format: ['prometheus']
  - job_name: 'elastic_rpc'
    consul_sd_configs:
      - server: 'localhost:8500'
        services: ['elastic-rpc-writer', 'elastic-rpc-reader']
        token: '{{ key "consul/tokens/prometheus" }}'
    metric_relabel_configs:
    - source_labels: [__name__]
      regex: node_network_transmit_bytes_total|node_network_receive_bytes_total|node_time_seconds
      action: keep
    relabel_configs:
    - source_labels: [__meta_consul_tags]
      regex: '.*,projectid=([^,]+),.*'
      replacement: '$1'
      target_label: 'projectid'
    - source_labels: [__meta_consul_tags]
      regex: '.*,tier=([^,]+),.*'
      replacement: '$1'
      target_label: 'tier'
    scrape_interval: 15s
    metrics_path: /metrics

remote_write:
  - url: https://prometheus-blocks-prod-us-central1.grafana.net/api/prom/push
    basic_auth:
      username: 117965
      password: {{ key "consul/tokens/grafana-publisher" }}
EOH
      }

      resources {
        cpu    = 500
        memory = 500
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
