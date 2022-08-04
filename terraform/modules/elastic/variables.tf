variable "region" {}
variable "env" {}
variable "network" {}
variable "boot_nodes" {}
variable "domain" {}
variable "web_zone_id" {}
variable "vpc_index" { default = 51 }
variable "tkiv_data_node_number" { default = 3 }
variable "instance_type" { default = "c5.4xlarge" }
variable "redis_version" { default = "redis6.x" }

variable "shard_conf" {
  type = list(object({
    shard_number                  = number
    redis_shards                  = number
    redis_replicas_per_node_group = number
    redis_instance_type           = string
    writer_cpu                    = number
    writer_memory                 = number
    # if the domains are subdomains of the root domain the default script will support them
    # if they belong to another hosting zone it'll try to import an exisiting certificate
    other_supported_domains_http = list(string)
    other_supported_domains_wss  = list(string)
  }))
}
