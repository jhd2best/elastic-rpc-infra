resource "aws_route53_record" "domain_pd" {
  zone_id = var.zone_id
  name    = local.pd_domain
  type    = "A"
  ttl     = 60
  records = var.is_cluster_public ? local.pd_public_ips : local.pd_private_ips

  depends_on = [aws_instance.pd_tiup, aws_instance.pd_normal]
}

resource "aws_route53_record" "tui_pd" {
  zone_id = var.zone_id
  name    = local.tiup_domain
  type    = "A"
  ttl     = 60
  records = [var.is_cluster_public ? aws_instance.pd_tiup.public_ip : aws_instance.pd_tiup.private_ip]

  depends_on = [aws_instance.pd_tiup]
}

resource "aws_route53_record" "domain_pds" {
  for_each = local.pd_domains
  zone_id  = var.zone_id
  name     = each.key
  type     = "A"
  ttl      = 60
  records  = [var.is_cluster_public ? each.value.public_ip : each.value.private_ip]

  depends_on = [aws_instance.pd_tiup, aws_instance.pd_normal]
}


resource "aws_route53_record" "domain_data" {
  for_each = local.data_domains
  zone_id  = var.zone_id
  name     = each.key
  type     = "A"
  ttl      = 60
  records  = [var.is_cluster_public ? each.value.public_ip : each.value.private_ip]

  depends_on = [aws_instance.data_normal]
}
