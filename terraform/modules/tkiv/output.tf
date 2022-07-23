
// TODO: create all the logic necessary to create a tkiv cluster
output "pid_urls" {
  # create one domain per pd node like pd1.domain, pd2.domain, pd2.domain
  # and reference the internal pd config using those domains too
  # that will give us more flexibility to make the cluster open whenever we need to do some maintenance work like sync the cluster outside the vpc
  # or if we replace one ec2 instance we won't have the change the config file pointing to that node, just change the domain ip
  value = ["pd.tikv.t.hmny.io:2379"]
}

output "tkiv_data_urls" {
  # create one domain per data node like tkdata1.domain, tkdata2.domain, tkdata3.domain, tkdata4.domain, etc
  # and reference the internal pd config using those domains too
  # that will give us more flexibility to make the cluster open whenever we need to do some maintenance work like sync the cluster outside the vpc
  # or if we replace one ec2 instance we won't have the change the config file pointing to that node, just change the domain ip
  value = []
}