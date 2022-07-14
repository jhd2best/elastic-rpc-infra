variable "domain" {}
variable "env" {}
variable "region" {}
variable "nomad" {}

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
