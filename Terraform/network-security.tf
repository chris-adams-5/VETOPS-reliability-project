#==========================================
# DEDICATED PRIVATE SUBNETS FOR VETOP
#==========================================

# Clean subnet in Availability Zone A
resource "aws_subnet" "vet_private_a" {
  vpc_id            = "vpc-080dbb0b7dc86503a"
  cidr_block        = "172.31.200.0/24" # Safe, unused IP range
  availability_zone = "eu-west-2a"

  tags = {
    Name = "vet-dedicated-private-a"
  }
}

# Clean subnet in Availability Zone B
resource "aws_subnet" "vet_private_b" {
  vpc_id            = "vpc-080dbb0b7dc86503a"
  cidr_block        = "172.31.201.0/24" # Safe, unused IP range
  availability_zone = "eu-west-2b"

  tags = {
    Name = "vet-dedicated-private-b"
  }
}

#==========================================
# NAT GATEWAY AND ELASTIC IP
#==========================================

# grab a static ip for the nat gateway to use
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

# nat gateway in a public subnet so it can see the internet
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = "subnet-04a8c56d32950f29b"

  tags = {
    Name = "vet-hospital-nat"
  }
}

#==========================================
# PRIVATE ROUTE TABLE FOR LAMBDA & REDIS
#==========================================

# build a brand new, clean route table exclusively for the private subnets
resource "aws_route_table" "private_rt" {
  vpc_id = "vpc-080dbb0b7dc86503a"

  # route all external traffic to the nat gateway
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "vet-private-route-table"
  }
}

#==========================================
# ROUTE TABLE ASSOCIATIONS
#==========================================

# securely link the first dedicated private subnet to the NAT table
resource "aws_route_table_association" "private_subnet_1_assoc" {
  subnet_id      = aws_subnet.vet_private_a.id
  route_table_id = aws_route_table.private_rt.id
}

# securely link the second dedicated private subnet to the NAT table
resource "aws_route_table_association" "private_subnet_2_assoc" {
  subnet_id      = aws_subnet.vet_private_b.id
  route_table_id = aws_route_table.private_rt.id
}

#==========================================
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

#==========================================
# IAM EXECUTION ROLE FOR LAMBDA
#==========================================
resource "aws_iam_role" "lambda_exec_role" {
  name = "vet-cache-lambda-role"

  # trust policy for role so it can run securely
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

#==========================================
# IAM POLICY MADE BY AWS FOR VPC LAMBDAS
#==========================================

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

#==========================================
# LOAD BALANCER INVOCATION PERMISSION
#==========================================

resource "aws_lambda_permission" "allow_alb" {
  statement_id = "AllowExecutionFromALB"
  action       = "lambda:InvokeFunction"

  # yet to be defined/written, but named here for now
  function_name = aws_lambda_function.cache_proxy.function_name
  principal     = "elasticloadbalancing.amazonaws.com"

  # restricts access to least privilege.
  source_arn = aws_lb_target_group.lambda_cache_tg.arn
}

#==========================================
# LOAD BALANCER SECURITY GROUP
#==========================================

import {
  to = aws_security_group.loadbalancer_sg
  identity = {
    id = "sg-004241c2cdb8475b9"
  }
}

resource "aws_security_group" "loadbalancer_sg" {
  description = "Allows ingress via TCP on port 80 from all sources."
  egress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = ""
    from_port        = 0
    ipv6_cidr_blocks = ["::/0"]
    prefix_list_ids  = []
    protocol         = "-1"
    security_groups  = []
    self             = false
    to_port          = 0
  }]
  ingress = [{
    cidr_blocks = [
      "18.175.129.196/32", # traffic generator
      "46.208.96.91/32",   # Chris
      "54.86.50.139/32",   # Joe (Postman)
      "86.19.92.50/32",    # Ian
      "37.156.73.193/32"   # T
    ]
    description      = ""
    from_port        = 80
    ipv6_cidr_blocks = ["::/0"]
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = false
    to_port          = 80
  }]
  name                   = "Load Balancer Security Group VetOp"
  region                 = "eu-west-2"
  revoke_rules_on_delete = null
  tags = {
    Owner = "Students"
  }
  tags_all = {
    Owner = "Students"
  }
  vpc_id = "vpc-080dbb0b7dc86503a"
}