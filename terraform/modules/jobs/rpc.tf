locals {
  harmony_binary_path = "elastic_rpc_cluster/bin/harmony"
  random_number       = 2342 # this is to force an update on all rpc jobs
}

resource "nomad_job" "elastic_reader" {
  for_each = { for g in try(var.shard_config, []) : g.shard_number => g }
  jobspec = templatefile("${path.module}/jobs/elastic_reader.nomad", {
    shard             = each.key
    binary_path       = local.harmony_binary_path
    random_number     = local.random_number
    tkiv_addr         = "[\"${join("\", \"", each.value.tkiv_pd_addrs)}\"]"
    redis_addr        = each.value.redis_addr
    boot_nodes        = var.boot_nodes
    network_type      = var.network
    is_cluster_public = var.is_cluster_public
    http_domain       = each.value.shard_http_endpoint
    http_domains      = each.value.other_supported_domains_http
    wss_domain        = each.value.shard_wss_endpoint
    wss_domains       = each.value.other_supported_domains_wss
  })
}

resource "nomad_job" "elastic_writer" {
  for_each = { for g in try(var.shard_config, []) : g.shard_number => g }
  jobspec = templatefile("${path.module}/jobs/elastic_writer.nomad", {
    shard              = each.key
    binary_path        = local.harmony_binary_path
    random_number      = local.random_number
    tkiv_addr          = "[\"${join("\", \"", each.value.tkiv_pd_addrs)}\"]"
    redis_addr         = each.value.redis_addr
    boot_nodes         = var.boot_nodes
    network_type       = var.network
    is_cluster_public  = var.is_cluster_public
    dns_port           = var.dns_init_port + each.key
    p2p_port           = var.p2p_init_port + each.key
    explorer_init_port = var.explorer_init_port + each.key
  })
}