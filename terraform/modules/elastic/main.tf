# this module sets up a Nomad cluster to run the elastic rpc

terraform {
  required_providers {
    aws = {}
  }
}

locals {
  groups = [
    {
      id              = "server"
      instance_type   = "t3.micro"
      instance_count  = { min : 3, max : 3, desired : 3 }
      security_groups = []
    },
    {
      id             = "client"
      instance_type  = var.instance_type
      instance_count = { min : 0, max : 15, desired : 2 },
      security_groups = [                                 # this groups are open to the whole world so used them with caution
        { protocol : "icmp", from_port : 8, to_port : 0 } # enough to enable ping
      ]
    }
  ]
  project = "elastic-rpc"
}

data "aws_key_pair" "harmony" {
  key_name = "harmony-node"
}

module "nomad" {
  source            = "../nomad"
  nomad_version     = "1.3.2"
  consul_version    = "1.12.3"
  region            = var.region
  domain            = "${var.region}.${var.env}.${var.domain}"
  env               = var.env
  project           = "erpc-${var.env}-${var.region}"
  cluster_id        = "erpc-${var.env}-${var.region}"
  ssh_key_name      = data.aws_key_pair.harmony.key_name
  zone_id           = var.web_zone_id
  vpc               = aws_vpc.vpc
  cluster_groups    = local.groups
  fabio_apps        = {}
  public_subnet_ids = aws_subnet.public.*.id
}

module "tkiv" {
  source = "../tkiv"
}

module "jobs" {
  source = "../../modules/jobs"
  env    = var.env
  nomad  = module.nomad
  region = var.region
}