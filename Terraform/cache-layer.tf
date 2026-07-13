# cache-layer.tf to hold cache infrastructure

#===================
# ElastiCache Provisioned (Non-Serverless)
#====================

resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "vet-hospital-redis-subnets"
  # updated to use both verified private subnets (private-2a and private-2b)
  subnet_ids = ["subnet-09ffb20c4da788637", "subnet-06675bda1a1539f1f"]
}

# added in size of processor etc for server and subnet cluster group
resource "aws_elasticache_cluster" "redis_cache" {
  cluster_id      = "vet-hospital-cache"
  engine          = "redis"
  node_type       = "cache.t4g.micro"
  num_cache_nodes = 1
  port            = 6379

  subnet_group_name  = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids = [aws_security_group.elasticache_sg.id]
}

#=========================
# package the code and zip it ready for lambda deployment
#===========================
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src"
  output_path = "${path.module}/cache_proxy.zip"
}

#=========================
# AWS Lambda Function
#=============================

resource "aws_lambda_function" "cache_proxy" {
  # points to the zip file from above
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "vet-cache-middleware"

  #  link the role to the lambda
  role    = aws_iam_role.lambda_exec_role.arn
  handler = "cache_proxy.lambda_handler"

  # makes sure that lambda is only updated when the python code changes
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.12"

  # attach the lambda to my private subnets to give it access to the Redis cache and NAT Gateway
  vpc_config {
    subnet_ids         = ["subnet-09ffb20c4da788637", "subnet-06675bda1a1539f1f"]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      REDIS_ENDPOINT     = aws_elasticache_cluster.redis_cache.cache_nodes[0].address
      VENDOR_BACKEND_URL = "http://vetop-reliability-server.animal-hospital.mkrs.link/"
      VENDOR_AUTH_HEADER = "Basic dGVzdC1hY2NvdW50LXZldG9wczp2ZXJ5d2Vhaw=="
    }
  }

}
