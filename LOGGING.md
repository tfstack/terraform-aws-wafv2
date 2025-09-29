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
- **Kinesis Firehose**: Real-time streaming to multiple destinations *(coming soon)*

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

> **Coming Soon**: Kinesis Firehose logging support will be added in a future release.

### Planned Features

- Real-time streaming to multiple destinations
- Integration with S3, Redshift, Elasticsearch, and Splunk
- Data transformation capabilities
- Automatic retry and buffering
- Cost-effective for high-volume logging

### Future Configuration Example

```hcl
# This will be available in a future release
logging = {
  enabled = true
  kinesis_firehose_arn = "arn:aws:firehose:region:account:deliverystream/waf-logs"
  redacted_fields = ["authorization", "cookie"]
  sampled_requests_enabled = true
}
```

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
- Integration with third-party SIEM tools
- Need data transformation before storage
- High-volume, real-time processing requirements

### 2. S3 Bucket Naming

- **Required**: Must start with `aws-waf-logs-`
- **Recommended**: Include environment and purpose
- **Example**: `aws-waf-logs-prod-security-2024`

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

## Examples

See the [examples](examples/) directory for complete working examples:

- [S3 Logging Example](examples/s3-logging/) - Complete S3 logging setup
- [CloudWatch Logging Example](examples/waf-defaults/) - CloudWatch logs setup

## Related Documentation

- [AWS WAF Logging Documentation](https://docs.aws.amazon.com/waf/latest/developerguide/logging.html)
- [AWS WAF Logging Configuration](https://docs.aws.amazon.com/waf/latest/APIReference/API_LoggingConfiguration.html)
- [S3 Bucket Policy for WAF Logs](https://docs.aws.amazon.com/waf/latest/developerguide/logging-s3.html)
