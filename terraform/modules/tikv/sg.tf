resource "aws_security_group" "tikv_nodes" {
  name   = "${var.cluster_name}-tikv-nodes"
  vpc_id = var.vpc_id

  tags = {
    Name = "${var.cluster_name}-tikv--nodes"
  }

  // Grafana dashboard
  ingress {
    protocol    = "tcp"
    from_port   = 3000
    to_port     = 3000
    cidr_blocks = [var.manager_cidr_block]
  }

  ingress {
    from_port   = 2379
    to_port     = 2379
    protocol    = "tcp"
    cidr_blocks = [var.is_cluster_public ? "0.0.0.0/0" : data.aws_vpc.selected.cidr_block]
  }

  ingress {
    from_port   = 2380
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = [var.is_cluster_public ? "0.0.0.0/0" : data.aws_vpc.selected.cidr_block]
  }

  ingress {
    from_port   = 20160
    to_port     = 20160
    protocol    = "tcp"
    cidr_blocks = [var.is_cluster_public ? "0.0.0.0/0" : data.aws_vpc.selected.cidr_block]
  }

  ingress {
    from_port   = 20180
    to_port     = 20180
    protocol    = "tcp"
    cidr_blocks = [var.is_cluster_public ? "0.0.0.0/0" : data.aws_vpc.selected.cidr_block]
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