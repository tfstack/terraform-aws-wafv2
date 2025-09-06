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
    Project     = "waf-minimal"
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
# WAFv2 Module - Minimal Example
############################################

# Create Web ACL with AWS managed rules and associate with ALB
module "waf" {
  source = "../../"

  name_prefix = local.base_name
  description = "WAF with AWS managed rules"
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
    }
  ]

  resource_arns = [module.alb.alb_arn]

  # Enable WAF logging
  logging = {
    enabled                   = true
    cloudwatch_log_group_name = "aws-waf-logs-${local.base_name}"
    cloudwatch_retention_days = 30
    destroy_log_group         = true
  }

  # Enable built-in monitoring
  enable_monitoring = true
  alarm_threshold   = 100
}

############################################
# Outputs
############################################

output "alb_alb_dns" {
  description = "ALB DNS name"
  value       = module.alb.alb_dns
}

output "waf_web_acl_name" {
  description = "WAFv2 Web ACL name for monitoring"
  value       = module.waf.web_acl_name
}

output "dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.waf.dashboard_url
}
