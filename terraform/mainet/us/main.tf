terraform {
  backend "s3" {
    region = "us-west-2"
    bucket = "tf-harmony"
    key    = "elastic-rpc/mainnet/us" # change this if new region or env launched
  }
}


locals {
  region           = "us"                           # change this if new region launched
  aws_region       = "us-west-2"                    # change this if new region launched
  env              = "main"                         # change this if new env launched # this is used for namespacing so it can be a short version
  network          = "mainnet"                      # change this if new env launched # this is used for node configuration
  boot_nodes       = "/dnsaddr/bootstrap.t.hmny.io" # change this if new env launched
  domain           = "t.hmny.io"                    # hosting zone also used as dnszone change this if new env used
  vpc_index        = 52                             # used to namespace the vpc cdir number, in the case when having multiple clusters in different regions all of them will have a different cidr block
  tkiv_node_number = 13                             # number of nodes for the tkiv cluster to launch
}

provider "aws" {
  region = local.aws_region
  default_tags {
    tags = {
      Environment = "Mainnet"   # change this if new region or env launched
      Region      = "US Oregon" # change this if new region or env launched
      Owner       = "DevOps Guild"
      Project     = "elastic-rpc-infra"
      Repo        = "github.com/harmony-one/elastic-rpc-infra"
      Terraformed = true
    }
  }
}

provider "consul" {
  address = module.elastic.nomad.consul_addr
  token   = module.elastic.nomad.consul_master_token
}

provider "nomad" {
  address   = module.elastic.nomad.nomad_addr
  secret_id = module.elastic.nomad.nomad_master_token
}

data "aws_route53_zone" "root" {
  name = local.domain
}

module "elastic" {
  source                = "../../modules/elastic"
  domain                = local.domain
  env                   = local.env
  network               = local.network
  boot_nodes            = local.boot_nodes
  region                = local.region
  vpc_index             = local.vpc_index
  web_zone_id           = data.aws_route53_zone.root.id
  tkiv_data_node_number = local.tkiv_node_number
  redis_version         = "redis6.x"
  shard_conf = [{
    shard_number             = 0
    redis_shards             = 2
    redis_replicas_per_shard = 1
    redis_instance_type      = "cache.r6g.4xlarge"
    num_writers              = 2
    min_num_readers          = 1
    other_supported_domains_http = [
      #      "api.harmony.one",
      #      "a.api.s0.t.hmny.io",
      #      "curve.s0.t.hmny.io",
      #      "sushi-archival.s0.t.hmny.io",
      #      "api.s0.t.hmny.io",
      #      "rpc.s0.t.hmny.io",
      #      "thegraph.s0.t.hmny.io",
      #      "bridge.api.s0.t.hmny.io",
      #      "rosetta.s0.t.hmny.io",
      #      "btc.api.s0.t.hmny.io",
      #      "partners.s0.t.hmny.io",
    ]
    other_supported_domains_wss = [
      #      "wss.internal.s0.t.hmny.io",
      #      "ws.internal.s0.t.hmny.io",
      #      "ws.s0.t.hmny.io",
      #      "a.ws.s0.t.hmny.io",
    ]
    },
  ]
}

output "elastic" {
  value     = module.elastic
  sensitive = true
}