output "aws_region" {
  value = var.region
}

output "vpc" {
  value = aws_vpc.vpc
}

output "nomad" {
  value = module.nomad
}

output "redis_shard_addresses" {
  value = {
    for k, bd in aws_elasticache_replication_group.redis_shard : k => bd.configuration_endpoint_address
  }
}

output "redis_shard_ports" {
  value = {
    for k, bd in aws_elasticache_replication_group.redis_shard : k => bd.port
  }
}