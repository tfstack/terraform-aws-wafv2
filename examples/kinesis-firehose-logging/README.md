# WAF with Kinesis Data Firehose Logging Example

This example demonstrates how to configure AWS WAFv2 with Kinesis Data Firehose logging using the terraform-aws-wafv2 module.

## Features

- **Kinesis Data Firehose delivery stream** for real-time log streaming
- **S3 destination** for Firehose logs with lifecycle management
- **WAF Web ACL** with custom SQL injection rule
- **Field redaction** for sensitive data protection
- **CloudWatch logging** for Firehose delivery monitoring
- **Advanced logging filters** for cost optimization and focused analysis
- **Complete infrastructure** including VPC, ALB, and Lambda function

## Architecture

```plaintext
Internet → ALB → WAF → Lambda Function
                ↓
         Kinesis Data Firehose → S3 Bucket
                ↓
         CloudWatch Logs (Firehose delivery monitoring)
```

## Usage

1. **Initialize and apply:**

   ```bash
   terraform init
   terraform apply
   ```

2. **Test WAF rules:**

   ```bash
   # Get ALB DNS name
   ALB_DNS=$(terraform output -raw alb_url)

   # Test normal requests (should be allowed)
   curl "http://$ALB_DNS/"

   # Test SQL injection (should be blocked and logged)
   curl "http://$ALB_DNS/?test=union+select+*+from+users"
   ```

3. **Monitor logs:**
   - WAF logs will be streamed to Kinesis Data Firehose
   - Firehose will deliver logs to S3 bucket under `waf-logs/` prefix
   - Monitor Firehose delivery in CloudWatch Logs

## Configuration Options

### Kinesis Firehose Settings

- **Buffer size**: 10 MB (configurable)
- **Buffer interval**: 60 seconds (configurable)
- **S3 prefix**: `waf-logs/!{timestamp:yyyy/MM/dd/}`
- **Error prefix**: `errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/`
- **Compression**: Enabled (GZIP)

### WAF Rules Configuration

- **SQL Injection Rule**: Blocks requests containing "union select" in query parameters
- **Default Action**: Allow all other requests
- **Rule Priority**: 11 (can be adjusted based on your needs)

### WAF Logging Configuration

- **Field redaction**: authorization, cookie, set-cookie, x-api-key, x-auth-token
- **Sampled requests**: Enabled for AWS Console visibility
- **Logging filters**: Advanced filtering for cost optimization and focused analysis
- **Log format**: JSON (newline-delimited)

### Logging Filter Configuration

The example includes advanced logging filters to demonstrate selective logging:

```hcl
logging_filter = {
  default_behavior = "KEEP" # Keep all logs by default

  filters = [
    {
      behavior    = "KEEP"
      requirement = "MEETS_ALL"
      conditions = [
        {
          action_condition = {
            action = "BLOCK"
          }
        }
      ]
    },
    {
      behavior    = "KEEP"
      requirement = "MEETS_ANY"
      conditions = [
        {
          label_name_condition = {
            label_name = "RateLimitPerIP"
          }
        }
      ]
    }
  ]
}
```

**What this does:**

- **Filter 1**: Keep logs for requests that were BLOCKED (including SQL injection blocks)
- **Filter 2**: Keep logs for requests that triggered rate limiting (if rate limiting rules are added)
- **Default**: Keep all other logs (since `default_behavior = "KEEP"`)

## Log Analysis

### Using AWS CLI

```bash
# List log files in S3
aws s3 ls s3://$(terraform output -raw s3_bucket_name)/waf-logs/ --recursive

# Download and analyze logs
aws s3 cp s3://$(terraform output -raw s3_bucket_name)/waf-logs/ . --recursive

# Count blocked requests by rule
cat *.gz | gunzip | jq -r 'select(.action=="BLOCK") | .terminatingRuleId' | sort | uniq -c | sort -rn

# Analyze SQL injection blocks
cat *.gz | gunzip | jq 'select(.action=="BLOCK" and .terminatingRuleId=="BlockSQLInjection") | {ip: .httpRequest.clientIp, uri: .httpRequest.uri, args: .httpRequest.args}'
```

### Using AWS Athena

Create a table to query WAF logs from S3:

```sql
CREATE EXTERNAL TABLE waf_firehose_logs (
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
LOCATION 's3://BUCKET_NAME/waf-logs/';
```

### Common Athena Queries

```sql
-- Top 10 blocked IPs
SELECT httprequest.clientip, COUNT(*) as block_count
FROM waf_firehose_logs
WHERE action = 'BLOCK'
GROUP BY httprequest.clientip
ORDER BY block_count DESC
LIMIT 10;

-- Requests by rule type
SELECT terminatingruletype, COUNT(*) as count
FROM waf_firehose_logs
WHERE action = 'BLOCK'
GROUP BY terminatingruletype
ORDER BY count DESC;

-- SQL injection blocks
SELECT httprequest.clientip, httprequest.uri, httprequest.args, COUNT(*) as blocks
FROM waf_firehose_logs
WHERE action = 'BLOCK' AND terminatingruleid = 'BlockSQLInjection'
GROUP BY httprequest.clientip, httprequest.uri, httprequest.args
ORDER BY blocks DESC;
```

## Monitoring

### CloudWatch Metrics

- **Firehose delivery**: `/aws/kinesisfirehose/STREAM_NAME`
- **WAF metrics**: Available in AWS WAF console
- **S3 metrics**: Available in S3 console

### CloudWatch Alarms

Consider setting up alarms for:

- Firehose delivery failures
- WAF rule blocking rates
- S3 bucket storage usage
- Lambda function errors
- High number of blocked requests

### Monitoring Commands

```bash
# Check Firehose delivery stream status
aws firehose describe-delivery-stream --delivery-stream-name $(terraform output -raw firehose_stream_name)

# Check CloudWatch logs for Firehose
aws logs describe-log-streams --log-group-name "/aws/kinesisfirehose/$(terraform output -raw firehose_stream_name)"

# Check S3 bucket metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/S3 \
  --metric-name BucketSizeBytes \
  --dimensions Name=BucketName,Value=$(terraform output -raw s3_bucket_name) \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Average
```

## Testing WAF Rules

### SQL Injection Test

```bash
# This should be blocked by the SQL injection rule
curl "http://$(terraform output -raw alb_url)/?test=union+select+*+from+users"

# Check if it appears in logs
aws s3 ls s3://$(terraform output -raw s3_bucket_name)/waf-logs/ --recursive | tail -5
```

### Normal Request Test

```bash
# These should be allowed through
curl "http://$(terraform output -raw alb_url)/"
curl "http://$(terraform output -raw alb_url)/api/health"

# Check allowed requests in logs
aws s3 cp s3://$(terraform output -raw s3_bucket_name)/waf-logs/ . --recursive
cat *.gz | gunzip | jq 'select(.action=="ALLOW")'
```

## Benefits of Kinesis Data Firehose

### Real-time Streaming

- **Low latency**: Logs are streamed in near real-time
- **Automatic scaling**: Handles varying log volumes automatically
- **Built-in retry**: Automatic retry for failed deliveries

### Multiple Destinations

- **S3**: Cost-effective long-term storage
- **Elasticsearch**: Real-time search and analytics
- **Splunk**: Security information and event management
- **HTTP endpoints**: Custom integrations

### Data Transformation

- **Lambda integration**: Transform logs before delivery
- **Compression**: Automatic GZIP compression
- **Partitioning**: Dynamic partitioning for better query performance

### Cost Optimization

- **Pay per use**: Only pay for data processed
- **No infrastructure**: Fully managed service
- **Automatic scaling**: No over-provisioning needed

## Troubleshooting

### Common Issues

1. **Firehose delivery failures:**

   ```bash
   # Check CloudWatch logs
   aws logs filter-log-events \
     --log-group-name "/aws/kinesisfirehose/$(terraform output -raw kinesis_firehose_name)" \
     --filter-pattern "ERROR"
   ```

2. **S3 permissions issues:**

   ```bash
   # Verify bucket policy
   aws s3api get-bucket-policy --bucket $(terraform output -raw s3_bucket_name)
   ```

3. **WAF not logging:**

   ```bash
   # Check WAF logging configuration
   aws wafv2 get-logging-configuration --resource-arn $(terraform output -raw waf_web_acl_arn)
   ```

4. **No WAF metrics in CloudWatch:**

   ```bash
   # Check if WAF is associated with ALB
   aws wafv2 list-resources-for-web-acl --web-acl-arn $(terraform output -raw waf_web_acl_arn)

   # Generate some traffic to create metrics
   curl "http://$(terraform output -raw alb_url)/"
   ```

### Debug Commands

```bash
# Check all resources
terraform show

# Check specific outputs
terraform output

# Validate configuration
terraform validate

# Check WAF rules
aws wafv2 list-rules --scope REGIONAL
```

## Cleanup

```bash
terraform destroy
```

This will remove all resources including:

- WAF Web ACL
- Kinesis Data Firehose delivery stream
- S3 bucket and policies
- IAM roles and policies
- VPC, ALB, and Lambda function
- CloudWatch log groups
- All associated networking resources

## Next Steps

### Advanced Configurations

1. **Multiple destinations**: Configure Firehose to deliver to multiple destinations
2. **Data transformation**: Add Lambda function for log transformation
3. **Dynamic partitioning**: Partition logs by timestamp, region, etc.
4. **Elasticsearch destination**: Stream logs directly to Elasticsearch
5. **Splunk integration**: Configure Splunk as a destination

### Integration Examples

- **SIEM integration**: Stream to security information systems
- **Real-time analytics**: Use Kinesis Analytics for real-time processing
- **Data lake**: Integrate with AWS Glue for data cataloging
- **Machine learning**: Use logs for ML model training

This example provides a solid foundation for implementing WAF logging with Kinesis Data Firehose, enabling real-time log streaming and flexible destination options.
