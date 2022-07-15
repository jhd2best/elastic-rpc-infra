resource "aws_elasticache_replication_group" "redis_shard" {
  for_each = { for obj in var.shard_conf : obj.shard_number => obj }

  replication_group_id       = "${var.region}-${var.env}-S${each.value.shard_number}-elastic-rpc"
  description                = "elastic cluster for shard ${each.value.shard_number}"
  node_type                  = each.value.redis_instance_type
  port                       = 6379
  apply_immediately          = false # this has to be false because that way any changes will be applied in the next maintenance window
  auto_minor_version_upgrade = false
  maintenance_window         = "tue:06:30-tue:07:30"
  num_node_groups            = each.value.redis_shards
  replicas_per_node_group    = each.value.redis_replicas_per_node_group
  data_tiering_enabled       = false
  automatic_failover_enabled = true
  parameter_group_name       = aws_elasticache_parameter_group.elastic.name

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.elastic_cloud_watch.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }
}

resource "aws_elasticache_parameter_group" "elastic" {
  name   = "elastic-rpc-custom"
  family = var.redis_version

  parameter {
    name  = "maxmemory-policy"
    value = "volatile-ttl"
  }
}