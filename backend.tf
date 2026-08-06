terraform {
  backend "s3" {
    bucket       = "orange-ks8-logs"
    key          = "vpc/dev/state.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
