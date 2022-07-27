variable "domain" {
  description = "the base domain for the entry of tkiv you build it. like 'erpc.com'"
  type        = string
}

variable "zone_id" {
  description = "Route 53 zone id"
  type        = string
}

variable "vpc_id" {
  description = "vpc the tkiv should be created into. like 'vpc-1aaec862'"
  type        = string
}

variable "manager_cidr_block" {
  description = "cidr block of ips which can manage cluster"
  default     = "0.0.0.0/0"
  type        = string
}

variable "availability_zone" {
  description = "zone the tkiv should be created into. like 'us-west-2a'"
  type        = string
}

variable "tkiv_pd_node_number" {
  description = "this will be the number of tkiv pd nodes wanted in per cluster"
  default     = 3
  type        = number
}

variable "tikv_pd_node_instance_type" {
  description = "this will be the instance type of tkiv pd nodes wanted in cluster"
  default     = "t3.xlarge"
  type        = string
}

variable "tkiv_data_node_number" {
  description = "this will be the number of tkiv data nodes wanted in per cluster"
  default     = 3
  type        = number
}

variable "tikv_data_node_instance_type" {
  description = "this will be the instance type of tkiv data nodes wanted in cluster"
  default     = "i3en.2xlarge"
  type        = string
}

variable "cluster_version" {
  description = "the tikv version wanted for the tkiv cluster. like 'v5.3.1'"
  default     = "v5.3.1"
  type        = string
}

variable "cluster_name" {
  description = "the cluster name wanted for the tkiv cluster"
  default     = "elastic-rpc-cluster"
  type        = string
}

variable "tkiv_replication_factor" {
  description = "the replication factor wanted for the tkiv cluster"
  default     = 2
  type        = number
}

variable "is_cluster_public" {
  description = "whether we will make the cluster to public"
  default     = false
  type        = bool
}