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

  fabio_apps = merge({
  }, var.fabio_apps)
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

resource "aws_lb_listener_rule" "app" {
  for_each     = local.apps
  listener_arn = aws_lb_listener.https.arn
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

resource "aws_route53_record" "app" {
  for_each = local.apps
  zone_id  = local.zone_id
  name     = "${each.key}.${local.domain}"
  type     = "A"
  alias {
    zone_id                = aws_lb.lb.zone_id
    name                   = aws_lb.lb.dns_name
    evaluate_target_health = false
  }
}

// register all instances in a target group so that can be
// used by fabio and exposed for the load balancer

resource "aws_lb_target_group" "fabio_apps" {
  name                 = "${var.cluster_id}-fabio-apps"
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
  name                 = "${var.cluster_id}-fabio-grpc"
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
  for_each               = { for g in var.cluster_groups : g.id => g if g.id != "server" }
  autoscaling_group_name = aws_autoscaling_group.group[each.key].id
  lb_target_group_arn    = aws_lb_target_group.fabio_apps.arn
}

resource "aws_autoscaling_attachment" "fabio_grpc" {
  for_each               = { for g in var.cluster_groups : g.id => g if g.id != "server" }
  autoscaling_group_name = aws_autoscaling_group.group[each.key].id
  lb_target_group_arn    = aws_lb_target_group.fabio_grpc.arn
}

resource "aws_lb_listener_rule" "fabio_apps_subdomain" {
  for_each     = { for id, app in local.fabio_apps : id => app if try(app.subdomain, "") != "" }
  listener_arn = aws_lb_listener.https.arn
  action {
    type             = "forward"
    target_group_arn = try(each.value.grpc, false) ? aws_lb_target_group.fabio_grpc.arn : aws_lb_target_group.fabio_apps.arn
  }
  condition {
    host_header {
      values = [try(each.value.subdomain, "") != "" ? "${each.value.subdomain}.${local.domain}" : local.domain]
    }
  }
}

// catch all apps at, e.g. example.com/myapp
resource "aws_lb_listener_rule" "fabio_apps_root" {
  listener_arn = aws_lb_listener.https.arn
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fabio_apps.arn
  }
  condition {
    host_header {
      values = [local.domain]
    }
  }
}

// additional subdomain to catch all aps, e.g. lb.example.com/myapp
resource "aws_lb_listener_rule" "fabio_apps_lb" {
  listener_arn = aws_lb_listener.https.arn
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fabio_apps.arn
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
    zone_id                = aws_lb.lb.zone_id
    name                   = aws_lb.lb.dns_name
    evaluate_target_health = false
  }
}

// create DNS record for all custom fabio app subdomains, e.g. myapp.example.com
resource "aws_route53_record" "fabio_apps" {
  for_each = { for id, app in local.fabio_apps : id => app if try(app.subdomain, "") != "" }
  zone_id  = local.zone_id
  name     = "${each.key}.${local.domain}"
  type     = "A"
  alias {
    zone_id                = aws_lb.lb.zone_id
    name                   = aws_lb.lb.dns_name
    evaluate_target_health = false
  }
}

