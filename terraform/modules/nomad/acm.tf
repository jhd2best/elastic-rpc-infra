# setup a wildcard certificate needed for the service endpoints

resource "aws_route53_record" "validate" {
  for_each = {
    for dvo in aws_acm_certificate.domain.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = local.zone_id
}

resource "aws_acm_certificate" "domain" {
  domain_name               = "*.${local.domain}"
  subject_alternative_names = [local.domain]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# this forces Terraform to wait until the validation is complete
resource "aws_acm_certificate_validation" "domain" {
  certificate_arn         = aws_acm_certificate.domain.arn
  validation_record_fqdns = [for record in aws_route53_record.validate : record.fqdn]
}

# only import certificates from domains we don't know
data "aws_acm_certificate" "external_certs" {
  for_each = toset(local.external_domains)
  domain   = each.value
}

## only import certificates from domains we don't know
#data "aws_acm_certificate" "internal_certs" {
#  for_each = toset(local.internal_domains)
#  domain   = each.value
#}

# if the domain is within the root domain (hosting zone) then created
resource "aws_acm_certificate" "internal_certs" {
  for_each          = toset(local.internal_domains)
  domain_name       = each.key
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validate_internal" {
  count = length(local.internal_dvo)

  allow_overwrite = true
  name            = local.internal_dvo[count.index].resource_record_name
  records         = [local.internal_dvo[count.index].resource_record_value]
  ttl             = 60
  type            = local.internal_dvo[count.index].resource_record_type
  zone_id         = local.zone_id

  lifecycle {
    ignore_changes = all
  }
}

resource "aws_acm_certificate_validation" "validate_internal" {
  for_each                = toset(local.internal_domains)
  certificate_arn         = aws_acm_certificate.internal_certs[each.key].arn
  validation_record_fqdns = [for record in aws_route53_record.validate_internal : record.fqdn if split(each.key, record.fqdn)[0] != record.fqdn]
}