terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "4.0.1"
    }
  }
}

// check vpc exist
data "aws_vpc" "selected" {
  id = var.vpc_id
}

// check subnet exist
data "aws_subnet" "selected" {
  vpc_id            = var.vpc_id
  availability_zone = var.availability_zone
}

locals {
  pd_tiup_public_ip  = aws_eip.pd_tiup.public_ip
  pd_tiup_private_ip = aws_instance.pd_tiup.private_ip
  pd_private_ips     = concat([aws_instance.pd_tiup.private_ip], aws_instance.pd_normal.*.private_ip)
  data_private_ips   = aws_instance.data_normal.*.private_ip
  pd_domain          = "pd.${var.domain}"
}

resource "null_resource" "launch_tikv" {
  count = 1

  connection {
    host        = local.pd_tiup_public_ip
    type        = "ssh"
    user        = "ubuntu"
    private_key = trimspace(tls_private_key.tikv_nodes.private_key_pem)
    agent       = false
  }

  provisioner "file" {
    content     = tls_private_key.tikv_nodes.private_key_pem
    destination = "/home/ubuntu/.ssh/id_rsa"
  }

  provisioner "file" {
    content = templatefile("${path.module}/files/topology.yaml.tftpl", {
      pd_tiup_private_ip = local.pd_tiup_private_ip,
      pd_private_ips     = local.pd_private_ips,
      data_private_ips   = local.data_private_ips,
      replicas_count     = var.tkiv_replication_factor,
    })
    destination = "/home/ubuntu/topology.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "sleep 20",
      "export PATH=/home/ubuntu/.tiup/bin:$PATH",
      "tiup cluster check ./topology.yaml --apply --user tikv",
      "tiup cluster deploy ${var.cluster_name} ${var.cluster_version} ./topology.yaml --user tikv -y",
      "sleep 30",
      "tiup cluster start ${var.cluster_name}",
      "sleep 10",
      "tiup cluster display ${var.cluster_name}",
    ]
  }

  depends_on = [aws_instance.pd_tiup, aws_instance.pd_normal, aws_instance.data_normal]
}
