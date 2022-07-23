# setup the load balancer

resource "aws_security_group" "elb" {
  name   = "${var.cluster_id}-elb"
  vpc_id = local.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

// the load balancer

resource "aws_lb" "lb" {
  for_each           = { for id, app in local.fabio_shard : app.shard_number => app.shard_number... }
  name               = "${var.cluster_id}-s${each.key}-elb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.elb.id, local.default_security_group_id]
  subnets            = local.subnet_ids
}

// default listeners

resource "aws_lb_listener" "http" {
  for_each          = { for id, app in local.fabio_shard : app.shard_number => app.shard_number... }
  load_balancer_arn = aws_lb.lb[each.key].arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  for_each          = { for id, app in local.fabio_shard : app.shard_number => app.shard_number... }
  load_balancer_arn = aws_lb.lb[each.key].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.domain.arn
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = ""
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener_certificate" "external" {
  for_each = { for idx, app in local.external_cert_per_lb : "${app.shard_number}:${app.domain}" => app... }

  listener_arn    = each.value[0].listener_arn
  certificate_arn = each.value[0].certificate_arn

  depends_on = [data.aws_acm_certificate.external_certs, aws_lb_listener.https]
}

resource "aws_lb_listener_certificate" "internal" {
  for_each = { for idx, app in local.internal_cert_per_lb : "${app.shard_number}:${app.domain}" => app... }

  listener_arn    = each.value[0].listener_arn
  certificate_arn = each.value[0].certificate_arn

  depends_on = [aws_acm_certificate_validation.validate_internal, aws_lb_listener.https]
}
