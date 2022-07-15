locals {
  region    = "us"
  env       = "mainet"
  domain    = "t.hmny.io"
  vpc_index = 51
}

data "aws_route53_zone" "root" {
  name = local.domain
}

module "elastic" {
  source      = "../../modules/elastic"
  domain      = local.domain
  env         = local.env
  region      = local.region
  vpc_index   = local.vpc_index
  web_zone_id = data.aws_route53_zone.root.id
}

module "jobs" {
  source = "../../modules/jobs"
  domain = local.domain
  env    = local.env
  nomad  = module.elastic.nomad
  region = local.region
}
