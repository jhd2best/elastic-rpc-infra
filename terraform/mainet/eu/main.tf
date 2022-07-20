terraform {
  backend "s3" {
    region = "us-west-2"
    bucket = "tf-harmony"
    key    = "elastic-rpc/mainnet/eu" # change this if new region or env launched
  }
}


locals {
  region     = "eu"                           # change this if new region or env launched
  aws_region = "eu-central-1"                 # change this if new region or env launched
  env        = "main"                         # change this if new region or env launched # this is used for namespacing so it can be a short version
  network    = "mainnet"                      # change this if new region or env launched # this is used for node configuration
  boot_nodes = "/dnsaddr/bootstrap.t.hmny.io" # change this if new region or env launched
  domain     = "t.hmny.io"
  vpc_index  = 51
}

provider "aws" {
  region = local.aws_region
  default_tags {
    tags = {
      Environment = "Mainnet" # change this if new region or env launched
      Region      = "Europe"  # change this if new region or env launched
      Owner       = "DevOps Guild"
      Project     = "elastic-rpc-infra"
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
  source        = "../../modules/elastic"
  domain        = local.domain
  env           = local.env
  network       = local.network
  boot_nodes    = local.boot_nodes
  region        = local.region
  vpc_index     = local.vpc_index
  web_zone_id   = data.aws_route53_zone.root.id
  redis_version = "redis6.x"
  shard_conf = [{
    shard_number                  = 0
    redis_shards                  = 2
    redis_replicas_per_node_group = 1
    redis_instance_type           = "cache.r6g.large"
    },
    {
      shard_number                  = 1
      redis_shards                  = 1
      redis_replicas_per_node_group = 1
      redis_instance_type           = "cache.r6g.large"
  }]
}

output "elastic" {
  value     = module.elastic
  sensitive = true
}