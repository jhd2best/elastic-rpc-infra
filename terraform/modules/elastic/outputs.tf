output "aws_region" {
  value = var.region
}

output "vpc" {
  value = aws_vpc.vpc
}

output "nomad" {
  value = module.nomad
}

#output "redis_address" {
#  value = aws_elasticache_replication_group.redis_shard.*.configuration_endpoint_address
#}
#
#output "redis_port" {
#  value = aws_elasticache_replication_group.redis_shard.*.port
#}