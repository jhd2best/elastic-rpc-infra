output "vpc" {
  value = aws_vpc.vpc
}

output "nomad" {
  value = module.nomad
}

output "tikv" {
  value = module.tkiv
}