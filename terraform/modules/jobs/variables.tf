variable "env" {}
variable "network" {}
variable "region" {}
variable "nomad" {}

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
  default     = 40
}

variable "high_memory_target" {
  description = "High memory % threshold for the cluster autoscaling"
  type        = number
  default     = 70
}

variable "low_memory_target" {
  description = "Low memory % threshold for the cluster autoscaling"
  type        = number
  default     = 40
}

variable "shard_config" {
  type = list(object({
    shard_number                 = number
    shard_http_endpoint          = string
    shard_wss_endpoint           = string
    redis_addr                   = string
    tkiv_addr                    = string
    other_supported_domains_http = list(string)
    other_supported_domains_wss  = list(string)
  }))

  default = []
}
