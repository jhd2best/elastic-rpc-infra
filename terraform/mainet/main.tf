terraform {
  backend "s3" {
    region = "us-west-2"
    bucket = "tf-harmony"
    key    = "elastic-rpc/mainnet/global" # change this if new env launched
  }
}

provider "aws" {
  region = "us-west-2"
  default_tags {
    tags = {
      Environment = "Mainnet" # change this if new region or env launched
      Region      = "Global"  # change this if new region or env launched
      Owner       = "DevOps Guild"
      Project     = "elastic-rpc-infra"
      Repo        = "github.com/harmony-one/elastic-rpc-infra"
      Terraformed = true
    }
  }
}

locals {
  regions = ["us", "eu"] // Add here the region if a new one is launched
  domain  = "t.hmny.io"

  regions_to_aws = { for region in local.regions : region => data.terraform_remote_state.this[region].outputs.region }
  global_elbs = merge(flatten([for region in local.regions : {
    for shard, elb in data.terraform_remote_state.this[region].outputs.elastic.nomad.elb_dns_names :
    "${region}-${shard}" => elb
    }
  ])...)
}

data "terraform_remote_state" "this" {
  for_each = { for i in local.regions : i => i }
  backend  = "s3"

  config = {
    region = "us-west-2"
    bucket = "tf-harmony"
    key    = "elastic-rpc/mainnet/${each.value}"
  }
}

data "aws_route53_zone" "this" {
  name = local.domain
}

