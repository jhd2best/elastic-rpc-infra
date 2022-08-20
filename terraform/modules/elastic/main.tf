# this module sets up a Nomad cluster to run the elastic rpc

terraform {
  required_providers {
    aws = {}
  }
}

locals {
  is_cluster_public = false # use this for maintenance purposes only like syncying the tkiv from another region
  dnsInitPort       = 6000
  p2pInitPort       = 9000
  explorerInitPort  = 5000 # this is 4000 ports bellow the p2p port https://github.com/harmony-one/harmony/blob/main/api/service/explorer/service.go#L31
  numOfWorkers      = sum([for g in var.shard_conf : g.num_writers])
  numOfReaders      = sum([for g in var.shard_conf : g.min_num_readers])
  tikvSubnets       = [aws_subnet.public[0].id]
  groups = [
    {
      id              = "server"
      instance_type   = "t3.micro"
      instance_count  = { min : 3, max : 3, desired : 3 }
      security_groups = []
      subnets_ids     = []
    },
    {
      id             = "writer"
      instance_type  = "m5.2xlarge"
      instance_count = { min : local.numOfWorkers, max : local.numOfWorkers, desired : local.numOfWorkers }
      subnets_ids    = local.tikvSubnets
      security_groups = [
        # this groups are open to the whole world so used them with caution
        { protocol : "icmp", from_port : 8, to_port : 0 },                                          # enough to enable ping
        { protocol : "tcp", from_port : local.dnsInitPort, to_port : local.dnsInitPort },           # open ports for upto 8 shards
        { protocol : "tcp", from_port : local.p2pInitPort, to_port : local.p2pInitPort },           # open ports for upto 8 shards
        { protocol : "tcp", from_port : local.explorerInitPort, to_port : local.explorerInitPort }, # open ports for upto 8 shards
      ]
    },
    {
      id              = "client"
      instance_type   = var.instance_type
      instance_count  = { min : local.numOfReaders, max : 15, desired : local.numOfReaders },
      security_groups = []
      subnets_ids     = []
    }
  ]
  project    = "elastic-rpc"
  domain     = "${var.region}.${var.env}.${var.domain}"
  cluster_id = "erpc-${var.env}-${var.region}"
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
  project        = local.cluster_id
  cluster_id     = local.cluster_id
  ssh_key_name   = data.aws_key_pair.harmony.key_name
  zone_id        = var.web_zone_id
  vpc            = aws_vpc.vpc
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
  public_subnet_ids = aws_subnet.public.*.id
}

module "tkiv" {
  source                = "../tikv"
  domain                = local.domain
  subnets_ids           = local.tikvSubnets
  vpc_id                = aws_vpc.vpc.id
  zone_id               = var.web_zone_id
  cluster_name          = local.cluster_id
  is_cluster_public     = local.is_cluster_public
  tkiv_data_node_number = var.tkiv_data_node_number
  tkiv_pd_node_number   = 3

  depends_on = [aws_subnet.public]
}

module "redis" {
  source        = "../redis"
  env           = var.env
  redis_version = var.redis_version
  region        = var.region
  shard_conf    = var.shard_conf
  subnets       = aws_subnet.public
  vpc_id        = aws_vpc.vpc.id

  depends_on = [aws_subnet.public]
}

module "jobs" {
  source            = "../jobs"
  env               = var.env
  network           = var.network
  nomad             = module.nomad
  region            = var.region
  boot_nodes        = var.boot_nodes
  is_cluster_public = local.is_cluster_public
  dns_zone          = local.rootDomain
  shard_config = [
    for k, bd in var.shard_conf : {
      shard_wss_endpoint           = "ws${bd.shard_number}.${local.domain}"
      shard_http_endpoint          = "api${bd.shard_number}.${local.domain}"
      shard_number                 = bd.shard_number
      num_writers                  = bd.num_writers
      min_num_readers              = bd.min_num_readers
      redis_addr                   = "${module.redis.shard_addresses[bd.shard_number]}:${module.redis.shard_ports[bd.shard_number]}"
      tkiv_pd_addrs                = module.tkiv.tkiv_pd_urls
      other_supported_domains_http = bd.other_supported_domains_http
      other_supported_domains_wss  = bd.other_supported_domains_wss
    }
  ]

  depends_on         = [module.redis]
  dns_init_port      = local.dnsInitPort
  p2p_init_port      = local.p2pInitPort
  explorer_init_port = local.explorerInitPort
}