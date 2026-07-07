# main infrastructure

#===================================
# original load balancer - imported
#====================================

import {
  to = aws_lb.org-loadbalancer
  identity = {
    "arn" = "arn:aws:elasticloadbalancing:eu-west-2:664047078509:loadbalancer/app/lb-VetOp/543123630aad3957"
  }
}

resource "aws_lb" "org-loadbalancer" {
  client_keep_alive                           = 3600
  customer_owned_ipv4_pool                    = null
  desync_mitigation_mode                      = "defensive"
  dns_record_client_routing_policy            = null
  drop_invalid_header_fields                  = false
  enable_cross_zone_load_balancing            = true
  enable_deletion_protection                  = true
  enable_http2                                = true
  enable_prefix_for_ipv6_source_nat           = "off"
  enable_tls_version_and_cipher_suite_headers = false
  enable_waf_fail_open                        = false
  enable_xff_client_port                      = false
  enable_zonal_shift                          = false
  idle_timeout                                = 60
  internal                                    = false
  ip_address_type                             = "ipv4"
  load_balancer_type                          = "application"
  name                                        = "lb-VetOp"
  preserve_host_header                        = false
  region                                      = "eu-west-2"
  security_groups                             = ["sg-004241c2cdb8475b9"]
  tags = {
    Owner = "Students"
  }
  tags_all = {
    Owner = "Students"
  }
  xff_header_processing_mode = "append"
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    enabled = true
    prefix  = null
  }
  connection_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    enabled = true
    prefix  = null
  }
  health_check_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    enabled = true
    prefix  = null
  }
  subnet_mapping {
    allocation_id        = null
    ipv6_address         = null
    private_ipv4_address = null
    subnet_id            = "subnet-09ffb20c4da788637"
  }
  subnet_mapping {
    allocation_id        = null
    ipv6_address         = null
    private_ipv4_address = null
    subnet_id            = "subnet-0e606c290592d4005"
  }
}

#===================================
# s3 bucket - for load balancer cloudwatch logs
#====================================

resource "aws_s3_bucket" "alb_logs" {
  bucket        = "vetop-vet-hospital-alb-logs"
  force_destroy = true
}

#===================================
# bucket policy - for cloudwatch logs bucket
#====================================

resource "aws_s3_bucket_policy" "allow_logs_in_s3" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = data.aws_iam_policy_document.policy_allow_access_for_logs.json
}

data "aws_iam_policy_document" "policy_allow_access_for_logs" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::vetop-vet-hospital-alb-logs/*"]
    effect    = "Allow"
  }
}