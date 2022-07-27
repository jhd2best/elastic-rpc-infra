resource "aws_security_group" "tikv_nodes" {
  name   = "${var.cluster_name}-tikv-nodes"
  vpc_id = var.vpc_id

  tags = {
    Name = "${var.cluster_name}-tikv--nodes"
  }

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = [var.manager_cidr_block]
  }

  // Grafana dashboard
  ingress {
    protocol    = "tcp"
    from_port   = 3000
    to_port     = 3000
    cidr_blocks = [var.manager_cidr_block]
  }

  ingress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "open_tikv" {
  count = var.is_cluster_public ? 1 : 0

  type              = "ingress"
  from_port         = 2379
  to_port           = 2379
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.tikv_nodes.id
}

