terraform {
  required_version = ">= 1.0"
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

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

############################################
# Random Suffix for Resource Names
############################################

resource "random_string" "suffix" {
  length  = 8
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

  name            = "waf-firehose"
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
resource "aws_iam_role" "lambda" {
  name = "${local.base_name}-lambda"

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

data "archive_file" "lambda_function" {
  type        = "zip"
  source_file = "${path.module}/external/lambda_function.js"
  output_path = "${path.module}/external/lambda_function.zip"
}

# Lambda Function
resource "aws_lambda_function" "api" {
  filename      = data.archive_file.lambda_function.output_path
  function_name = "${local.base_name}-api"
  role          = aws_iam_role.lambda.arn
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

module "s3_bucket" {
  source = "tfstack/s3/aws"

  bucket_name   = local.name
  bucket_suffix = local.suffix
  force_destroy = true
  tags          = local.tags

  enable_versioning = true

  lifecycle_rules = [
    {
      id     = "cleanup-incomplete-uploads"
      status = "Enabled"
      filter = {
        prefix = ""
      }
      abort_incomplete_multipart_upload = {
        days_after_initiation = 3
      }
    },
    {
      id     = "expire-old-logs"
      status = "Enabled"
      filter = {
        prefix = ""
      }
      expiration = {
        days = 90
      }
      noncurrent_version_expiration = {
        noncurrent_days = 30
      }
    }
  ]
}

############################################
# IAM Role for Kinesis Data Firehose
############################################

resource "aws_iam_role" "firehose" {
  name = "${local.base_name}-firehose"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "firehose" {
  name = "${local.base_name}-firehose"
  role = aws_iam_role.firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          module.s3_bucket.bucket_arn,
          "${module.s3_bucket.bucket_arn}/*"
        ]
      },
    ]
  })
}

module "kinesis-firehose" {
  source = "tfstack/kinesis-firehose/aws"

  # Note: "aws-waf-logs" prefix is required by AWS for WAF logging to Kinesis Data Firehose
  name        = "aws-waf-logs-${local.base_name}-firehose"
  destination = "extended_s3"

  s3_configuration = {
    role_arn            = aws_iam_role.firehose.arn
    bucket_arn          = module.s3_bucket.bucket_arn
    prefix              = "waf-logs/!{timestamp:yyyy/MM/dd/}"
    error_output_prefix = "errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    buffer_interval     = 60
    buffer_size         = 10
    compression_format  = "GZIP"

  }

  create_cloudwatch_log_group         = true
  cloudwatch_log_group_retention_days = 1
  cloudwatch_log_group_force_destroy  = true

  tags = local.tags
}

############################################
# IAM Role for WAF Logging
############################################

resource "aws_iam_role" "waf_logging" {
  name = "${local.base_name}-waf-logging"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "wafv2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "waf_logging" {
  name = "${local.base_name}-waf-logging"
  role = aws_iam_role.waf_logging.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "firehose:PutRecord",
          "firehose:PutRecordBatch"
        ]
        Resource = module.kinesis-firehose.delivery_stream_arn
      }
    ]
  })
}

############################################
# WAFv2 Module with S3 Logging Demo
############################################

module "waf" {
  source = "../.."

  name_prefix    = local.base_name
  description    = "WAF with Kinesis Firehose logging demonstration"
  scope          = "REGIONAL"
  default_action = "allow"

  # Enable logging to Kinesis Firehose
  logging = {
    # Enable WAF logging
    enabled = true

    # Kinesis Firehose configuration
    kinesis_firehose_arn      = "arn:aws:firehose:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:deliverystream/aws-waf-logs-${local.base_name}-firehose"
    kinesis_firehose_role_arn = aws_iam_role.waf_logging.arn

    # Redact sensitive fields from logs
    # Common fields to redact: authorization, cookie, set-cookie, x-api-key, etc.
    redacted_fields = [
      "authorization", # Authorization header (Bearer tokens, Basic auth, etc.)
      "cookie",        # Session cookies and other cookie data
      "set-cookie",    # Set-Cookie response headers
      "x-api-key",     # Custom API key headers
      "x-auth-token"   # Custom authentication token headers
    ]

    # Control sampled requests visibility in AWS WAF console
    # When true, AWS WAF stores a sample of requests that match rules
    # These samples are visible in the AWS WAF console for analysis
    sampled_requests_enabled = true

    # Advanced logging filter configuration
    # This demonstrates filtering which requests get logged
    logging_filter = {
      # Default behavior: KEEP all logs, DROP all logs, or apply filters
      default_behavior = "KEEP" # Keep all logs by default

      # Define specific filters for selective logging
      filters = [
        # Filter 1: Only log BLOCK actions (security-focused logging)
        {
          behavior    = "KEEP"      # Keep logs that match this filter
          requirement = "MEETS_ALL" # All conditions must be met
          conditions = [
            {
              action_condition = {
                action = "BLOCK" # Only log requests that were blocked
              }
              label_name_condition = null
            }
          ]
        },
        # Filter 2: Log requests with specific labels (e.g., from rate limiting rules)
        {
          behavior    = "KEEP"      # Keep logs that match this filter
          requirement = "MEETS_ANY" # Any condition can be met
          conditions = [
            {
              action_condition = null
              label_name_condition = {
                label_name = "RateLimitPerIP" # Log requests from rate limiting rule
              }
            }
          ]
        }
      ]
    }
  }

  # Add multiple rules to demonstrate comprehensive logging
  # Each rule action (block, count, allow) will be logged differently
  rules = [
    # Rule 1: Block SQL injection attempts
    {
      name                     = "BlockSQLInjection"
      priority                 = 11
      action                   = "block" # BLOCK actions are logged
      statement_type           = "byte_match"
      search_string            = "union select"
      field_to_match           = "query_string"
      text_transformation      = "LOWERCASE"
      positional_constraint    = "CONTAINS"
      header_name              = null
      size                     = null
      comparison_operator      = null
      limit                    = null
      aggregate_key_type       = null
      ip_set_arn               = null
      country_codes            = null
      regex_string             = null
      custom_response_body_key = null
      response_code            = null
      response_headers         = {}
      negated                  = false
    }
  ]

  # Associate with the ALB created above
  resource_arns = [
    module.alb.alb_arn
  ]

  tags = local.tags

  depends_on = [
    aws_iam_role_policy.waf_logging,
    module.kinesis-firehose
  ]
}
