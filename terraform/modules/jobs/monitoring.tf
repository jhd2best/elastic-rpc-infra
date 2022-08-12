locals {
  autoscaler_version = "0.3.6"
  min_instances      = 2
}

resource "nomad_job" "fabio" {
  jobspec = file("${path.module}/jobs/fabio.nomad")
}

resource "nomad_job" "prom_autoscaler" {
  for_each = { for g in try(var.nomad.cluster_groups, []) : g.id => g if g.id == "client" }
  jobspec = templatefile("${path.module}/jobs/prom_autoscaler.nomad", {
    # Prometheus
    env    = var.env
    region = var.region
    # Autoscaler
    client_asg_name        = var.nomad.autoscaling_groups[each.key].name
    client_node_class      = each.key
    autoscaler_version     = local.autoscaler_version
    client_max_nodes       = each.value.instance_count.max
    client_min_nodes       = local.min_instances
    token                  = var.nomad.nomad_master_token
    client_high_cpu_target = var.high_cpu_target
    client_low_cpu_target  = var.low_cpu_target
  })
}

resource "nomad_job" "promtail" {
  jobspec = templatefile("${path.module}/jobs/promtail.nomad", {
    env    = var.env
    region = var.region
  })
}
