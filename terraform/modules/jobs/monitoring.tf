locals {
  autoscaler_version = "0.3.6"
}

resource "nomad_job" "fabio" {
  jobspec = file("${path.module}/jobs/fabio.nomad")
}

resource "nomad_job" "prom_autoscaler_portal" {
  for_each = { for g in try(var.nomad.cluster_groups, []) : g.id => g if g.id == "client" }
  jobspec = templatefile("${path.module}/jobs/prom_autoscaler.nomad", {
    # Prometheus
    env           = var.env
    nomad_cluster = "elastic_rpc"
    region        = var.region
    # Autoscaler
    client_asg_name           = var.nomad.autoscaling_groups[each.key].name
    client_node_class         = each.key
    autoscaler_version        = local.autoscaler_version
    client_max_nodes          = each.value.instance_count.max
    token                     = var.nomad.nomad_master_token
    client_low_memory_target  = var.low_memory_target
    client_high_memory_target = var.high_memory_target
    client_high_cpu_target    = var.high_cpu_target
    client_low_cpu_target     = var.low_cpu_target
  })
}

#resource "nomad_job" "promtail_portal" {
#  jobspec = templatefile("${path.module}/jobs/promtail.nomad", {
#    env           = var.env
#    nomad_cluster = "elastic_rpc"
#  })
#}