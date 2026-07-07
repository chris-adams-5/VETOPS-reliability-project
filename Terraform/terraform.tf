# provider info

provider "aws" {
  region = "eu-west-2"
}

terraform {
  backend "s3" {
    bucket         = "vetop-vet-hospital-tf-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "eu-west-2"
   #dynamodb_table = "vetop-vet-hospital-tf-lock"
    use_lockfile   = true

  }
}