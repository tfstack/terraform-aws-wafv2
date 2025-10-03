# WAF with S3 Logging Extensive Configuration Example

This example demonstrates **comprehensive S3 logging configuration** for AWS WAFv2 with a focus on all available logging options. This is a direct S3 logging implementation (not via Kinesis Firehose).

## Purpose

This example showcases the **extensive logging configuration options** available when logging AWS WAF requests directly to S3, including:

- Field redaction for security
- Sampled requests control
- Multiple rule types generating different log patterns
- S3 bucket configuration best practices

## Features

### Extensive Logging Configuration

- **Field redaction** - Redact sensitive headers (authorization, cookies, API keys)
- **Sampled requests** - Control visibility of sample requests in AWS Console
- **S3 bucket prefix** - Organize logs within the bucket
- **Multiple rule types** - BLOCK, COUNT, and RATE_BASED rules for diverse logging

### S3 Bucket Security & Management

- **Server-side encryption** (AES256)
- **Public access blocking**
- **Versioning enabled**
- **Lifecycle policies** - Auto-expire logs after 90 days
- **Proper IAM policies** - AWS logging service permissions

### WAF Rules for Logging Demo

- **SQL Injection blocking** - Demonstrates BLOCK action logs
- **User agent monitoring** - Demonstrates COUNT mode (logs without blocking)
- **Rate limiting** - Demonstrates RATE_BASED rule logs

## What This Example Creates

1. **S3 Bucket** (`aws_s3_bucket.waf_logs`)
   - Bucket name includes account ID for uniqueness
   - Configured to receive WAF logs

2. **S3 Bucket Configuration**
   - Versioning enabled
   - Server-side encryption (AES256)
   - Public access blocked
   - Bucket policy allowing AWS logging service to write logs
   - Lifecycle rule to expire logs after 90 days

3. **WAF Web ACL**
   - Custom rule blocking SQL injection attempts
   - Logging enabled to the S3 bucket
   - Field redaction for sensitive headers

## Usage

1. **(Optional)** Update the `resource_arns` in `main.tf` if you want to associate the WAF with an ALB or other resource
2. Run `terraform init` and `terraform apply`
3. WAF logs will be written to the S3 bucket

## Extensive Logging Configuration Options

This example demonstrates **all available S3 logging options**:

### Core S3 Configuration

- **`enabled`**: Set to `true` to enable WAF logging
- **`s3_bucket_name`**: Target S3 bucket for logs (references the created bucket)
- **`s3_bucket_prefix`**: Organizational prefix (set to "waf-logs" in this example)

### Field Redaction (Security)

- **`redacted_fields`**: Array of header names to redact from logs
  - `authorization` - Authorization headers (Bearer tokens, Basic auth)
  - `cookie` - Session cookies and cookie data
  - `set-cookie` - Set-Cookie response headers
  - `x-api-key` - Custom API key headers
  - `x-auth-token` - Custom authentication tokens

**Why redact?** Prevents sensitive authentication data from being stored in logs, meeting compliance requirements (PCI-DSS, HIPAA, etc.)

### Sampled Requests Control

- **`sampled_requests_enabled`**: When `true`, AWS WAF stores sample requests that match rules
  - Samples are visible in AWS WAF Console for analysis
  - Useful for debugging and understanding traffic patterns
  - Does not affect what's logged to S3 (full logs still written)

### CloudWatch Options (Not Used in S3-Only Example)

- `cloudwatch_log_group_name`: Set to `null` (not using CloudWatch in this example)
- `cloudwatch_retention_days`: Default 30 (not applicable here)
- `destroy_log_group`: Default `false` (not applicable here)

**Note**: You can enable both S3 and CloudWatch logging simultaneously if needed.

## S3 Bucket Policy

This example includes the required S3 bucket policy to allow AWS logging service to write WAF logs:

```hcl
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSLogDeliveryWrite",
      "Effect": "Allow",
      "Principal": {
        "Service": "logging.s3.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::bucket-name/*"
    },
    {
      "Sid": "AWSLogDeliveryAclCheck",
      "Effect": "Allow",
      "Principal": {
        "Service": "logging.s3.amazonaws.com"
      },
      "Action": "s3:GetBucketAcl",
      "Resource": "arn:aws:s3:::bucket-name"
    }
  ]
}
```

The bucket policy is automatically applied by this example.

## Log Format & Examples

WAF logs are stored in S3 in **newline-delimited JSON format** (one JSON object per line).

### Example Log Entry - BLOCK Action (SQL Injection)

```json
{
  "timestamp": 1640995200000,
  "formatVersion": 1,
  "webaclId": "arn:aws:wafv2:us-east-1:123456789012:regional/webacl/example-waf/a1b2c3d4",
  "terminatingRuleId": "BlockSQLInjection",
  "terminatingRuleType": "REGULAR",
  "action": "BLOCK",
  "httpSourceName": "ALB",
  "httpSourceId": "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/my-alb/123456",
  "ruleGroupList": [],
  "rateBasedRuleList": [],
  "nonTerminatingMatchingRules": [],
  "httpRequest": {
    "clientIp": "203.0.113.1",
    "country": "US",
    "headers": [
      {
        "name": "Host",
        "value": "example.com"
      },
      {
        "name": "authorization",
        "value": "REDACTED"
      }
    ],
    "uri": "/search",
    "args": "q=union+select+*+from+users",
    "httpVersion": "HTTP/1.1",
    "httpMethod": "GET",
    "requestId": "12345678-1234-1234-1234-123456789012"
  }
}
```

**Notice**: The `authorization` header shows `"REDACTED"` because it's in the `redacted_fields` list.

### Example Log Entry - COUNT Action (User Agent Monitoring)

```json
{
  "timestamp": 1640995201000,
  "formatVersion": 1,
  "webaclId": "arn:aws:wafv2:us-east-1:123456789012:regional/webacl/example-waf/a1b2c3d4",
  "terminatingRuleId": "Default_Action",
  "terminatingRuleType": "REGULAR",
  "action": "ALLOW",
  "nonTerminatingMatchingRules": [
    {
      "ruleId": "CountSuspiciousUserAgents",
      "action": "COUNT"
    }
  ],
  "httpRequest": {
    "clientIp": "198.51.100.1",
    "country": "CA",
    "headers": [
      {
        "name": "user-agent",
        "value": "Mozilla/5.0 (compatible; Googlebot/2.1)"
      },
      {
        "name": "cookie",
        "value": "REDACTED"
      }
    ],
    "uri": "/",
    "httpMethod": "GET"
  }
}
```

**Notice**:

- Request was allowed (default action) but matched the COUNT rule
- The COUNT rule appears in `nonTerminatingMatchingRules`
- The `cookie` header is redacted

### Example Log Entry - RATE_BASED Rule

```json
{
  "timestamp": 1640995202000,
  "formatVersion": 1,
  "webaclId": "arn:aws:wafv2:us-east-1:123456789012:regional/webacl/example-waf/a1b2c3d4",
  "terminatingRuleId": "RateLimitPerIP",
  "terminatingRuleType": "RATE_BASED",
  "action": "BLOCK",
  "rateBasedRuleList": [
    {
      "rateBasedRuleId": "RateLimitPerIP",
      "limitKey": "IP",
      "maxRateAllowed": 2000
    }
  ],
  "httpRequest": {
    "clientIp": "203.0.113.50",
    "country": "US",
    "uri": "/api/endpoint",
    "httpMethod": "POST"
  },
  "httpSourceName": "ALB",
  "labels": []
}
```

**Notice**: The `rateBasedRuleList` shows which rate limit was exceeded.

## Analyzing Logs

### Using AWS CLI to Query Logs

```bash
# List log files
aws s3 ls s3://my-waf-logs-bucket-$(aws sts get-caller-identity --query Account --output text)/waf-logs/

# Download recent logs
aws s3 cp s3://my-waf-logs-bucket-$(aws sts get-caller-identity --query Account --output text)/waf-logs/ . --recursive

# Count blocked requests by rule
cat *.gz | gunzip | jq -r 'select(.action=="BLOCK") | .terminatingRuleId' | sort | uniq -c | sort -rn

# Find requests with redacted fields
cat *.gz | gunzip | jq 'select(.httpRequest.headers[]?.value=="REDACTED")'

# Analyze rate limit violations
cat *.gz | gunzip | jq 'select(.terminatingRuleType=="RATE_BASED") | {ip: .httpRequest.clientIp, rule: .terminatingRuleId}'
```

### Using AWS Athena for Log Analysis

Create a table in Athena to query WAF logs:

```sql
CREATE EXTERNAL TABLE waf_logs (
  timestamp bigint,
  formatversion int,
  webaclid string,
  terminatingruleid string,
  terminatingruletype string,
  action string,
  httpsourcename string,
  httpsourceid string,
  rulegrouplist array<string>,
  ratebasedrulelist array<struct<ratebasedruleid:string,limitkey:string,maxrateallowed:int>>,
  nonterminatingmatchingrules array<struct<ruleid:string,action:string>>,
  httprequest struct<
    clientip:string,
    country:string,
    headers:array<struct<name:string,value:string>>,
    uri:string,
    args:string,
    httpversion:string,
    httpmethod:string,
    requestid:string
  >
)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
LOCATION 's3://my-waf-logs-bucket-ACCOUNT_ID/waf-logs/';
```

### Common Queries

```sql
-- Top 10 blocked IPs
SELECT httprequest.clientip, COUNT(*) as block_count
FROM waf_logs
WHERE action = 'BLOCK'
GROUP BY httprequest.clientip
ORDER BY block_count DESC
LIMIT 10;

-- Requests with redacted fields
SELECT timestamp, httprequest.clientip, httprequest.uri
FROM waf_logs
WHERE EXISTS (
  SELECT 1 FROM UNNEST(httprequest.headers) AS h
  WHERE h.value = 'REDACTED'
);

-- Rate limit violations by hour
SELECT
  date_format(from_unixtime(timestamp/1000), '%Y-%m-%d %H:00') as hour,
  COUNT(*) as violations
FROM waf_logs
WHERE terminatingruletype = 'RATE_BASED'
GROUP BY date_format(from_unixtime(timestamp/1000), '%Y-%m-%d %H:00')
ORDER BY hour DESC;
```
