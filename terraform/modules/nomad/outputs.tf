output "consul_master_token" {
  value = random_uuid.consul_master_token.result
}

output "nomad_master_token" {
  value = data.http.nomad_token.body
}

output "nomad_addr" {
  value = "https://nomad.${local.domain}"
}

output "consul_addr" {
  value = "https://consul.${local.domain}"
}

output "elb_dns_names" {
  value = {
    for num, lb in aws_lb.lb : num => lb.dns_name
  }
}

output "cluster_groups" {
  value = var.cluster_groups
}

output "autoscaling_groups" {
  value = { for k, v in aws_autoscaling_group.group : k => { name = v.name } }
}
