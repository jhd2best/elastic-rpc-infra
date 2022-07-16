locals {
  region     = "us"
  aws_region = "us-west-1"
  env        = "mainet"
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
  redis_version = "redis6.2"
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

module "jobs" {
  source = "../../modules/jobs"
  domain = local.domain
  env    = local.env
  nomad  = module.elastic.nomad
  region = local.region
}
