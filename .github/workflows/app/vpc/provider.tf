provider "aws" {
  region = "us-west-2" #change
}

terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket" #change
    key    = "vpc/terraform.tfstate" #change
    region = "us-west-2" #chanage
  }
}
