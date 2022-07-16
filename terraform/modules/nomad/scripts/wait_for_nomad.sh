#!/bin/bash

# eval "$(jq -r '@sh "addr=\(.addr) token=\(.token)"')"

addr=$1
token=$2
echo "consul address=$addr"
# echo "consul token=$token"

set +e
while true; do
    L=`curl -s --header "X-Consul-Token: $token" "$addr/v1/kv/nomad/tokens/master?raw"`
    if [[ ${L//-/} =~ ^[[:xdigit:]]{32}$ ]]; then
        # echo $L > .terraform/nomad.txt
        break
    fi
    echo "consul reply: $L"
    sleep 5
    # echo "waiting for nomad..."
done
set -e
