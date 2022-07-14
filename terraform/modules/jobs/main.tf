# this module is meant to be run after creating a Nomad cluster
# it takes care of running all jobs and setting up all important
# key/values in consul

terraform {
  required_providers {
    aws    = {}
    consul = {}
    nomad  = {}
  }
}
