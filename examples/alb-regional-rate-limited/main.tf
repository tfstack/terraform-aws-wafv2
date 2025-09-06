terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

############################################
# Random Suffix for Resource Names
############################################

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

############################################
# Local Variables
############################################

locals {
  azs                  = ["ap-southeast-2a", "ap-southeast-2b", "ap-southeast-2c"]
  enable_dns_hostnames = true
  enable_https         = false

  name            = "waf"
  base_name       = local.suffix != "" ? "${local.name}-${local.suffix}" : local.name
  suffix          = random_string.suffix.result
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  region          = "ap-southeast-2"
  vpc_cidr        = "10.0.0.0/16"
  tags = {
    Environment = "dev"
    Project     = "waf-rate-limiting"
  }
}

############################################
# VPC Configuration
############################################

module "vpc" {
  source = "cloudbuildlab/vpc/aws"

  vpc_name           = local.base_name
  vpc_cidr           = local.vpc_cidr
  availability_zones = local.azs

  public_subnet_cidrs  = local.public_subnets
  private_subnet_cidrs = local.private_subnets

  # Enable Internet Gateway & NAT Gateway
  create_igw       = true
  nat_gateway_type = "single"

  tags = local.tags
}

############################################
# Lambda Function
############################################

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${local.base_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

# IAM Policy for Lambda execution
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "lambda_function" {
  type        = "zip"
  source_file = "${path.module}/external/lambda_function.js"
  output_path = "${path.module}/external/lambda_function.zip"
}

# Lambda Function
resource "aws_lambda_function" "api" {
  filename      = data.archive_file.lambda_function.output_path
  function_name = "${local.base_name}-api"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.handler"
  runtime       = "nodejs20.x"
  timeout       = 30
  memory_size   = 128

  environment {
    variables = {
      ENVIRONMENT = "dev"
    }
  }

  tags = local.tags
}

resource "aws_lambda_permission" "alb" {
  statement_id  = "AllowExecutionFromALB"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = "arn:aws:elasticloadbalancing:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:targetgroup/${local.base_name}-http/*"
}

############################################
# AWS ALB Module
############################################

module "alb" {
  source = "tfstack/alb/aws"

  name              = local.name
  suffix            = random_string.suffix.result
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids

  enable_https     = false
  http_port        = 80
  target_http_port = 80
  target_type      = "lambda"
  targets          = [aws_lambda_function.api.arn]

  # Health check configuration for Lambda (disabled)
  health_check_enabled = false

  tags = local.tags

  depends_on = [aws_lambda_permission.alb]
}

# SNS topic for WAF alerts
resource "aws_sns_topic" "waf_alerts" {
  name = "${local.base_name}-waf-alerts"
  tags = local.tags
}

# SNS topic subscription
resource "aws_sns_topic_subscription" "waf_alerts" {
  topic_arn = aws_sns_topic.waf_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

############################################
# WAFv2 Module - Rate Limited Example
############################################

module "waf" {
  source = "../../"

  name_prefix = local.base_name
  description = "WAF for rate limiting with IP exclusions and custom responses"
  scope       = "REGIONAL"
  tags        = local.tags

  # IP sets for exclusions
  ip_sets = {
    allowed_ips = {
      name      = "${local.base_name}-allowed-ips"
      addresses = ["203.0.113.0/24", "198.51.100.0/24"]
    }
    blocked_ips = {
      name      = "${local.base_name}-blocked-ips"
      addresses = ["10.0.0.100/32"]
    }
  }

  # Custom response bodies
  custom_response_bodies = {
    blocked_ip_message = {
      key = "blocked_ip_message"
      content = jsonencode({
        error     = "Access Denied"
        message   = "Your IP address has been blocked"
        code      = "BLOCKED_IP"
        timestamp = "$context.requestTime"
      })
      content_type = "APPLICATION_JSON"
    }
    rate_limit_message = {
      key = "rate_limit_message"
      content = jsonencode({
        error       = "Rate Limit Exceeded"
        message     = "Too many requests. Please try again later."
        code        = "RATE_LIMITED"
        retry_after = "300"
        timestamp   = "$context.requestTime"
      })
      content_type = "APPLICATION_JSON"
    }
  }

  # WAF rules with rate limiting exclusions
  rules = [
    # Block specific IPs immediately (highest priority)
    {
      name                     = "BlockedIPs"
      priority                 = 10
      action                   = "block"
      statement_type           = "ip_set"
      ip_set_arn               = module.waf.ip_set_arns["blocked_ips"]
      custom_response_body_key = "blocked_ip_message"
      response_code            = 403
    },
    # Allow specific IPs (bypasses rate limiting)
    {
      name           = "AllowedIPs"
      priority       = 20
      action         = "allow"
      statement_type = "ip_set"
      ip_set_arn     = module.waf.ip_set_arns["allowed_ips"]
    },
    # Rate limit all other IPs
    {
      name                     = "GeneralRateLimit"
      priority                 = 100
      action                   = "block"
      statement_type           = "rate_based"
      limit                    = 10
      aggregate_key_type       = "IP"
      custom_response_body_key = "rate_limit_message"
      response_code            = 429
      response_headers = {
        "Retry-After"  = "300"
        "X-Rate-Limit" = "10"
      }
    }
  ]

  resource_arns = [module.alb.alb_arn]

  # Enable monitoring
  enable_monitoring   = true
  alarm_sns_topic_arn = aws_sns_topic.waf_alerts.arn
  alarm_threshold     = 10
}

############################################
# Outputs
############################################

output "alb_dns" {
  description = "ALB DNS name"
  value       = module.alb.alb_dns
}

output "waf_web_acl_name" {
  description = "WAF Web ACL name"
  value       = module.waf.web_acl_name
}

output "waf_alarms" {
  description = "WAF CloudWatch alarms"
  value       = module.waf.rule_alarms
}

output "dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.waf.dashboard_url
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = aws_sns_topic.waf_alerts.arn
}
