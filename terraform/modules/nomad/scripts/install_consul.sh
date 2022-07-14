#!/bin/bash

# this scripts installs and configures consul

export CONSUL_HTTP_TOKEN=${consul_master_token}

function install_consul {
    curl -O https://releases.hashicorp.com/consul/${consul_version}/consul_${consul_version}_linux_amd64.zip
    unzip consul_${consul_version}_linux_amd64.zip
    rm consul_${consul_version}_linux_amd64.zip
    mv consul /usr/bin

    mkdir -p /etc/consul.d
    mkdir -p /opt/consul
}

function install_consul_service {
    cat <<EOF > /usr/lib/systemd/system/consul.service
[Unit]
Description="Consul"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul.d/consul.hcl

[Service]
Type=notify
User=root
Group=root
ExecStart=/usr/bin/consul agent -config-dir=/etc/consul.d/ -bind '{{ GetInterfaceIP "eth0" }}'
ExecReload=/usr/bin/consul reload
ExecStop=/usr/bin/consul leave
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
}

function generate_consul_config {
    cat <<EOF > /etc/consul.d/consul.hcl
datacenter = "${datacenter}"
data_dir = "/opt/consul"
retry_join = ["provider=aws tag_key=aws:autoscaling:groupName tag_value=${autoscaling_group_name}"]

acl {
    enabled        = true
    default_policy = "deny"
    down_policy    = "extend-cache"
    tokens {
        "agent" = "${consul_agent_token}"
    }
}
EOF
}

function create_consul_server_config {
    cat <<EOF > /etc/consul.d/server.hcl
    server = true
    bootstrap_expect = ${server_nodes}

    ui = true
    client_addr = "0.0.0.0"

    acl {
        tokens {
            "master" = "${consul_master_token}"
        }
    }

    # remove this in production
    performance {
        raft_multiplier = 5
    }
EOF
}

function create_consul_client_config {
    cat <<EOF > /etc/consul.d/client.hcl
acl {
    tokens {
  	    "default" = "${consul_anon_token}"
    }
}
EOF
}

function setup_consul_acl {

  error=1
  while [ "$error" != "0" ]; do
      sleep 5
      consul acl policy read -name global-management
      error=$?
  done

  consul kv put -cas "consul/tokens/master" ${consul_master_token}

  if [ "$?" == "0" ]; then
      consul acl policy create -name agent-policy \
      -description "Agent Policy" \
      -rules 'node_prefix "" { policy = "write" } service_prefix "" { policy = "read" }'
      consul kv put "consul/tokens/agent" ${consul_agent_token}
      consul acl token create -description "Agent Token" -policy-name "agent-policy" -secret ${consul_agent_token}

      consul acl policy create -name 'dns-policy' \
      -description "Allows anonymous DNS queries" \
      -rules 'node_prefix "" { policy = "read" } service_prefix "" { policy = "read" }'
      consul kv put "consul/tokens/anon" ${consul_anon_token}
      consul acl token create -description "DNS Token" -policy-name "dns-policy" -secret ${consul_anon_token}

      consul acl policy create -name "ui-policy" \
      -description "Necessary permissions for UI functionality" \
      -rules 'key_prefix "" { policy = "write" } node_prefix "" { policy = "read" } service_prefix "" { policy = "read" }'
      token=`uuidgen`
      consul kv put "consul/tokens/ui" $token
      consul acl token create -description "UI Token" -policy-name "ui-policy" -secret=$token

      consul acl policy create -name 'nomad-server-policy' \
      -description "Permissions for the nomad server/client" \
      -rules 'agent_prefix "" {policy = "read"} key_prefix "" { policy = "read" } node_prefix "" {policy = "read"} service_prefix "" {policy = "write"} acl = "write"'
      token=`uuidgen`
      consul kv put "consul/tokens/nomad" $token
      consul acl token create -description "Nomad Server Token" -policy-name "nomad-server-policy" -secret $token

      consul acl policy create -name 'fabio-policy' \
      -description "Permissions for the Fabio load balancer" \
      -rules 'agent_prefix "" {policy = "read"} node_prefix "" {policy = "read"} service_prefix "" {policy = "write"}'
      token=`uuidgen`
      consul kv put "consul/tokens/fabio" $token
      consul acl token create -description "Fabio Token" -policy-name "fabio-policy" -secret $token

      consul acl policy create -name 'prometheus-policy' \
      -description "Permissions for Prometheus" \
      -rules 'agent_prefix "" {policy = "read"} node_prefix "" {policy = "read"} service_prefix "" {policy = "write"}'
      token=`uuidgen`
      consul kv put "consul/tokens/prometheus" $token
      consul acl token create -description "Prometheus Token" -policy-name "prometheus-policy" -secret $token

      consul kv put "config/domain" "${domain}"
  fi
}

install_consul
generate_consul_config
install_consul_service

#%{ if server_nodes != "" }
create_consul_server_config
#%{ else }
create_consul_client_config
#%{ endif }

systemctl daemon-reload
systemctl start consul

#%{ if server_nodes != "" }
setup_consul_acl
#%{ endif }
