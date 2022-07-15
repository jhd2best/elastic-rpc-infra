resource "aws_elasticache_replication_group" "redis_shard" {
  replication_group_id       = "${var.region}-${var.env}-S0-elastic-rpc"
  description                = "elastic cluster for shard 0"
  node_type                  = "cache.r6g.large"
  port                       = 6379
  apply_immediately          = false
  auto_minor_version_upgrade = false
  maintenance_window         = "tue:06:30-tue:07:30"
  num_node_groups            = 3
  replicas_per_node_group    = 2
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
  family = "redis6.2"

  parameter {
    name  = "maxmemory-policy"
    value = "volatile-ttl"
  }
}