variable "region" {}
variable "env" {}
variable "network" {}
variable "boot_nodes" {}
variable "domain" {}
variable "web_zone_id" {}
variable "vpc_index" { default = 51 }
variable "tkiv_data_node_number" { default = 3 }
variable "client_instance_type" { default = "c5.4xlarge" }
variable "writer_instance_type" { default = "m5.2xlarge" }
variable "redis_version" { default = "redis6.x" }

variable "shard_conf" {
  type = list(object({
    shard_number             = number
    redis_shards             = number
    redis_replicas_per_shard = number
    num_writers              = number
    min_num_readers          = number
    redis_instance_type      = string
    # if the domains are subdomains of the root domain the default script will support them
    # if they belong to another hosting zone it'll try to import an exisiting certificate
    other_supported_domains_http = list(string)
    other_supported_domains_wss  = list(string)
  }))
}
