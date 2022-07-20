output "aws_region" {
  value = var.region
}

output "vpc" {
  value = data.aws_vpc.vpc
}

output "nomad" {
  value = module.nomad
}