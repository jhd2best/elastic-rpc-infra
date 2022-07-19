locals {
  redis_port = 6379
}

resource "aws_elasticache_replication_group" "redis_shard" {
  for_each = { for obj in var.shard_conf : obj.shard_number => obj }

  replication_group_id       = "${var.region}-${var.env}-S${each.key}-elastic-rpc"
  description                = "elastic cluster for shard ${each.key}"
  node_type                  = each.value.redis_instance_type
  port                       = local.redis_port
  apply_immediately          = false # this has to be false because that way any changes will be applied in the next maintenance window
  auto_minor_version_upgrade = true
  maintenance_window         = "tue:06:30-tue:07:30"
  num_node_groups            = each.value.redis_shards
  replicas_per_node_group    = each.value.redis_replicas_per_node_group
  data_tiering_enabled       = false
  automatic_failover_enabled = true
  multi_az_enabled           = true
  parameter_group_name       = aws_elasticache_parameter_group.elastic_redis.name
  security_group_ids         = [aws_security_group.elastic_redis.id]

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.elastic_cloud_watch.name
    destination_type = "cloudwatch-logs"
    log_format       = "text"
    log_type         = "slow-log"
  }
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.elastic_cloud_watch.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }
}

resource "aws_security_group" "elastic_redis" {
  name = "elastic-rpc-redis-${var.region}-${var.env}"
  ingress {
    protocol    = "tcp"
    from_port   = local.redis_port
    to_port     = local.redis_port
    cidr_blocks = aws_subnet.public.*.cidr_block
  }
}

resource "aws_elasticache_parameter_group" "elastic_redis" {
  name   = "elastic-rpc-redis-${var.region}-${var.env}"
  family = var.redis_version

  parameter {
    name  = "maxmemory-policy"
    value = "volatile-ttl"
  }
  parameter {
    name  = "maxmemory-samples"
    value = 30
  }
  parameter {
    name  = "cluster-enabled"
    value = "yes"
  }
  parameter {
    name  = "cluster-allow-reads-when-down"
    value = "yes"
  }
}
