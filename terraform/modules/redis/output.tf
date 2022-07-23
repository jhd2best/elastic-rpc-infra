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
#output "shard_addresses" {
#  value = {
#    0 = "explorer-cluster-v2-s0-e0.fkcwg2.clustercfg.usw2.cache.amazonaws.com"
#    1 = "explorer-cluster-v2-s1-e0.fkcwg2.clustercfg.usw2.cache.amazonaws.com"
#  }
#}
#
#output "shard_ports" {
#  value = {
#    0 = 6379
#    1 = 6379
#  }
#}