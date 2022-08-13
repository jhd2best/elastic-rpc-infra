#!/bin/sh
# Make sure the harmony bin is executable
chmod +x /local/harmony
export PATH=$PATH:/local

node_exporter --collector.disable-defaults --collector.netdev&
# Run the user command'c
echo "$@"
exec "$@"
