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
  domain                    = "${var.env}.${var.domain}"
  zone_id                   = var.zone_id
  vpc_id                    = var.vpc.id
  subnet_ids                = var.public_subnet_ids
  default_security_group_id = data.aws_security_group.default.id
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
