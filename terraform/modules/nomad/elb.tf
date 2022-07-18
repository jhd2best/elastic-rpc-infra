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
  name               = "${var.cluster_id}-elb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.elb.id, local.default_security_group_id]
  subnets            = local.subnet_ids
}

// default listeners

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.lb.arn
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
  load_balancer_arn = aws_lb.lb.arn
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
