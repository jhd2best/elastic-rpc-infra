variable "region" {}
variable "env" {}
variable "domain" {}
variable "web_zone_id" {}
variable "vpc_index" {}
variable "instance_type" { default = "c5.4xlarge" }
variable "redis_version" { default = "redis6.x" }

variable "shard_conf" {
  type = list(object({
    shard_number                  = number
    redis_shards                  = number
    redis_replicas_per_node_group = number
    redis_instance_type           = string
  }))
}
