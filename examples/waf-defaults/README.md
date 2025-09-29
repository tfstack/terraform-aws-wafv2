# WAF Defaults Example

This example demonstrates AWS WAFv2 with default rules, managed rule sets, IP sets, custom response bodies, and monitoring capabilities.

## Features

- **Default Security Rules**: Pre-configured HTTP method restriction and rate limiting
- **Default Managed Rule Sets**: Easy-to-enable Core Rule Set, Known Bad Inputs, and SQL Injection protection
- **IP Sets**: Allowlist and blocklist functionality
- **Custom Response Bodies**: JSON-formatted error responses
- **CloudWatch Logging**: WAF logging with redacted fields
- **Monitoring**: Built-in CloudWatch monitoring with alarms
- **Lambda Backend**: Node.js Lambda function with ALB integration

## Architecture

```plaintext
Internet → ALB → WAFv2 → Lambda Function
                ↓
            CloudWatch Logs
                ↓
            CloudWatch Alarms
```

## Components

### Infrastructure

- **VPC**: Multi-AZ VPC with public and private subnets
- **ALB**: Application Load Balancer with Lambda target
- **Lambda**: Node.js API function with health endpoints
- **WAFv2**: Web Application Firewall with default rules and managed sets

### WAF Configuration

#### Default Rules (Easy Setup)

- **HTTP Method Restriction**: Blocks disallowed methods (DELETE, PATCH, OPTIONS, etc.)
- **Rate Limiting**: 1000 requests per 5 minutes per IP

#### Default Managed Rule Sets (One-Click Enable)

- **Core Rule Set**: XSS, injection, and common attack protection
- **Known Bad Inputs**: Blocks known malicious inputs
- **SQL Injection**: SQL injection attack protection

#### IP Sets

- **Allowed IPs**: `203.0.113.0/24`, `198.51.100.0/24`
- **Blocked IPs**: `10.0.0.100/32`

#### Custom Response Bodies

- **Blocked IP Message**: JSON response for IP-based blocks
- **Rate Limit Message**: JSON response for rate limit violations

## Usage

### Prerequisites

- Terraform >= 1.0
- AWS CLI configured
- Node.js (for Lambda function)

### Deployment

1. **Initialize Terraform**

   ```bash
   terraform init
   ```

2. **Plan the deployment**

   ```bash
   terraform plan
   ```

3. **Apply the configuration**

   ```bash
   terraform apply
   ```

4. **Get the ALB DNS name**

   ```bash
   terraform output alb_alb_dns
   ```

### Testing

The example includes testing capabilities:

```bash
# Test with different use cases
./test-waf.sh api-only
./test-waf.sh public-website
./test-waf.sh internal
./test-waf.sh scientific-data
```

### Monitoring

#### CloudWatch Dashboard

Access the WAF monitoring dashboard:

```bash
terraform output dashboard_url
```

#### WAF Logs

Monitor WAF logs in CloudWatch:

```bash
aws logs filter-log-events --log-group-name "aws-waf-logs-$(terraform output -raw waf_web_acl_name)"
```

#### Alarms

CloudWatch alarms are automatically created for:

- Blocked requests per rule
- Rate limit violations
- Custom rule violations

## Configuration

### Default Rules

```hcl
default_rules = {
  block_disallowed_methods = true
  general_rate_limit       = true
}
```

### Default Managed Rule Sets

```hcl
default_managed_rule_sets = {
  core_rule_set    = true
  known_bad_inputs = true
  sql_injection    = true
}
```

### IP Sets Configuration

```hcl
ip_sets = {
  allowed_ips = {
    name      = "allowed-ips"
    addresses = ["203.0.113.0/24", "198.51.100.0/24"]
  }
  blocked_ips = {
    name      = "blocked-ips"
    addresses = ["10.0.0.100/32"]
  }
}
```

### Custom Response Bodies Configuration

```hcl
custom_response_bodies = {
  blocked_ip_message = {
    key = "blocked_ip_message"
    content = jsonencode({
      error   = "Access Denied"
      message = "Your IP address has been blocked"
      code    = "BLOCKED_IP"
    })
    content_type = "APPLICATION_JSON"
  }
}
```

## Security Features

### HTTP Method Protection

- **Allowed**: GET, HEAD, POST, PUT
- **Blocked**: DELETE, PATCH, OPTIONS, TRACE, CONNECT

### Rate Limiting

- **Limit**: 1000 requests per 5 minutes per IP
- **Response**: 429 Too Many Requests with JSON error

### IP-based Access Control

- **Allowlist**: Specific IP ranges for trusted access
- **Blocklist**: Specific IPs for blocking

### AWS Managed Rules

- **Core Rule Set**: OWASP Top 10 protection
- **SQL Injection**: Database attack prevention
- **Known Bad Inputs**: Malicious input detection

## Monitoring and Alerting

### CloudWatch Metrics

- Blocked requests per rule
- Allowed requests per rule
- Rate limit violations
- IP set matches

### CloudWatch Alarms

- High blocked request count
- Rate limit violations
- Custom rule violations

### Logging

- **Log Group**: `/aws/wafv2/{waf-name}`
- **Retention**: 30 days
- **Redacted Fields**: Authorization, Cookie
- **Sampling**: Enabled

## Customization

### Using Default Rules and Managed Sets

The example demonstrates how to easily enable default security features:

```hcl
# Enable default security rules
default_rules = {
  block_disallowed_methods = true
  general_rate_limit       = true
}

# Enable default managed rule sets
default_managed_rule_sets = {
  core_rule_set    = true
  known_bad_inputs = true
  sql_injection    = true
}
```

### Adding Custom Rules

```hcl
rules = [
  {
    name                  = "CustomRule"
    priority              = 100
    action                = "block"
    statement_type        = "byte_match"
    search_string         = "malicious"
    field_to_match        = "query_string"
    text_transformation   = "LOWERCASE"
    positional_constraint = "CONTAINS"
  }
]
```

### Modifying IP Sets

```hcl
ip_sets = {
  custom_ips = {
    name      = "custom-ips"
    addresses = ["192.168.1.0/24"]
  }
}
```

### Adding Custom Response Bodies

```hcl
custom_response_bodies = {
  custom_error = {
    key          = "custom_error"
    content      = "Custom error message"
    content_type = "TEXT_PLAIN"
  }
}
```

## Outputs

| Name | Description |
|------|-------------|
| `alb_alb_dns` | ALB DNS name for testing |
| `waf_web_acl_name` | WAF Web ACL name |
| `waf_web_acl_arn` | WAF Web ACL ARN |
| `dashboard_url` | CloudWatch dashboard URL |
| `rule_alarms` | WAF CloudWatch alarms |
| `waf_log_group_name` | WAF log group name |

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## Cost Considerations

- **WAF**: $1.00 per Web ACL per month + $0.60 per million requests
- **CloudWatch Logs**: $0.50 per GB ingested + $0.03 per GB stored
- **CloudWatch Alarms**: $0.10 per alarm per month
- **Lambda**: Pay per request (first 1M requests free)
- **ALB**: $0.0225 per ALB-hour + $0.008 per LCU-hour

## Troubleshooting

### Common Issues

1. **Lambda timeout**: Increase timeout in Lambda configuration
2. **WAF not blocking**: Check rule priorities and conditions
3. **Logs not appearing**: Verify CloudWatch log group permissions
4. **Alarms not triggering**: Check alarm thresholds and evaluation periods

### Debugging

1. **Check WAF logs**:

   ```bash
   aws logs filter-log-events --log-group-name "aws-waf-logs-$(terraform output -raw waf_web_acl_name)"
   ```

2. **Test specific rules**:

   ```bash
   curl -X DELETE http://$(terraform output -raw alb_alb_dns)/
   ```

3. **Monitor CloudWatch metrics**:

   ```bash
   aws cloudwatch get-metric-statistics --namespace AWS/WAFV2 --metric-name BlockedRequests
   ```

## Security Best Practices

1. **Regular Updates**: Keep managed rule sets updated
2. **Monitoring**: Set up appropriate alarms and dashboards
3. **Logging**: Enable comprehensive logging for security analysis
4. **IP Management**: Regularly review and update IP sets
5. **Rate Limits**: Adjust rate limits based on application needs
6. **Response Bodies**: Use informative but secure error messages

## Support

For issues and questions:

- Check CloudWatch logs for detailed error information
- Review WAF rule priorities and conditions
- Verify IP set configurations
- Monitor CloudWatch metrics and alarms
