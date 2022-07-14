output "consul_master_token" {
  value = random_uuid.consul_master_token.result
}

output "nomad_master_token" {
  value = data.http.nomad_token.body
}

output "elb_zone_id" {
  value = aws_lb.lb.zone_id
}

output "nomad_addr" {
  value = "https://nomad.${local.domain}"
}

output "consul_addr" {
  value = "https://consul.${local.domain}"
}

output "elb_dns_name" {
  value = aws_lb.lb.dns_name
}

output "elb_listener_arn" {
  value = aws_lb_listener.https.arn
}

output "elb_fabio_arn" {
  value = aws_lb_target_group.fabio_apps.arn
}

output "cluster_groups" {
  value = var.cluster_groups
}

output "autoscaling_groups" {
  value = { for k, v in aws_autoscaling_group.group : k => { name = v.name } }
}
