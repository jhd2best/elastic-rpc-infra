# this module sets up a nomad/consul cluster in a dedicated VPC
# and behind a load balancer

terraform {
  required_providers {
    aws = {}
  }
}

data "aws_ssm_parameter" "image_id" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

data "aws_security_group" "default" {
  vpc_id = var.vpc.id
  name   = "default"
}

locals {
  image_id                  = data.aws_ssm_parameter.image_id.value
  domain                    = var.domain
  zone_id                   = var.zone_id
  vpc_id                    = var.vpc.id
  subnet_ids                = var.public_subnet_ids
  default_security_group_id = data.aws_security_group.default.id

  external_domains = [for domain in flatten([for app in local.fabio_shard : app.other_supported_domains]) : domain if split(var.rootDomain, domain)[0] == domain]
  internal_domains = [for domain in flatten([for app in local.fabio_shard : app.other_supported_domains]) : domain if split(var.rootDomain, domain)[0] != domain]

  external_cert_per_lb = flatten([
    for pk, shard in local.fabio_shard : [
      for nk, domain in local.external_domains : {
        shard_number    = shard.shard_number
        domain          = domain
        listener_arn    = aws_lb_listener.https[shard.shard_number].arn
        certificate_arn = data.aws_acm_certificate.external_certs[domain].arn
      } if contains(shard.other_supported_domains, domain)
    ]
  ])

  internal_cert_per_lb = flatten([
    for pk, shard in local.fabio_shard : [
      for dix, domain in local.internal_domains : {
        shard_number    = shard.shard_number
        domain          = domain
        listener_arn    = aws_lb_listener.https[shard.shard_number].arn
        certificate_arn = aws_acm_certificate.internal_certs[domain].arn
      } if contains(shard.other_supported_domains, domain)
    ]
  ])

  internal_dvo = flatten([for record in aws_acm_certificate.internal_certs : record.domain_validation_options])
}

resource "null_resource" "wait_for_nomad" {
  provisioner "local-exec" {
    command     = "${path.module}/scripts/wait_for_nomad.sh https://consul.${local.domain} ${random_uuid.consul_master_token.result}"
    interpreter = ["bash", "-c"]
    working_dir = path.root
  }
  # program = ["bash", "-c", "${path.module}/scripts/wait_for_nomad.sh"]
  # query = {
  #     addr = "https://consul.${local.domain}"
  #     token = random_uuid.consul_master_token.result
  # }
  depends_on = [aws_autoscaling_group.group]
}

data "http" "nomad_token" {
  url = "https://consul.${local.domain}/v1/kv/nomad/tokens/master?raw"
  request_headers = {
    X-Consul-Token = random_uuid.consul_master_token.result
  }
  depends_on = [null_resource.wait_for_nomad]
}

resource "random_uuid" "consul_master_token" {}
resource "random_uuid" "consul_agent_token" {}
resource "random_uuid" "consul_anon_token" {}
