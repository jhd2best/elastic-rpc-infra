
// TODO: create all the logic necessary to create a tkiv cluster
output "tkiv_url" {
  // make the tkiv url namespaced with the env and region
  value = "pd.tikv.t.hmny.io:2379"
}