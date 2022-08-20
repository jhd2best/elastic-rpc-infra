output "shard_addresses" {
  value = {
    for k, bd in aws_elasticache_replication_group.redis_shard : k => bd.configuration_endpoint_address
  }
}

output "shard_ports" {
  value = {
    for k, bd in aws_elasticache_replication_group.redis_shard : k => bd.port
  }
}
