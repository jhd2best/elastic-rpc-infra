#!/bin/bash

# this scripts installs and configures nomad

error=1
while [ "$error" != "0" ]; do
    sleep 5
    consul kv get "consul/tokens/nomad"
    error=$?
done

function install_nomad {
    curl -O https://releases.hashicorp.com/nomad/${nomad_version}/nomad_${nomad_version}_linux_amd64.zip
    unzip nomad_${nomad_version}_linux_amd64.zip
    rm nomad_${nomad_version}_linux_amd64.zip
    mv nomad /usr/bin

    mkdir -p /etc/nomad.d
    mkdir -p /opt/nomad
#   Promtail setup https://learn.hashicorp.com/tutorials/nomad/exec-users-host-volumes?in=nomad/stateful-workloads
    useradd -M -U promtail_user
    mkdir -p /opt/nomad/promtail
    chown promtail_user:promtail_user /opt/nomad/promtail
    chmod 700 /opt/nomad/promtail
#   fastcache setup https://learn.hashicorp.com/tutorials/nomad/exec-users-host-volumes?in=nomad/stateful-workloads
    useradd -M -U fastcache_user
    mkdir -p /opt/nomad/fastcache
    chown fastcache_user:fastcache_user /opt/nomad/fastcache
    chmod 700 /opt/nomad/fastcache
}

function install_nomad_service {
    cat <<EOF > /usr/lib/systemd/system/nomad.service
[Unit]
Description="Nomad"
Documentation=https://www.nomadproject.io/docs/
Wants=network-online.target
After=network-online.target
Wants=consul.service
After=consul.service

[Service]
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/bin/nomad agent -config /etc/nomad.d
KillMode=process
KillSignal=SIGINT
LimitNOFILE=infinity
LimitNPROC=infinity
Restart=on-failure
RestartSec=2
StartLimitBurst=3
StartLimitIntervalSec=10
TasksMax=infinity
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF
}

function generate_nomad_config {
    token=`consul kv get consul/tokens/nomad`
    cat <<EOF > /etc/nomad.d/nomad.hcl
datacenter = "${datacenter}"
region = "${region}"
data_dir = "/opt/nomad"
consul {
    token = "$token"
}
acl {
    enabled = true
}
telemetry {
    collection_interval = "1s"
    disable_hostname = true
    prometheus_metrics = true
    publish_allocation_metrics = true
    publish_node_metrics = true
}
EOF
}

function create_nomad_server_config {
    token=`uuidgen`
    consul kv put -cas "nomad/tokens/repl" $token
    if [ "$?" != "" ]; then
        token=`consul kv get nomad/tokens/repl`
    fi
    cat <<EOF > /etc/nomad.d/server.hcl
server {
    enabled = true
    bootstrap_expect = ${server_nodes}
}
acl {
    enabled = true
    replication_token = "$token"
}
EOF
}

function create_nomad_client_config {
    cat <<EOF > /etc/nomad.d/client.hcl
client {
    enabled = true
    max_kill_timeout = "180s"
    node_class = "${group_id}"
    meta {
        group_id = "${group_id}"
        %{ if server_nodes == "" }
        node_type = "client"
        %{ endif }
    }
    host_volume "nomad_data" {
      path      = "/opt/nomad/alloc"
      read_only = true
    }
   host_volume "promtail_data" {
      path      = "/opt/nomad/promtail"
      read_only = false
  }
   host_volume "fastcache_data" {
      path      = "/opt/nomad/fastcache"
      read_only = false
  }
}

plugin "docker" {
    config {
        allow_privileged = true
    }
}
EOF
}

function bootstrap_nomad {
    consul kv put -cas nomad/tokens/master 1
    if [ "$?" == "0" ]; then
        token=`nomad acl bootstrap | grep Secret |  awk '{print $4}'`
        if [ "$token" != "" ]; then
            consul kv put "nomad/tokens/master" $token
        else
            consul kv delete "nomad/tokens/master"
        fi
    fi
}

install_nomad
generate_nomad_config
install_nomad_service

#%{ if server_nodes != "" }
create_nomad_server_config
#%{ endif }

#%{ if server_nodes == "" || server_nodes == "1" }
create_nomad_client_config
#%{ endif }

systemctl daemon-reload
systemctl start nomad

#%{ if server_nodes != "" }
sleep 10
bootstrap_nomad
#%{ endif }
