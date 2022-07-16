job "fabio" {
  datacenters = ["dc1"]
  type = "system"

  group "fabio" {
    task "fabio" {
      driver = "docker"
      config {
        image = "fabiolb/fabio"
        network_mode = "host"
        volumes = [
          "local/fabio:/etc/fabio",
        ]
      }

      resources {
        cpu    = 200
        memory = 128
        network {
          mbits = 20
          port "lb" {
            static = 9999
          }
          port "ui" {
            static = 9998
          }
          port "grpc" {
            static = 9997
          }
        }
      }

      env {
        proxy_addr = ":9999;proto=http,:9997;proto=grpc"
      }

      template {
        // this is the Consul's Fabio token
        data = "registry.consul.token = {{ key \"consul/tokens/fabio\" }}"
        destination = "local/fabio/fabio.properties"
      }
    }
  }
}
