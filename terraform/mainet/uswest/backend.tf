terraform {
  backend "s3" {
    region         = "us-west-2"
    bucket         = "tf-harmony"
    key            = "elastic-rpc/mainet/uswest"
  }
}

