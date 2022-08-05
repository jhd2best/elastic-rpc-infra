variable "region" {}
variable "env" {}
variable "redis_version" {}
variable "vpc_id" {}
variable "subnets" { default = [] }

variable "shard_conf" {
  type = list(object({
    shard_number             = number
    redis_shards             = number
    redis_replicas_per_shard = number
    redis_instance_type      = string
  }))
}