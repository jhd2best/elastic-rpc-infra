locals {
  harmony_binary_path = "v7575-v4.3.12-17-g3cdd9cfa/static/harmony"
  random_number       = 2341  # this is to force an update on all rpc jobs
  writer_cpu          = 20600 // MHz
  writer_memory       = 29500 // MB
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
    count              = each.value.num_writers
    binary_path        = local.harmony_binary_path
    random_number      = local.random_number
    tkiv_addr          = "[\"${join("\", \"", each.value.tkiv_pd_addrs)}\"]"
    redis_addr         = each.value.redis_addr
    boot_nodes         = var.boot_nodes
    network_type       = var.network
    cpu                = local.writer_cpu
    memory             = local.writer_memory
    memory_max         = local.writer_memory + 300
    is_cluster_public  = var.is_cluster_public
    dns_port           = var.dns_init_port
    p2p_port           = var.p2p_init_port
    explorer_init_port = var.explorer_init_port
  })
}