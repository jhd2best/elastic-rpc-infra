variable "consul_version" {
  default     = "1.12.2"
  description = "The consul version to deploy"
}

variable "nomad_version" {
  default     = "1.3.2"
  description = "The nomad version to deploy"
}

variable "ssh_key_name" {
  description = "Name of the SSH key to access the EC2 instances"
}

variable "cluster_groups" {
  type = list(object({
    id              = string,
    instance_type   = string,
    instance_count  = object({ min : number, max : number, desired : number }),
    security_groups = list(object({ protocol : string, from_port : number, to_port : number }))
  }))
  description = "Describe the client/server instances in the cluster"
}

variable "fabio_apps" {
  default = {
    // subdomain = "sub" OR path = "path"
    // grpc = true/false
  }
  description = "Register all the apps that are going to be hosted on the cluster"
}

variable "cluster_id" {
  description = "Unique ID of the cluster (for the region)"
}

variable "region" {
  description = "Short name region, e.g. us or eu or sg"
}

variable "domain" {
  description = "Root domain for the backend, e.g. hm.t.io"
}

variable "project" {
  description = "Project code name, e.g. elastic-rpc"
}

variable "env" {
  description = "Environment, e.g. mainet, testnet, etc"
}

variable "vpc" {
}

variable "public_subnet_ids" {
}

variable "zone_id" {
  description = "Route53 zone id where all the subdomains will be created"
}
