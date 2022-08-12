variable "env" {}
variable "network" {}
variable "region" {}
variable "nomad" {}
variable "is_cluster_public" { type = bool }

variable "boot_nodes" {}
variable "dns_init_port" {}
variable "p2p_init_port" {}
variable "explorer_init_port" {}

variable "high_cpu_target" {
  description = "High CPU % threshold for the cluster autoscaling"
  type        = number
  default     = 70
}
variable "low_cpu_target" {
  description = "Low CPU % threshold for the cluster autoscaling"
  type        = number
  default     = 45
}

variable "shard_config" {
  type = list(object({
    writer_cpu                   = number
    writer_memory                = number
    shard_number                 = number
    shard_http_endpoint          = string
    shard_wss_endpoint           = string
    redis_addr                   = string
    tkiv_pd_addrs                = list(string)
    other_supported_domains_http = list(string)
    other_supported_domains_wss  = list(string)
  }))

  default = []
}
