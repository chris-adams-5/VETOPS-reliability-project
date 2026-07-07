# IAC for the VetOps AWS resources ()



#====================================
# terraform state bucket for state.tf
#======================================

resource "aws_s3_bucket" "terraform_state" { bucket = "vetop-vet-hospital-tf-state" }


resource "aws_s3_bucket_versioning" "state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

#===================================
# s3 bucket for load balancer cloudwatch logs
#====================================

resource "aws_s3_bucket" "alb_logs" {
  bucket = "vetop-vet-hospital-alb-logs"
}

#=============================================
# DynamoDB table for terraform state locking (to stop race conditions)
#=============================================
# resource "aws_dynamodb_table" "terraform_lock" {
#   name         = "vetop-vet-hospital-tf-lock"
#   billing_mode = "PAY_PER_REQUEST"
#   hash_key     = "LockID"

#   attribute {
#     name = "LockID"
#     type = "S"
#   }
# }
