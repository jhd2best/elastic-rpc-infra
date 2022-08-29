variable "vpc_id" {
  description = "vpc the tkiv should be created into. like 'vpc-1aaec862'"
  type        = string
}

variable "manager_cidr_block" {
  description = "cidr block of ips which can manage cluster"
  default     = "0.0.0.0/0"
  type        = string
}

variable "subnets_ids" {
  description = "subnets into which the tkiv nodes will get deployed evenly"
  type        = list(string)
}

variable "new_tkiv_data_node_number" {
  description = "this will be the number of tkiv data nodes wanted in per cluster"
  default     = 2
  type        = number
}

variable "tikv_data_node_instance_type" {
  description = "this will be the instance type of tkiv data nodes wanted in cluster"
  default     = "i3en.2xlarge"
  type        = string
}

variable "cluster_name" {
  description = "the cluster name wanted for the tkiv cluster"
  default     = "elastic-rpc-cluster"
  type        = string
}

variable "pd_tiup_public_ip" {
  description = "the public ip for pd node which include tiup tool"
  type        = string
}

variable "pd_tiup_private_key" {
  description = "the private key of pd node which include tiup tool"
  type        = string
}