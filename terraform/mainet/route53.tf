resource "aws_route53_record" "regions_api" {
  for_each = local.global_elbs
  zone_id  = data.aws_route53_zone.this.zone_id
  name     = "api.erpc-${split("-", each.key)[0]}.s${split("-", each.key)[1]}.${local.domain}"
  type     = "CNAME"
  ttl      = 300
  records  = [each.value]
}

resource "aws_route53_record" "regions_ws" {
  for_each = local.global_elbs
  zone_id  = data.aws_route53_zone.this.zone_id
  name     = "ws.erpc-${split("-", each.key)[0]}.s${split("-", each.key)[1]}.${local.domain}"
  type     = "CNAME"
  ttl      = 300
  records  = [each.value]
}

resource "aws_route53_record" "global_api" {
  for_each = local.global_elbs
  zone_id  = data.aws_route53_zone.this.zone_id
  name     = "api.erpc.s${split("-", each.key)[1]}.${local.domain}"
  type     = "CNAME"
  ttl      = 300
  records  = ["api.erpc-${split("-", each.key)[0]}.s${split("-", each.key)[1]}.${local.domain}"]

  set_identifier = "api-${split("-", each.key)[0]}.s${split("-", each.key)[1]}"

  latency_routing_policy {
    region = local.regions_to_aws[split("-", each.key)[0]]
  }
}

resource "aws_route53_record" "global_ws" {
  for_each = local.global_elbs
  zone_id  = data.aws_route53_zone.this.zone_id
  name     = "ws.erpc.s${split("-", each.key)[1]}.${local.domain}"
  type     = "CNAME"
  ttl      = 300
  records  = ["ws.erpc-${split("-", each.key)[0]}.s${split("-", each.key)[1]}.${local.domain}"]

  set_identifier = "ws-${split("-", each.key)[0]}.s${split("-", each.key)[1]}"

  latency_routing_policy {
    region = local.regions_to_aws[split("-", each.key)[0]]
  }
}