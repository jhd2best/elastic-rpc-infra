# setup the load balancer listeners for all the
# services running in the cluster

locals {
  apps = {
    consul = {
      port           = 8500
      health_path    = "/v1/status/leader"
      health_port    = 8500
      cluster_groups = ["server"]
    }
    nomad = {
      port           = 4646
      health_path    = "/v1/agent/health"
      health_port    = 4646
      cluster_groups = ["server"]
    }
    fabio = {
      port           = 9998
      health_path    = "/health"
      health_port    = 9998
      cluster_groups = [for g in var.cluster_groups : g.id if g.id != "server"]
    }
  }

  fabio_shard = concat([], var.fabio_shard)

  cluster_clients_shard = flatten([
    for pk, shard in local.fabio_shard : [
      for g in var.cluster_groups : {
        shard_number = shard.shard_number
        group        = g.id
      } if g.id != "server"
    ]
  ])

  other_domains_per_shard = {
    for num, domains in
    { for id, app in local.fabio_shard : app.shard_number => app.other_supported_domains... } :
    num => flatten(domains)
  }

  other_domains_by_shard = flatten([
    for num, domains in local.other_domains_per_shard : [
      for domain in domains : {
        domain       = domain
        shard_number = num
      }
    ]
  ])
}

resource "aws_lb_target_group" "app" {
  for_each             = local.apps
  name                 = "${var.cluster_id}-${each.key}"
  port                 = each.value.port
  protocol             = "HTTP"
  vpc_id               = local.vpc_id
  deregistration_delay = 1
  health_check {
    path                = each.value.health_path
    port                = each.value.health_port
    interval            = 5
    unhealthy_threshold = 2
    timeout             = 3
  }
  tags = {
    Project = var.project
    Env     = var.env
  }
}

resource "aws_autoscaling_attachment" "app" {
  for_each = {
    for x in flatten(concat([
      for id, app in local.apps : [
        for g in app.cluster_groups : "${id}@${g}"
      ]
    ])) : x => x
  }
  autoscaling_group_name = aws_autoscaling_group.group[split("@", each.key)[1]].id
  lb_target_group_arn    = aws_lb_target_group.app[split("@", each.key)[0]].arn
}

// This is for the global apps so we use the first loadbalancer in the list
resource "aws_lb_listener_rule" "global_app" {
  for_each     = local.apps
  listener_arn = aws_lb_listener.https[0].arn
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app[each.key].arn
  }
  condition {
    host_header {
      values = ["${each.key}.${local.domain}"]
    }
  }
}

// This is for the global apps so we use the first loadbalancer in the list
resource "aws_route53_record" "global_app" {
  for_each = local.apps
  zone_id  = local.zone_id
  name     = "${each.key}.${local.domain}"
  type     = "A"
  alias {
    zone_id                = aws_lb.lb[0].zone_id
    name                   = aws_lb.lb[0].dns_name
    evaluate_target_health = false
  }
}

// register all instances in a target group so that can be
// used by fabio and exposed for the load balancer

resource "aws_lb_target_group" "fabio_apps" {
  for_each             = { for id, app in local.fabio_shard : app.shard_number => app.shard_number... }
  name                 = "${var.cluster_id}-s${each.key}-fabio-apps"
  port                 = 9999
  protocol             = "HTTP"
  vpc_id               = local.vpc_id
  deregistration_delay = 1
  health_check {
    path                = "/health"
    port                = 9998
    interval            = 5
    unhealthy_threshold = 2
    timeout             = 3
  }
  tags = {
    project = var.project
    env     = var.env
  }
}

resource "aws_lb_target_group" "fabio_grpc" {
  for_each             = { for id, app in local.fabio_shard : app.shard_number => app.shard_number... }
  name                 = "${var.cluster_id}-s${each.key}-fabio-grpc"
  port                 = 9997
  protocol             = "HTTP"
  protocol_version     = "GRPC"
  vpc_id               = local.vpc_id
  deregistration_delay = 1
  health_check {
    path                = "/"
    port                = 9997
    interval            = 5
    unhealthy_threshold = 2
    timeout             = 3
    matcher             = "0-99"
  }
  tags = {
    project = var.project
    env     = var.env
  }
}

resource "aws_autoscaling_attachment" "fabio_apps" {
  for_each               = { for g in local.cluster_clients_shard : "${g.shard_number}:${g.group}" => g... }
  autoscaling_group_name = aws_autoscaling_group.group[each.value[0].group].id
  lb_target_group_arn    = aws_lb_target_group.fabio_apps[each.value[0].shard_number].arn
}

resource "aws_autoscaling_attachment" "fabio_grpc" {
  for_each               = { for g in local.cluster_clients_shard : "${g.shard_number}:${g.group}" => g... }
  autoscaling_group_name = aws_autoscaling_group.group[each.value[0].group].id
  lb_target_group_arn    = aws_lb_target_group.fabio_grpc[each.value[0].shard_number].arn
}

// catch all apps at, e.g. s0.example.com/myapp
resource "aws_lb_listener_rule" "fabio_apps_root" {
  for_each     = { for id, app in local.fabio_shard : app.shard_number => app.shard_number... }
  listener_arn = aws_lb_listener.https[each.key].arn
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fabio_apps[each.key].arn
  }
  condition {
    host_header {
      values = ["s${each.key}.${local.domain}"]
    }
  }
}

// additional subdomain to catch all aps, e.g. lb.example.com/myapp
resource "aws_lb_listener_rule" "fabio_apps_lb" {
  listener_arn = aws_lb_listener.https[0].arn
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fabio_apps[0].arn
  }
  condition {
    host_header {
      values = ["lb.${local.domain}"]
    }
  }
}

resource "aws_route53_record" "fabio_apps_lb" {
  zone_id = local.zone_id
  name    = "lb.${local.domain}"
  type    = "A"
  alias {
    zone_id                = aws_lb.lb[0].zone_id
    name                   = aws_lb.lb[0].dns_name
    evaluate_target_health = false
  }
}

// create DNS record for all custom fabio shards subdomains, e.g. api.s0.example.com
resource "aws_route53_record" "fabio_shard" {
  for_each = { for id, app in local.fabio_shard : id => app }
  zone_id  = local.zone_id
  name     = "${each.value.subdomain}${each.value.shard_number}.${local.domain}"
  type     = "A"
  alias {
    zone_id                = aws_lb.lb[each.value.shard_number].zone_id
    name                   = aws_lb.lb[each.value.shard_number].dns_name
    evaluate_target_health = false
  }
}

resource "aws_lb_listener_rule" "fabio_apps_subdomain" {
  for_each     = { for id, app in local.fabio_shard : "${app.shard_number}:${app.subdomain}" => app }
  listener_arn = aws_lb_listener.https[each.value.shard_number].arn
  action {
    type             = "forward"
    target_group_arn = try(each.value.grpc, false) ? aws_lb_target_group.fabio_grpc[each.value.shard_number].arn : aws_lb_target_group.fabio_apps[each.value.shard_number].arn
  }
  condition {
    host_header {
      values = ["${each.value.subdomain}${each.value.shard_number}.${local.domain}"]
    }
  }
}

resource "aws_lb_listener_rule" "fabio_apps_other_domains" {
  for_each     = { for app in local.other_domains_by_shard : "${app.shard_number}:${app.domain}" => app... }
  listener_arn = aws_lb_listener.https[each.value[0].shard_number].arn
  action {
    type             = "forward"
    target_group_arn = try(each.value[0].grpc, false) ? aws_lb_target_group.fabio_grpc[each.value[0].shard_number].arn : aws_lb_target_group.fabio_apps[each.value[0].shard_number].arn
  }
  condition {
    host_header {
      values = [each.value[0].domain]
    }
  }
}
