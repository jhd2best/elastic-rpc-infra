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
  project    = "elastic-rpc"
  domain     = "${var.region}.${var.env}.${var.domain}"
  rootDomain = var.domain
}

data "aws_key_pair" "harmony" {
  key_name = "harmony-node"
}

module "nomad" {
  source         = "../nomad"
  nomad_version  = "1.3.2"
  consul_version = "1.12.3"
  region         = var.region
  domain         = local.domain
  rootDomain     = local.rootDomain
  env            = var.env
  project        = "erpc-${var.env}-${var.region}"
  cluster_id     = "erpc-${var.env}-${var.region}"
  ssh_key_name   = data.aws_key_pair.harmony.key_name
  zone_id        = var.web_zone_id
  vpc            = data.aws_vpc.vpc
  cluster_groups = local.groups
  fabio_shard = concat([], [ # websocket shards
    for k, bd in var.shard_conf :
    {
      shard_number            = bd.shard_number
      subdomain               = "ws"
      other_supported_domains = bd.other_supported_domains_wss
      grpc                    = false
    }
    ], [ # http shards
    for k, bd in var.shard_conf :
    {
      shard_number            = bd.shard_number
      subdomain               = "api"
      other_supported_domains = bd.other_supported_domains_http
      grpc                    = false
    }
  ])
  public_subnet_ids = data.aws_subnet.public.*.id
}

module "tkiv" {
  source = "../tkiv"
}

module "redis" {
  source        = "../redis"
  env           = var.env
  redis_version = var.redis_version
  region        = var.region
  shard_conf    = var.shard_conf
  subnets       = data.aws_subnet.public
  vpc_id        = data.aws_vpc.vpc.id

  depends_on = [data.aws_subnet.public]
}

module "jobs" {
  source     = "../../modules/jobs"
  env        = var.env
  network    = var.network
  nomad      = module.nomad
  region     = var.region
  boot_nodes = var.boot_nodes
  shard_config = [
    for k, bd in var.shard_conf : {
      shard_wss_endpoint  = "ws.s${bd.shard_number}.${local.domain}"
      shard_http_endpoint = "api.s${bd.shard_number}.${local.domain}"
      shard_number        = bd.shard_number
      redis_addr          = "${module.redis.shard_addresses[bd.shard_number]}:${module.redis.shard_ports[bd.shard_number]}"
      tkiv_addr           = module.tkiv.tkiv_url
    }
  ]

  depends_on = [module.redis]
}