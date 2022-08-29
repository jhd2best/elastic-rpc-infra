data "aws_key_pair" "tikv_node" {
  key_name = "${var.cluster_name}-tikv-node"
  include_public_key = true
}

data "aws_security_group" "tikv_nodes" {
  name   = "${var.cluster_name}-tikv-nodes"
  vpc_id = var.vpc_id
}

data "aws_iam_instance_profile" "smm-role" {
  name = "${var.cluster_name}-smm-role"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] // const

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "template_file" "user_data_normal" {
  template = format("%s", file("${path.module}/files/init-data.sh.tftpl"))
  vars = {
    public_key = trimspace(data.aws_key_pair.tikv_node.public_key),
  }
}

resource "aws_instance" "data_normal" {
  count = var.new_tkiv_data_node_number

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.tikv_data_node_instance_type
  subnet_id              = var.subnets_ids[count.index % length(var.subnets_ids)]
  key_name               = data.aws_key_pair.tikv_node.key_name
  vpc_security_group_ids = [data.aws_security_group.tikv_nodes.id]
  iam_instance_profile   = data.aws_iam_instance_profile.smm-role.name

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 40
    delete_on_termination = true
  }

  tags = {
    Name = "${var.cluster_name}-tikv-data-new-${count.index + 1}"
  }

  user_data = data.template_file.user_data_normal.rendered


  lifecycle {
    ignore_changes = [ami, subnet_id]
  }
}