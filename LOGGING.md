# AWS WAF Logging Configuration Guide

This document provides comprehensive documentation for configuring AWS WAF logging using the terraform-aws-wafv2 module.

## Table of Contents

1. [Logging Destinations](#logging-destinations)
2. [CloudWatch Logs Logging](#cloudwatch-logs-logging)
3. [S3 Logging](#s3-logging)
4. [Kinesis Firehose Logging](#kinesis-firehose-logging)
5. [Advanced Logging Features](#advanced-logging-features)
6. [Configuration Examples](#configuration-examples)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)
9. [Examples](#examples)
10. [Related Documentation](#related-documentation)

## Logging Destinations

The terraform-aws-wafv2 module supports multiple logging destinations:

- **CloudWatch Logs**: Real-time logging with immediate access
- **S3**: Cost-effective long-term storage and analytics
- **Kinesis Firehose**: Real-time streaming to multiple destinations

> **⚠️ Important**: Only one logging destination can be active at a time per Web ACL. The module validates this constraint and will fail if multiple destinations are specified simultaneously.

## CloudWatch Logs Logging

### CloudWatch Configuration

```hcl
logging = {
  enabled = true
  cloudwatch_log_group_name = "aws-waf-logs-my-webacl"
  cloudwatch_retention_days = 30
  destroy_log_group = false
}
```

### Features

- **Real-time logging**: Logs appear in CloudWatch Logs immediately
- **Retention control**: Configure log retention (1-365 days)
- **Log group management**: Option to destroy log group on module deletion
- **Sampled requests**: Control visibility of sample requests in AWS Console (3 options: disable, enable, enable with exclusions)

## S3 Logging

### S3 Configuration

```hcl
logging = {
  enabled = true
  s3_bucket_name = "aws-waf-logs-my-bucket"
  s3_bucket_prefix = "waf-logs/"
  redacted_fields = ["authorization", "cookie"]

  # Control sampled requests visibility in AWS WAF console
  sampled_requests_enabled = true
}
```

### S3 Bucket Requirements

- **Naming**: Bucket name must start with `aws-waf-logs-`
- **Permissions**: Requires proper bucket policy for AWS logging service
- **Region**: Must be in the same region as your WAF

### S3 Log Path Structure

AWS WAF automatically creates a standard hierarchical path structure:

```plaintext
AWSLogs/
├── {AccountID}/           # Your AWS account ID
    └── WAFLogs/          # Service identifier
        └── {Region}/     # AWS region
            └── {WebACL}/ # Web ACL name
                └── {Year}/{Month}/{Day}/{Hour}/{Minute}/
                    └── {AccountID}_waflogs_{Region}_{WebACL}_{Timestamp}_{RandomID}.log.gz
```

**Benefits:**

- Time-based partitioning for efficient querying
- Account and region isolation
- Compressed JSON format (`.gz`)
- Compatible with AWS Athena and other analytics tools

### S3 Bucket Policy Example

```hcl
resource "aws_s3_bucket_policy" "waf_logs" {
  bucket = aws_s3_bucket.waf_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.waf_logs.arn}/AWSLogs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AWSLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.waf_logs.arn
      }
    ]
  })
}
```

## Kinesis Firehose Logging

### Kinesis Firehose Configuration

```hcl
logging = {
  enabled = true
  kinesis_firehose_arn = "arn:aws:firehose:region:account:deliverystream/aws-waf-logs-stream-name"
  kinesis_firehose_role_arn = "arn:aws:iam::account:role/waf-logging-role"
  redacted_fields = ["authorization", "cookie"]
  sampled_requests_enabled = true
}
```

### Kinesis Firehose Features

- **Real-time streaming**: Logs are streamed to Kinesis Firehose in near real-time
- **Multiple destinations**: Stream to S3, Redshift, Elasticsearch, and Splunk
- **Data transformation**: Lambda integration for log transformation
- **Automatic retry**: Built-in retry mechanism for failed deliveries
- **Cost-effective**: Pay-per-use pricing for high-volume logging
- **Buffering**: Configurable buffer size and interval for optimal performance

### Kinesis Firehose Stream Requirements

- **Naming**: Stream name must start with `aws-waf-logs-` for WAF logging
- **IAM Role**: Requires dedicated IAM role for WAF to write to Firehose
- **Permissions**: WAF needs `firehose:PutRecord` and `firehose:PutRecordBatch` permissions

### IAM Role Configuration

```hcl
# IAM Role for WAF to write to Kinesis Firehose
resource "aws_iam_role" "waf_logging" {
  name = "waf-logging-role"

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
}

# IAM Policy for WAF to write to Firehose
resource "aws_iam_role_policy" "waf_logging" {
  name = "waf-logging-policy"
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
        Resource = "arn:aws:firehose:region:account:deliverystream/aws-waf-logs-stream-name"
      }
    ]
  })
}
```

### Kinesis Firehose Destinations

#### S3 Destination

```hcl
# Kinesis Firehose with S3 destination
module "kinesis_firehose" {
  source = "tfstack/kinesis-firehose/aws"

  name        = "aws-waf-logs-my-stream"
  destination = "extended_s3"

  s3_configuration = {
    role_arn            = aws_iam_role.firehose.arn
    bucket_arn          = aws_s3_bucket.waf_logs.arn
    prefix              = "waf-logs/!{timestamp:yyyy/MM/dd/}"
    error_output_prefix = "errors/!{firehose:error-output-type}/"
    buffer_interval     = 60
    buffer_size         = 10
    compression_format  = "GZIP"
  }

  create_cloudwatch_log_group         = true
  cloudwatch_log_group_retention_days = 7
}
```

#### Elasticsearch Destination

```hcl
# Kinesis Firehose with Elasticsearch destination
module "kinesis_firehose" {
  source = "tfstack/kinesis-firehose/aws"

  name        = "aws-waf-logs-elasticsearch"
  destination = "elasticsearch"

  elasticsearch_configuration = {
    domain_arn = aws_elasticsearch_domain.waf_logs.arn
    index_name = "waf-logs"
    type_name  = "waf-log"
    role_arn   = aws_iam_role.firehose.arn
  }
}
```

### Log Path Structure

Kinesis Firehose can deliver logs to various destinations with different path structures:

**S3 Destination:**

```plaintext
waf-logs/
├── 2024/01/15/          # Year/Month/Day
│   ├── 14/              # Hour
│   │   ├── 20240115T140000Z_000000000000_000000000000_000000000000.gz
│   │   └── 20240115T140100Z_000000000000_000000000000_000000000000.gz
│   └── 15/
└── errors/
    └── ProcessingFailed/
        └── 2024/01/15/14/
```

**Elasticsearch Destination:**

- Index: `waf-logs-YYYY.MM.DD`
- Type: `waf-log`
- Real-time searchable logs

## Advanced Logging Features

The following advanced features are available for logging configuration:

### Logging Filters

Control which requests get logged for cost optimization and focused analysis.

#### Filter Configuration

```hcl
logging_filter = {
  default_behavior = "KEEP" # or "DROP"
  filters = [
    {
      behavior    = "KEEP" # or "DROP"
      requirement = "MEETS_ALL" # or "MEETS_ANY"
      conditions = [
        {
          action_condition = {
            action = "BLOCK" # "ALLOW", "BLOCK", "COUNT"
          }
          label_name_condition = null
        }
      ]
    }
  ]
}
```

#### Filter Types

- **Action Conditions**: Filter by ALLOW, BLOCK, COUNT actions
- **Label Name Conditions**: Filter by specific rule labels
- **Requirements**: MEETS_ALL (all conditions) or MEETS_ANY (any condition)

### Sampled Requests Configuration

Control which requests are sampled and stored for analysis in the AWS WAF console.

#### Configuration Options

```hcl
sampled_requests_enabled = true/false
```

#### Options Available

**1. Enable Sampled Requests:**

```hcl
sampled_requests_enabled = true  # Default - enables sampled requests
```

**2. Disable Sampled Requests:**

```hcl
sampled_requests_enabled = false  # Disables sampled requests
```

#### Benefits

- **Console Visibility**: View sample requests in AWS WAF console for analysis
- **Debugging**: Helps troubleshoot rule behavior and request patterns
- **Security Analysis**: Review actual requests that triggered rules

### Field Redaction

Redact sensitive information from logs to meet compliance requirements.

#### Supported Fields

```hcl
redacted_fields = [
  "authorization",  # Authorization headers (Bearer tokens, Basic auth)
  "cookie",         # Session cookies
  "set-cookie",     # Set-Cookie response headers
  "x-api-key",      # Custom API key headers
  "x-auth-token",   # Custom authentication tokens
  "x-auth-header",  # Custom auth headers
  "x-forwarded-for", # Client IP forwarding headers
  "x-real-ip"       # Real IP headers
]
```

## Configuration Examples

### Example 1: Security-Focused S3 Logging

```hcl
logging = {
  enabled = true
  s3_bucket_name = "aws-waf-logs-security"
  s3_bucket_prefix = "security-logs/"

  # Redact sensitive fields
  redacted_fields = [
    "authorization",
    "cookie",
    "set-cookie",
    "x-api-key"
  ]

  # Only log blocked requests
  logging_filter = {
    default_behavior = "DROP"
    filters = [
      {
        behavior    = "KEEP"
        requirement = "MEETS_ALL"
        conditions = [
          {
            action_condition = {
              action = "BLOCK"
            }
            label_name_condition = null
          }
        ]
      }
    ]
  }

  sampled_requests_enabled = true
}
```

### Example 2: Comprehensive S3 Logging

```hcl
logging = {
  enabled = true
  s3_bucket_name = "aws-waf-logs-comprehensive"
  s3_bucket_prefix = "all-logs/"

  # Redact all sensitive fields
  redacted_fields = [
    "authorization",
    "cookie",
    "set-cookie",
    "x-api-key",
    "x-auth-token"
  ]

  # Log all requests with multiple filters
  logging_filter = {
    default_behavior = "KEEP"
    filters = [
      {
        behavior    = "KEEP"
        requirement = "MEETS_ANY"
        conditions = [
          {
            action_condition = {
              action = "BLOCK"
            }
            label_name_condition = null
          },
          {
            action_condition = {
              action = "COUNT"
            }
            label_name_condition = null
          }
        ]
      }
    ]
  }

  sampled_requests_enabled = true
}
```

### Example 3: CloudWatch Logs with Monitoring

```hcl
logging = {
  enabled = true
  cloudwatch_log_group_name = "aws-waf-logs-production"
  cloudwatch_retention_days = 90
  destroy_log_group = false
  sampled_requests_enabled = true
}

# Enable monitoring for alerts
enable_monitoring = true
alarm_sns_topic_arn = "arn:aws:sns:region:account:topic"
alarm_threshold = 10
```

### Example 4: Kinesis Firehose with S3 Destination

```hcl
# Kinesis Firehose delivery stream
module "kinesis_firehose" {
  source = "tfstack/kinesis-firehose/aws"

  name        = "aws-waf-logs-production"
  destination = "extended_s3"

  s3_configuration = {
    role_arn            = aws_iam_role.firehose.arn
    bucket_arn          = aws_s3_bucket.waf_logs.arn
    prefix              = "waf-logs/!{timestamp:yyyy/MM/dd/}"
    error_output_prefix = "errors/!{firehose:error-output-type}/"
    buffer_interval     = 60
    buffer_size         = 10
    compression_format  = "GZIP"
  }

  create_cloudwatch_log_group         = true
  cloudwatch_log_group_retention_days = 7
}

# WAF with Kinesis Firehose logging
module "waf" {
  source = "tfstack/wafv2/aws"

  name_prefix = "production"
  scope       = "REGIONAL"

  logging = {
    enabled = true
    kinesis_firehose_arn      = module.kinesis_firehose.delivery_stream_arn
    kinesis_firehose_role_arn = aws_iam_role.waf_logging.arn

    redacted_fields = [
      "authorization",
      "cookie",
      "set-cookie",
      "x-api-key"
    ]

    sampled_requests_enabled = true

    logging_filter = {
      default_behavior = "KEEP"
      filters = [
        {
          behavior    = "KEEP"
          requirement = "MEETS_ALL"
          conditions = [
            {
              action_condition = {
                action = "BLOCK"
              }
              label_name_condition = null
            }
          ]
        }
      ]
    }
  }

  resource_arns = [aws_lb.main.arn]
}
```

### Example 5: Kinesis Firehose with Multiple Destinations

```hcl
# Kinesis Firehose with S3 and Elasticsearch
module "kinesis_firehose" {
  source = "tfstack/kinesis-firehose/aws"

  name        = "aws-waf-logs-multi-dest"
  destination = "extended_s3"

  s3_configuration = {
    role_arn            = aws_iam_role.firehose.arn
    bucket_arn          = aws_s3_bucket.waf_logs.arn
    prefix              = "waf-logs/!{timestamp:yyyy/MM/dd/}"
    error_output_prefix = "errors/"
    buffer_interval     = 60
    buffer_size         = 5
    compression_format  = "GZIP"
  }

  # Optional: Add Elasticsearch as secondary destination
  elasticsearch_configuration = {
    domain_arn = aws_elasticsearch_domain.waf_logs.arn
    index_name = "waf-logs"
    type_name  = "waf-log"
    role_arn   = aws_iam_role.firehose.arn
  }

  create_cloudwatch_log_group = true
}
```

## Best Practices

### 1. Logging Destination Selection

**Use CloudWatch Logs when:**

- Real-time monitoring is required
- Integration with CloudWatch alarms/metrics
- Smaller log volumes
- Need immediate log access

**Use S3 when:**

- Large log volumes
- Long-term storage requirements
- Cost optimization needed
- Integration with analytics tools (Athena, etc.)

**Use Kinesis Firehose when:**

- Real-time streaming to multiple destinations
- Integration with third-party SIEM tools (Splunk, Elasticsearch)
- Need data transformation before storage
- High-volume, real-time processing requirements
- Want to stream to both S3 and analytics platforms
- Need automatic retry and buffering capabilities

### 2. Naming Conventions

**S3 Bucket Naming:**

- **Required**: Must start with `aws-waf-logs-`
- **Recommended**: Include environment and purpose
- **Example**: `aws-waf-logs-prod-security-2024`

**Kinesis Firehose Stream Naming:**

- **Required**: Must start with `aws-waf-logs-` for WAF logging
- **Recommended**: Include environment and purpose
- **Example**: `aws-waf-logs-prod-stream-2024`

### 3. Field Redaction Strategy

**High Security:**

```hcl
redacted_fields = [
  "authorization", "cookie", "set-cookie",
  "x-api-key", "x-auth-token", "x-auth-header"
]
```

**Balanced:**

```hcl
redacted_fields = [
  "authorization", "cookie", "x-api-key"
]
```

**Minimal:**

```hcl
redacted_fields = ["authorization"]
```

### 4. Logging Filter Strategy

**Security-Focused:**

- Use `default_behavior = "DROP"`
- Keep only `BLOCK` actions
- Redact all sensitive fields

**Cost-Optimized:**

- Use `default_behavior = "DROP"`
- Keep only critical events
- Minimal field redaction

**Comprehensive:**

- Use `default_behavior = "KEEP"`
- Add specific filters for analysis
- Full field redaction

### 5. S3 Lifecycle Management

```hcl
resource "aws_s3_bucket_lifecycle_configuration" "waf_logs" {
  bucket = aws_s3_bucket.waf_logs.id

  rule {
    id     = "waf-logs-lifecycle"
    status = "Enabled"

    filter {
      prefix = "waf-logs/"
    }

    # Transition to IA after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Transition to Glacier after 90 days
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Delete after 1 year
    expiration {
      days = 365
    }
  }
}
```

## Troubleshooting

### Common Issues

#### 1. Invalid S3 ARN Error

**Error**: `The ARN isn't valid. A valid ARN begins with arn:`

**Solution**: Ensure S3 bucket name starts with `aws-waf-logs-`

```hcl
# ❌ Wrong
s3_bucket_name = "my-waf-logs"

# ✅ Correct
s3_bucket_name = "aws-waf-logs-my-bucket"
```

#### 2. S3 Bucket Policy Issues

**Error**: WAF cannot write to S3 bucket

**Solution**: Ensure proper bucket policy with correct service principal

```hcl
Principal = {
  Service = "delivery.logs.amazonaws.com" # Correct service
}
```

#### 3. Logging Filter Validation Errors

**Error**: Invalid filter configuration

**Solution**: Ensure proper filter structure with all required fields

#### 4. Multiple Logging Destinations Error

**Error**: `Only one logging destination can be configured at a time`

**Solution**: Specify only one logging destination:

```hcl
# ❌ Wrong - Multiple destinations specified
logging = {
  enabled = true
  cloudwatch_log_group_name = "my-logs"
  s3_bucket_name = "my-bucket"  # This will cause validation error
}

# ✅ Correct - Single destination
logging = {
  enabled = true
  cloudwatch_log_group_name = "my-logs"
  s3_bucket_name = null
}
```

#### 5. Kinesis Firehose Stream Name Error

**Error**: `The ARN isn't valid. A valid ARN begins with arn:`

**Solution**: Ensure Kinesis Firehose stream name starts with `aws-waf-logs-`

```hcl
# ❌ Wrong
kinesis_firehose_arn = "arn:aws:firehose:region:account:deliverystream/my-waf-logs"

# ✅ Correct
kinesis_firehose_arn = "arn:aws:firehose:region:account:deliverystream/aws-waf-logs-my-stream"
```

#### 6. Kinesis Firehose IAM Permissions Error

**Error**: WAF cannot write to Kinesis Firehose stream

**Solution**: Ensure proper IAM role and permissions:

```hcl
# IAM Role for WAF logging
resource "aws_iam_role" "waf_logging" {
  name = "waf-logging-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "wafv2.amazonaws.com"  # Correct service principal
        }
      }
    ]
  })
}

# IAM Policy for Firehose permissions
resource "aws_iam_role_policy" "waf_logging" {
  name = "waf-logging-policy"
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
        Resource = "arn:aws:firehose:region:account:deliverystream/aws-waf-logs-stream-name"
      }
    ]
  })
}
```

### Monitoring and Verification

#### 1. Check WAF Logging Configuration

```bash
aws wafv2 get-logging-configuration \
  --resource-arn "arn:aws:wafv2:region:account:regional/webacl/name/id"
```

#### 2. Verify S3 Logs

```bash
# List log files
aws s3 ls s3://aws-waf-logs-bucket/AWSLogs/

# Check recent logs
aws s3 ls s3://aws-waf-logs-bucket/AWSLogs/ --recursive | tail -10
```

#### 3. Test Logging Filter

```bash
# Make requests that should be logged
curl "https://your-alb/test?q=union+select+*+from+users"

# Check if logs appear in S3
aws s3 ls s3://aws-waf-logs-bucket/AWSLogs/ --recursive | grep $(date +%Y/%m/%d)
```

#### 4. Verify Kinesis Firehose Logging

```bash
# Check Firehose delivery stream status
aws firehose describe-delivery-stream --delivery-stream-name aws-waf-logs-my-stream

# Check Firehose CloudWatch logs
aws logs describe-log-streams --log-group-name "/aws/kinesisfirehose/aws-waf-logs-my-stream"

# Check S3 destination for logs
aws s3 ls s3://my-waf-logs-bucket/waf-logs/ --recursive

# Test Firehose delivery
curl "https://your-alb/test?q=union+select+*+from+users"
sleep 60  # Wait for Firehose buffering
aws s3 ls s3://my-waf-logs-bucket/waf-logs/ --recursive | tail -5
```

#### 5. Monitor Kinesis Firehose Metrics

```bash
# Check Firehose delivery metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Firehose \
  --metric-name DeliveryToS3.Records \
  --dimensions Name=DeliveryStreamName,Value=aws-waf-logs-my-stream \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum

# Check Firehose error metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Firehose \
  --metric-name DeliveryToS3.Success \
  --dimensions Name=DeliveryStreamName,Value=aws-waf-logs-my-stream \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

## Examples

See the [examples](examples/) directory for complete working examples:

- [S3 Logging Example](examples/s3-logging/) - Complete S3 logging setup
- [CloudWatch Logging Example](examples/waf-defaults/) - CloudWatch logs setup
- [Kinesis Firehose Logging Example](examples/kinesis-firehose-logging/) - Complete Kinesis Firehose setup with S3 destination

## Related Documentation

- [AWS WAF Logging Documentation](https://docs.aws.amazon.com/waf/latest/developerguide/logging.html)
- [AWS WAF Logging Configuration](https://docs.aws.amazon.com/waf/latest/APIReference/API_LoggingConfiguration.html)
- [S3 Bucket Policy for WAF Logs](https://docs.aws.amazon.com/waf/latest/developerguide/logging-s3.html)
