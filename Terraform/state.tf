# IAC for the VetOps AWS resources

#====================================
#terraform state bucket for state.tf
#======================================

resource "aws_s3_bucket" "terraform_state" { bucket = "vet-hospital-tf-state-unique-id"}


resource "aws_s3_bucket_versioning" "state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}