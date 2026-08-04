terraform {
  backend "s3" {
    bucket         = "orange-ks8-logs"
    key            = "vpc/dev/state.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
