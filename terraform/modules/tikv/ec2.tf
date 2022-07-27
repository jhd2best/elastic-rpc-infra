resource "tls_private_key" "tikv_nodes" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "tikv_node" {
  key_name   = "${var.cluster_name}-tikv-node"
  public_key = trimspace(tls_private_key.tikv_nodes.public_key_openssh)
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

resource "aws_eip" "pd_tiup" {
  instance = aws_instance.pd_tiup.id
  vpc      = true

  depends_on = [aws_instance.pd_tiup]
}

resource "aws_instance" "pd_tiup" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.tikv_pd_node_instance_type
  availability_zone      = var.availability_zone
  subnet_id              = data.aws_subnet.selected.id // make sure all nodes are created in same subnet
  key_name               = aws_key_pair.tikv_node.key_name
  vpc_security_group_ids = [aws_security_group.tikv_nodes.id]
  iam_instance_profile   = aws_iam_instance_profile.smm-role.name

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 80
    delete_on_termination = true
  }

  tags = {
    Name = "${var.cluster_name}-tikv-pd-1"
  }

  connection {
    host        = self.public_ip
    type        = "ssh"
    user        = "ubuntu"
    private_key = trimspace(tls_private_key.tikv_nodes.private_key_pem)
    agent       = false
  }

  provisioner "file" {
    content = templatefile("${path.module}/files/init-pd.sh.tftpl", {
      public_key = trimspace(tls_private_key.tikv_nodes.public_key_openssh),
    })

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

  depends_on = [aws_instance.data_normal, aws_instance.pd_normal]
}

data "template_file" "user_data_pd_normal" {
  template = format("%s", file("${path.module}/files/init-pd.sh.tftpl"))
  vars = {
    public_key = trimspace(tls_private_key.tikv_nodes.public_key_openssh),
  }
}

resource "aws_instance" "pd_normal" {
  count = var.tkiv_pd_node_number > 1 ? var.tkiv_pd_node_number - 1 : 0

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.tikv_pd_node_instance_type
  availability_zone      = var.availability_zone
  subnet_id              = data.aws_subnet.selected.id
  key_name               = aws_key_pair.tikv_node.key_name
  vpc_security_group_ids = [aws_security_group.tikv_nodes.id]
  iam_instance_profile   = aws_iam_instance_profile.smm-role.name

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 40
    delete_on_termination = true
  }

  tags = {
    Name = "${var.cluster_name}-tikv-pd-${count.index + 2}"
  }

  user_data = data.template_file.user_data_pd_normal.rendered
}

data "template_file" "user_data_normal" {
  template = format("%s", file("${path.module}/files/init-data.sh.tftpl"))
  vars = {
    public_key = trimspace(tls_private_key.tikv_nodes.public_key_openssh),
  }
}

resource "aws_instance" "data_normal" {
  count = var.tkiv_data_node_number

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.tikv_data_node_instance_type
  availability_zone      = var.availability_zone
  subnet_id              = data.aws_subnet.selected.id
  key_name               = aws_key_pair.tikv_node.key_name
  vpc_security_group_ids = [aws_security_group.tikv_nodes.id]
  iam_instance_profile   = aws_iam_instance_profile.smm-role.name

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 40
    delete_on_termination = true
  }

  tags = {
    Name = "${var.cluster_name}-tikv-data-${count.index + 1}"
  }

  user_data = data.template_file.user_data_normal.rendered
}