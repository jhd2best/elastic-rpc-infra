terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

// check vpc exist
data "aws_vpc" "selected" {
  id = var.vpc_id
}

locals {
  data_private_ips = aws_instance.data_normal.*.private_ip
}

resource "null_resource" "scale_out_tikv" {
  connection {
    host        = var.pd_tiup_public_ip
    type        = "ssh"
    user        = "ubuntu"
    private_key = trimspace(var.pd_tiup_private_key)
    agent       = false
  }

  provisioner "file" {
    content = templatefile("${path.module}/files/topology.yaml.tftpl", {
      data_hosts     = local.data_private_ips,
    })
    destination = "/home/ubuntu/scale-out-topology.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "sleep 20",
      "export PATH=/home/ubuntu/.tiup/bin:$PATH",
      "tiup cluster check ./scale-out-topology.yaml --apply --user tikv",
      "tiup cluster scale-out ${var.cluster_name} ./scale-out-topology.yaml --user tikv -y",
      "sleep 10",
      "tiup cluster display ${var.cluster_name}",
    ]
  }
}