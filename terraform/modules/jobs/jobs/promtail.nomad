job "promtail" {
  datacenters = ["dc1"]
  type = "system"

  group "promtail" {
    count = 1

    ephemeral_disk {
      size = 300
    }
    network {
      port "http" {
        static = 3200
      }
    }
    volume "alloc" {
      type      = "host"
      source    = "nomad_data"
      read_only = true
    }

    volume "data" {
      type      = "host"
      source    = "promtail_data"
      read_only = false
    }

    task "promtail" {
      user = "promtail_user"

      resources {
        cpu    = 80
        memory = 80
      }

      template {
        change_mode = "noop"
        destination = "local/promtail.yml"

        data = <<EOH
---
positions:
  filename: /data/promtail_positions.yaml

client:
  url: https://{{ key "consul/params/loki-user" }}:{{ key "consul/tokens/grafana-publisher" }}@logs-prod3.grafana.net/loki/api/v1/push
  external_labels:
    env : ${env}
    region : ${region}

server:
  http_listen_port: 0
  grpc_listen_port: 0

scrape_configs:
- job_name: 'nomad-logs'
  consul_sd_configs:
    - server: 'localhost:8500'
      token: '{{ key "consul/tokens/prometheus" }}'
  relabel_configs:
    - source_labels: [__meta_consul_node]
      target_label: __host__
    - source_labels: [__meta_consul_service_metadata_external_source]
      target_label: source
      regex: (.*)
      replacement: '$1'
    - source_labels: [__meta_consul_service_id]
      regex: '_nomad-task-([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})-.*'
      target_label:  'task_id'
      replacement: '$1'
    - source_labels: [__meta_consul_tags]
      regex: ',(app|monitoring),'
      target_label:  'group'
      replacement:   '$1'
    - source_labels: [__meta_consul_service]
      target_label: job
    - source_labels: ['__meta_consul_node']
      regex:         '(.*)'
      target_label:  'instance'
      replacement:   '$1'
    - source_labels: [__meta_consul_tags]
      regex: ',(?:[^,]+,){0}([^=]+)=([^,]+),.*'
      replacement: '$2'
      target_label: '$1'
    - source_labels: [__meta_consul_tags]
      regex: ',(?:[^,]+,){1}([^=]+)=([^,]+),.*'
      replacement: '$2'
      target_label: '$1'
    - source_labels: [__meta_consul_tags]
      regex: ',(?:[^,]+,){2}([^=]+)=([^,]+),.*'
      replacement: '$2'
      target_label: '$1'
    - source_labels: [__meta_consul_service_id]
      regex: '_nomad-task-([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})-.*'
      target_label:  '__path__'
      replacement: '/alloc/$1/alloc/logs/*std*.{?,??}'
EOH
      }

      volume_mount {
        volume      = "alloc"
        destination = "/alloc"
        read_only = true
      }

      volume_mount {
        volume      = "data"
        destination = "/data"
        read_only = false
      }

      driver = "exec"

      artifact {
        source = "https://github.com/grafana/loki/releases/download/v2.2.1/promtail-linux-amd64.zip"
        destination = "local"
      }

      config {
        command = "promtail-linux-amd64"
        args = [
          "-config.file=local/promtail.yml",
          "-server.http-listen-port=$${NOMAD_PORT_http}",
        ]
      }

      service {
        name = "promtail"
        tags = [
          "monitoring"]
        port = "http"

        check {
          name = "promtail alive"
          type = "http"
          path = "/targets"
          interval = "10s"
          timeout = "2s"
        }
      }
    }
  }
}
