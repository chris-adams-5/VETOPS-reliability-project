#===========================
# A SECURITY GROUP FOR THE LAMBDA FUNCTION
#==========================================

resource "aws_security_group" "lambda_sg" {
  name   = "vet-cache-lambda-sg"
  vpc_id = "vpc-080dbb0b7dc86503a"


  # egress rule to allow lambda to talk to elasticache
  egress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # egress rule to let lambda to fetch data from the backend (if it isnt cached)
  egress {
    from_port   = 80
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#==========================================
# A SECURITY GROUP FOR THE ELASTICACHE
#==========================================

resource "aws_security_group" "elasticache_sg" {
  name   = "vet-cache-redis-sg"
  vpc_id = "vpc-080dbb0b7dc86503a"

  ingress {
    from_port = 6379
    to_port   = 6379
    protocol  = "tcp"
    # this line allows only our lambda to connect to this cache
    security_groups = [aws_security_group.lambda_sg.id]
  }

}

#===============================
# IAM execution role for lambda, so it can run securely
#==================================
resource "aws_iam_role" "lambda_exec_role" {
  name = "vet-cache-lambda-role"

  # trust policy for role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

}

#=====================================
#IAM policy made by aws for lambdas running in a VPC
#=================

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ==========================================
# load balancer invocation Permission
# ==========================================

resource "aws_lambda_permission" "allow_alb" {
  statement_id = "AllowExecutionFromALB"
  action       = "lambda:InvokeFunction"

  # yet to be defined/written, but named here for now
  function_name = aws_lambda_function.cache_proxy.function_name
  principal     = "elasticloadbalancing.amazonaws.com"

  # restricts access to least privelege.
  source_arn = aws_lb_target_group.lambda_cache_tg.arn
}