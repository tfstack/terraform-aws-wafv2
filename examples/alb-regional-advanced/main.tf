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
    Project     = "waf-advanced-example"
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

############################################
# WAFv2 Module - Advanced Example
############################################

# Create Web ACL with advanced features
module "waf" {
  source = "../../"

  name_prefix = local.base_name
  description = "Advanced WAF with comprehensive security rules and monitoring"
  scope       = "REGIONAL"
  tags        = local.tags

  # AWS Managed Rule Sets
  managed_rule_sets = [
    {
      name            = "AWSManagedRulesCommonRuleSet"
      priority        = 1
      rule_group_name = "AWSManagedRulesCommonRuleSet"
      override_action = "none"
      rule_action_overrides = {
        "CrossSiteScripting_QUERYARGUMENTS" = "block"
        "CrossSiteScripting_BODY"           = "block"
        "CrossSiteScripting_COOKIE"         = "block"
        "CrossSiteScripting_URIPATH"        = "block"
      }
    },
    {
      name            = "AWSManagedRulesSQLiRuleSet"
      priority        = 2
      rule_group_name = "AWSManagedRulesSQLiRuleSet"
      override_action = "none"
      rule_action_overrides = {
        "SQLi_QUERYARGUMENTS" = "block"
        "SQLi_BODY"           = "block"
        "SQLi_COOKIE"         = "block"
        "SQLi_URIPATH"        = "block"
      }
    },
    {
      name            = "AWSManagedRulesLinuxRuleSet"
      priority        = 3
      rule_group_name = "AWSManagedRulesLinuxRuleSet"
      override_action = "none"
      rule_action_overrides = {
        "LFI_QUERYSTRING" = "block"
        "LFI_URIPATH"     = "block"
        "LFI_HEADER"      = "block"
      }
    },
    {
      name            = "AWSManagedRulesBotControlRuleSet"
      priority        = 4
      rule_group_name = "AWSManagedRulesBotControlRuleSet"
      override_action = "none"
    }
  ]

  # IP Sets
  ip_sets = {
    blocked_ips = {
      name      = "${local.base_name}-blocked-ips"
      addresses = ["192.168.1.100/32", "10.0.0.100/32"]
    }
    allowed_ips = {
      name      = "${local.base_name}-allowed-ips"
      addresses = ["203.0.113.0/24", "198.51.100.0/24"]
    }
  }

  # All WAF Rules (no hardcoded priorities, fully configurable)
  rules = [
    {
      name           = "BlockedIPs"
      priority       = 10
      action         = "block"
      statement_type = "ip_set"
      ip_set_arn     = module.waf.ip_set_arns["blocked_ips"]
    },
    {
      name           = "AllowedIPs"
      priority       = 20
      action         = "allow"
      statement_type = "ip_set"
      ip_set_arn     = module.waf.ip_set_arns["allowed_ips"]
    },
    {
      name               = "GeneralRateLimit"
      priority           = 100
      action             = "block"
      statement_type     = "rate_based"
      limit              = 2000
      aggregate_key_type = "IP"
    },
    {
      name                  = "BlockAdminPaths"
      priority              = 200
      action                = "block"
      statement_type        = "byte_match"
      search_string         = "/admin"
      field_to_match        = "uri_path"
      text_transformation   = "LOWERCASE"
      positional_constraint = "STARTS_WITH"
    },
    {
      name                  = "BlockSuspiciousQueryParams"
      priority              = 300
      action                = "block"
      statement_type        = "byte_match"
      search_string         = "eval("
      field_to_match        = "query_string"
      text_transformation   = "LOWERCASE"
      positional_constraint = "CONTAINS"
    },
    {
      name                  = "BlockTraceMethod"
      priority              = 400
      action                = "block"
      statement_type        = "byte_match"
      search_string         = "TRACE"
      field_to_match        = "method"
      text_transformation   = "NONE"
      positional_constraint = "EXACTLY"
    },
    {
      name                = "BlockLargeRequests"
      priority            = 500
      action              = "block"
      statement_type      = "size_constraint"
      field_to_match      = "body"
      size                = 1048576 # 1MB
      comparison_operator = "GT"
    },
    {
      name           = "BlockSuspiciousCountries"
      priority       = 600
      action         = "block"
      statement_type = "geo_match"
      country_codes  = ["CN", "RU", "KP"] # China, Russia, North Korea
    },
    {
      name                = "BlockLargeURIs"
      priority            = 700
      action              = "block"
      statement_type      = "size_constraint"
      field_to_match      = "uri_path"
      size                = 1024 # 1KB
      comparison_operator = "GT"
    },
    {
      name                  = "BlockSuspiciousExtensions"
      priority              = 800
      action                = "block"
      statement_type        = "byte_match"
      search_string         = ".env"
      field_to_match        = "uri_path"
      text_transformation   = "LOWERCASE"
      positional_constraint = "ENDS_WITH"
    },
    {
      name                = "BlockVeryLargeURIs"
      priority            = 900
      action              = "block"
      statement_type      = "size_constraint"
      field_to_match      = "uri_path"
      size                = 2048 # 2KB
      comparison_operator = "GT"
    },
    {
      name                  = "BlockSuspiciousQueryPatterns"
      priority              = 1000
      action                = "block"
      statement_type        = "byte_match"
      search_string         = "union select"
      field_to_match        = "query_string"
      text_transformation   = "LOWERCASE"
      positional_constraint = "CONTAINS"
    },
    {
      name                  = "BlockSuspiciousMethods"
      priority              = 1100
      action                = "block"
      statement_type        = "byte_match"
      search_string         = "PROPFIND"
      field_to_match        = "method"
      text_transformation   = "NONE"
      positional_constraint = "EXACTLY"
    },
    {
      name                  = "BlockSuspiciousURIPatterns"
      priority              = 1200
      action                = "block"
      statement_type        = "byte_match"
      search_string         = "wp-admin"
      field_to_match        = "uri_path"
      text_transformation   = "LOWERCASE"
      positional_constraint = "CONTAINS"
    },
    {
      name                  = "BlockSuspiciousFileExtensions"
      priority              = 1300
      action                = "block"
      statement_type        = "byte_match"
      search_string         = ".bak"
      field_to_match        = "uri_path"
      text_transformation   = "LOWERCASE"
      positional_constraint = "ENDS_WITH"
    },
    {
      name                  = "BlockDirectoryTraversal"
      priority              = 1400
      action                = "block"
      statement_type        = "byte_match"
      search_string         = "../"
      field_to_match        = "query_string"
      text_transformation   = "URL_DECODE"
      positional_constraint = "CONTAINS"
    },
    {
      name                  = "BlockSuspiciousURIPatterns2"
      priority              = 1500
      action                = "block"
      statement_type        = "byte_match"
      search_string         = "phpmyadmin"
      field_to_match        = "uri_path"
      text_transformation   = "LOWERCASE"
      positional_constraint = "CONTAINS"
    },
    {
      name                  = "BlockExecutableFiles"
      priority              = 1600
      action                = "block"
      statement_type        = "byte_match"
      search_string         = ".exe"
      field_to_match        = "uri_path"
      text_transformation   = "LOWERCASE"
      positional_constraint = "ENDS_WITH"
    }
  ]

  resource_arns = [module.alb.alb_arn]

  # Advanced Logging Configuration
  logging = {
    enabled                   = true
    cloudwatch_log_group_name = "aws-waf-logs-${local.base_name}"
    cloudwatch_retention_days = 30
    destroy_log_group         = true
    redacted_fields           = ["authorization", "cookie"]
    sampled_requests_enabled  = true
  }

  # Enable built-in monitoring
  enable_monitoring = true
  alarm_threshold   = 100
}

############################################
# Outputs
############################################

output "alb_dns" {
  description = "ALB DNS name"
  value       = module.alb.alb_dns
}

output "waf_web_acl_name" {
  description = "WAFv2 Web ACL name for monitoring"
  value       = module.waf.web_acl_name
}

output "waf_web_acl_arn" {
  description = "WAFv2 Web ACL ARN"
  value       = module.waf.web_acl_arn
}

output "dashboard_url" {
  description = "CloudWatch Dashboard URL for WAFv2 monitoring"
  value       = module.waf.dashboard_url
}

output "rule_alarms" {
  description = "WAF CloudWatch alarms"
  value       = module.waf.rule_alarms
}

output "waf_log_group_name" {
  description = "WAFv2 CloudWatch log group name"
  value       = "aws-waf-logs-${local.base_name}"
}
