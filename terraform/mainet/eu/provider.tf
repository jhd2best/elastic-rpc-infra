provider "aws" {
  region = local.aws_region
  default_tags {
    tags = {
      Environment = "Mainet" # change this if new region or env launched
      Region      = "Europe" # change this if new region or env launched
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
