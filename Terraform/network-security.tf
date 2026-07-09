#===========================
# A SECURITY GROUP FOR THE LAMBDA FUNCTION
#==========================================

resource "aws_security_group" "lambda_sg" {
    name = "vet-cache-lambda-sg"
    vpc_id = "vpc-080dbb0b7dc86503a"
  
}