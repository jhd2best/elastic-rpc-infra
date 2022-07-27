
resource "aws_route53_record" "domain_pd" {
  zone_id = var.vpc_id
  name    = local.pd_domain
  type    = "A"
  ttl     = "300"
  records = local.pd_private_ips

  depends_on = [aws_instance.pd_tiup, aws_instance.pd_normal]
}
