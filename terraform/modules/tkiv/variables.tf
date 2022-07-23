variable "domain" {
  # base domain for the tkiv you can build it like ---> "pd1.${var.domain}"
  # and use the config to point to all the subdomains like ---> "tkdata1.${var.domain}", "tkdata2.${var.domain}", etc.
  # this will give us more flexibility to update ec2 instances since we won't have to update other nodes
  # if one ec2 instance is replace, we just have to point the domain to the new ip
  type = string
}

variable "vpc" { # vpc the tkiv should be created into
  type = object({
    id         = string
    cidr_block = string
  })
}


variable "subnet_ids" {
  # subnet ids the cluster should be created into each subnet is in a different az
  # create all the pd and data nodes across all this subnets this list
  type = list(string)
}

variable "is_cluster_public" {
  # this is so we can make the cluster temporaly public, this will make the subdomains to point to the public ips rather than the private ones and will open the security group
  # this will be for maintance purposes too, where we wil need to sync the cluster from outside the vpc
  type    = bool
  default = false
}

variable "tkiv_data_node_size_tb" {
  type = number
  # this is the size of each mounted volume in terabytes per tkiv data node  (feel free to update this number if we need more or less)
  default = 3.5
}

variable "tkiv_data_node_number" {
  type = number
  # this will be the number of tkiv nodes wanted per cluster (feel free to update this number if we need more or less)
  default = 15
}

variable "tkiv_replication_factor" {
  type = number
  # this is the replication factor wanted for the tkiv cluster
  default = 2
}