# cache-layer.tf to hold cache infrastructure

#===================
# ElastiCache Serverless
#====================

resource "aws_elasticache_serverless_cache" "redis_cache" {
  engine = "redis"
  name   = "vet-hospital-cache"

  security_group_ids       = [aws_security_group.redis_sg.id]
  subnet_ids               = ["subnet-09ffb20c4da788637"]
}

#=========================
# package the code and zip it ready for lambda deployment
#===========================
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../src/cache_proxy.py"
  output_path = "${path.module}/cache_proxy.zip"
}

#=========================
# AWS Lambda Function
#=============================

resource "aws_lambda_function" "cache_proxy" {
    # points to the zip file from above
    filename = data.archive_file.lambda_zip.output_path
    function_name = "vet-cache-middleware"

    #  link the role to the lambda
    role = aws_iam_role.lambda_exec_role.arn
    handler = "cache_proxy.lambda_handler"

    # makes sure that lambda is only updated when the python code changes
    source_code_hash = data.archive_file.lambda_zip.output_base64sha256
    runtime = "python3.12"

    # attach the lambda to my private subnet to give it access to the Redis cache
    vpc_config {
      subnet_ids = ["subnet-09ffb20c4da788637"]
      security_group_ids = [aws_security_group.lambda_sg.id]
    }

    # code to put the redis endpoint url at the end of the lambda env variables so no need to hardcode.
    environment {
      
      variables = {
        REDIS_ENDPOINT = aws_elasticache_serverless_cache.redis_cache.endpoint[0].address
      }
    }
}