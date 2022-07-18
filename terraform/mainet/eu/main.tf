locals {
  region     = "eu" # change this if new region or env launched
  aws_region = "eu-central-1" # change this if new region or env launched
  env        = "mainet" # change this if new region or env launched
  domain     = "t.hmny.io"
  vpc_index  = 51
}

data "aws_route53_zone" "root" {
  name = local.domain
}

module "elastic" {
  source        = "../../modules/elastic"
  domain        = local.domain
  env           = local.env
  region        = local.region
  vpc_index     = local.vpc_index
  web_zone_id   = data.aws_route53_zone.root.id
  redis_version = "redis6.x"
  shard_conf = [{
    shard_number                  = 0
    redis_shards                  = 3
    redis_replicas_per_node_group = 2
    redis_instance_type           = "cache.r6g.large"
    },
    {
      shard_number                  = 1
      redis_shards                  = 3
      redis_replicas_per_node_group = 2
      redis_instance_type           = "cache.r6g.large"
  }]
}
