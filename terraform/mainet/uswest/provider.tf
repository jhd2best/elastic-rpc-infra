provider "aws" {
  region = local.region
  default_tags {
    tags = {
      Environment = "Mainet"
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
  address = module.elastic.nomad.nomad_addr
  secret_id = module.elastic.nomad.nomad_master_token
}
