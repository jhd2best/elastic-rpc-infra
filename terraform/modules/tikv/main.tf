terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

data "aws_route53_zone" "selected" {
  name         = "${var.domain}"
  private_zone = true
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners = ["099720109477"] // const

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

// check vpc exist
data "aws_vpc" "selected" {
  id = var.vpc_id
}

// check subnet exist
data "aws_subnet" "selected" {
  vpc_id = data.aws_vpc.selected.id
  availability_zone = var.availability_zone
}

resource "aws_security_group" "tikv_nodes" {
  name   = "${var.cluster_name}-nodes"
  vpc_id = var.vpc_id

  tags = {
    Name = "${var.cluster_name}-nodes"
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
    cidr_blocks = ["172.31.0.0/16"]
  }

  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
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

resource "aws_instance" "pd_tiup" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.tikv_pd_node_instance_type
  availability_zone = var.availability_zone
  subnet_id     = data.aws_subnet.selected.id // make sure all nodes are created in same subnet
  key_name      = var.key_name
  security_groups = [aws_security_group.tikv_nodes.id]

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 80
    delete_on_termination = true
  }

  tags = {
    Name = "tikv-pd-1"
  }

  connection {
    host        = "${self.public_ip}"
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.private_key_path)
    agent       = false
  }

  provisioner "file" {
    content = <<EOF
      ${templatefile("${path.module}/files/init-pd.sh.tftpl", {
          public_key = "${file(var.public_key_path)}",
      })}
    EOF
    destination = "/home/ubuntu/init.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/init.sh && sudo /home/ubuntu/init.sh",
      "curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh",
      "export PATH=/home/ubuntu/.tiup/bin:$PATH",
      "tiup cluster",
      "tiup --binary cluster",
    ]
  }
}

resource "aws_eip" "pd_tiup" {
  instance = aws_instance.pd_tiup.id
  vpc      = true

  depends_on = [ aws_instance.pd_tiup ]
}

resource "aws_instance" "pd_normal" {
  count = var.tkiv_pd_node_number > 1 ? var.tkiv_pd_node_number - 1 : 0

  ami           = data.aws_ami.ubuntu.id
  instance_type = var.tikv_pd_node_instance_type
  availability_zone = var.availability_zone
  subnet_id     = data.aws_subnet.selected.id
  key_name      = var.key_name
  security_groups = [aws_security_group.tikv_nodes.id]

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 40
    delete_on_termination = true
  }

  tags = {
    Name = "tikv-pd-${count.index + 2}"
  }

  connection {
    host        = "${self.public_ip}"
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.private_key_path)
    agent       = false
  }

  provisioner "file" {
    content = <<EOF
      ${templatefile("${path.module}/files/init-pd.sh.tftpl", {
          public_key = "${file(var.public_key_path)}",
      })}
    EOF
    destination = "/home/ubuntu/init.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/init.sh && sudo /home/ubuntu/init.sh",
    ]
  }

  depends_on = [ aws_instance.pd_tiup ]
}

resource "aws_instance" "data_normal" {
  count = var.tkiv_data_node_number

  ami           = data.aws_ami.ubuntu.id
  instance_type = var.tikv_data_node_instance_type
  availability_zone = var.availability_zone
  subnet_id     = data.aws_subnet.selected.id
  key_name      = var.key_name
  security_groups = [aws_security_group.tikv_nodes.id]

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 40
    delete_on_termination = true
  }

  tags = {
    Name = "tikv-data-${count.index + 1}"
  }

  connection {
    host        = "${self.public_ip}"
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.private_key_path)
    agent       = false
  }

  provisioner "file" {
    content = <<EOF
      ${templatefile("${path.module}/files/init-data.sh.tftpl", {
          public_key = "${file(var.public_key_path)}",
      })}
    EOF
    destination = "/home/ubuntu/init.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/init.sh && sudo /home/ubuntu/init.sh",
    ]
  }

  depends_on = [ aws_instance.pd_tiup ]
}

locals {
  pd_tiup_public_ip = aws_eip.pd_tiup.public_ip
  pd_tiup_private_ip = aws_instance.pd_tiup.private_ip
  pd_private_ips     = concat(aws_instance.pd_tiup.*.private_ip, aws_instance.pd_normal.*.private_ip)
  data_private_ips   = aws_instance.data_normal.*.private_ip
}

resource "null_resource" "launch_tikv" {
  count = 1

  connection {
    host        = local.pd_tiup_public_ip
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.private_key_path)
    agent       = false
  }

  provisioner "file" {
    source      = var.private_key_path
    destination = "/home/ubuntu/.ssh/id_rsa"
  }

  provisioner "file" {
    content = <<EOF
${templatefile("${path.module}/files/topology.yaml.tftpl", {
  pd_tiup_private_ip = local.pd_tiup_private_ip,
  pd_private_ips = local.pd_private_ips,
  data_private_ips = local.data_private_ips,
  replicas_count = var.tkiv_replication_factor,
})}
    EOF
    destination = "/home/ubuntu/topology.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "export PATH=/home/ubuntu/.tiup/bin:$PATH",
      "tiup cluster check ./topology.yaml --apply --user tikv",
      "tiup cluster deploy ${var.cluster_name} ${var.cluster_version} ./topology.yaml --user tikv -y",
      "tiup cluster start ${var.cluster_name}",
      "sleep 10",
      "tiup cluster display ${var.cluster_name}",
    ]
  }

  depends_on = [ aws_instance.pd_tiup, aws_instance.pd_normal, aws_instance.data_normal ]
}

resource "aws_route53_record" "domain_pd" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "pd.${data.aws_route53_zone.selected.name}"
  type    = "A"
  ttl     = "300"
  records = local.pd_private_ips

  depends_on = [ aws_instance.pd_tiup, aws_instance.pd_normal ]
}
