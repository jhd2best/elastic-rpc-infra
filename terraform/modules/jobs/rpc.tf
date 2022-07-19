locals {
  harmony_binary_path = "elastic_rpc_cluster/bin/harmony"
}

resource "nomad_job" "elastic_reader" {
  for_each = { for g in try(var.shard_config, []) : g.shard_number => g }
  jobspec = templatefile("${path.module}/jobs/elastic_reader.nomad", {
    shard        = each.key
    binary_path  = local.harmony_binary_path
    tkiv_addr    = each.value.tkiv_addr
    redis_addr   = each.value.redis_addr
    boot_nodes   = var.boot_nodes
    network_type = var.network
    http_domain  = each.value.shard_http_endpoint
    wss_domain   = each.value.shard_wss_endpoint
  })
}