# setup the launch configuration and the autoscaling group
# for the cluster EC2 instances

locals {
  autoscaling_nomad_server_group_name = "${var.cluster_id}-nomad-server" // this has to be the same name as the one created in the aws console
}

data "template_file" "user_data" {
  for_each = { for g in var.cluster_groups : g.id => g }
  template = format("%s%s%s",
    file("${path.module}/scripts/init.sh"),
    file("${path.module}/scripts/install_consul.sh"),
  file("${path.module}/scripts/install_nomad.sh"))
  vars = {
    group_id               = each.key
    datacenter             = "dc1"
    region                 = var.region
    domain                 = var.domain
    cluster_id             = var.cluster_id
    server_nodes           = each.key == "server" ? each.value.instance_count.desired : ""
    autoscaling_group_name = local.autoscaling_nomad_server_group_name
    consul_version         = var.consul_version
    nomad_version          = var.nomad_version
    consul_master_token    = random_uuid.consul_master_token.result
    consul_agent_token     = random_uuid.consul_agent_token.result
    consul_anon_token      = random_uuid.consul_anon_token.result
  }
}

resource "aws_security_group" "ec2" {
  name   = "${var.cluster_id}-ssh"
  vpc_id = local.vpc_id
  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = [var.vpc.cidr_block]
  }
}

resource "aws_security_group" "open" {
  for_each = { for g in var.cluster_groups : g.id => g }
  name     = "${var.cluster_id}-${each.key}-open"
  vpc_id   = local.vpc_id
  dynamic "ingress" {
    for_each = each.value.security_groups
    content {
      protocol    = ingress.value.protocol
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

resource "aws_launch_configuration" "group" {
  for_each                    = { for g in var.cluster_groups : g.id => g }
  name_prefix                 = "${var.cluster_id}-nomad-${each.key}-"
  image_id                    = local.image_id
  instance_type               = each.value.instance_type
  iam_instance_profile        = aws_iam_instance_profile.nomad.name
  user_data                   = data.template_file.user_data[each.key].rendered
  key_name                    = var.ssh_key_name
  associate_public_ip_address = true
  security_groups             = concat([aws_security_group.ec2.id, local.default_security_group_id], [aws_security_group.open[each.key].id])
  # depends_on                  = [aws_iam_role_policy_attachment.nomad]
  root_block_device {
    delete_on_termination = true
  }
  lifecycle {
    create_before_destroy = true
  }
}

data "aws_default_tags" "elastic" {}

resource "aws_autoscaling_group" "group" {
  for_each             = { for g in var.cluster_groups : g.id => g }
  name                 = "${var.cluster_id}-nomad-${each.key}"
  launch_configuration = aws_launch_configuration.group[each.key].name
  desired_capacity     = each.value.instance_count.desired
  max_size             = each.value.instance_count.max
  min_size             = each.value.instance_count.min
  health_check_type    = "ELB"
  vpc_zone_identifier  = local.subnet_ids
  // protect_from_scale_in = true
  // force_delete          = true
  tag {
    key                 = "Name"
    value               = "${var.cluster_id}-${each.value.id}"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = data.aws_default_tags.elastic.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    ignore_changes        = [desired_capacity, load_balancers, target_group_arns]
    create_before_destroy = true
  }
}
