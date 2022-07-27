output "tkiv_pd_url" {
  description = "the domain include all pd nodes for the tkiv cluster"
  value       = "${local.pd_domain}:2379"
  depends_on  = [null_resource.launch_tikv]
}

output "pd_private_ips" {
  description = "the private ip for each pd node in tkiv cluster"
  value       = local.pd_private_ips
}

output "data_private_ips" {
  description = "the private ip for each data node in tkiv cluster"
  value       = local.data_private_ips
}