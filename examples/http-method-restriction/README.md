# HTTP Method Restriction Example

This example demonstrates AWS WAFv2 with custom HTTP method restrictions, AWS managed rule sets, and bot control configuration.

## Features

- **Custom HTTP Method Rules**: Block specific HTTP methods (DELETE, PATCH, OPTIONS, TRACE, CONNECT)
- **AWS Managed Rule Sets**: Core Rule Set, SQL Injection, Linux, and Bot Control protection
- **Bot Control**: Configured for API-only use case with specific category overrides
- **CloudWatch Logging**: WAF logging with monitoring
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
- **WAFv2**: Web Application Firewall with custom method restrictions

### WAF Configuration

#### Custom HTTP Method Rules

- **DELETE Method**: Blocked (Priority 1)
- **PATCH Method**: Blocked (Priority 2)
- **OPTIONS Method**: Blocked (Priority 3)
- **TRACE Method**: Blocked (Priority 4)
- **CONNECT Method**: Blocked (Priority 5)

#### AWS Managed Rule Sets

- **Core Rule Set** (Priority 200): XSS and injection protection
- **SQL Injection** (Priority 300): Database attack prevention
- **Linux Rule Set** (Priority 400): LFI and command injection protection
- **Bot Control** (Priority 500): Automated traffic management

#### Bot Control Categories

- **Search Engines**: Blocked (not needed for APIs)
- **Content Fetchers**: Allowed (for research tools)
- **Monitoring**: Allowed (for reliability)
- **HTTP Libraries**: Allowed (for legitimate tools)
- **Scraping**: Blocked (prevent bulk harvesting)
- **Advertising**: Blocked (no ads needed)
- **Social Media**: Blocked (not social content)
- **AI/ML Bots**: Blocked (prevent automated access)

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
# Test HTTP method restrictions
./test-waf.sh
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

## Configuration

### Custom HTTP Method Rules Configuration

```hcl
rules = [
  {
    name                  = "BlockDELETE"
    priority              = 1
    action                = "block"
    statement_type        = "byte_match"
    search_string         = "DELETE"
    field_to_match        = "method"
    text_transformation   = "NONE"
    positional_constraint = "EXACTLY"
  }
  # ... additional method rules
]
```

### AWS Managed Rule Sets Configuration

```hcl
managed_rule_sets = [
  {
    name            = "AWSManagedRulesCommonRuleSet"
    priority        = 200
    rule_group_name = "AWSManagedRulesCommonRuleSet"
    override_action = "none"
    rule_action_overrides = {
      "CrossSiteScripting_QUERYARGUMENTS" = "block"
      "CrossSiteScripting_BODY"           = "block"
      "CrossSiteScripting_COOKIE"         = "block"
      "CrossSiteScripting_URIPATH"        = "block"
    }
  }
  # ... additional rule sets
]
```

### Bot Control Configuration

```hcl
{
  name            = "AWSManagedRulesBotControlRuleSet"
  priority        = 500
  rule_group_name = "AWSManagedRulesBotControlRuleSet"
  override_action = "none"
  rule_action_overrides = {
    CategorySearchEngine      = "block"
    CategoryContentFetcher    = "allow"
    CategoryMonitoring        = "allow"
    CategoryHttpLibrary       = "allow"
    CategoryScraping          = "block"
    CategoryAdvertising       = "block"
    CategorySocialMedia       = "block"
    CategoryScrapingFramework = "block"
    CategoryAI                = "block"
  }
}
```

## Security Features

### HTTP Method Protection

- **Allowed**: GET, HEAD, POST, PUT
- **Blocked**: DELETE, PATCH, OPTIONS, TRACE, CONNECT

### AWS Managed Rules

- **Core Rule Set**: OWASP Top 10 protection
- **SQL Injection**: Database attack prevention
- **Linux Rule Set**: LFI and command injection protection
- **Bot Control**: Automated traffic management

### Bot Control Summary

- **Blocked**: Search engines, scraping, advertising, social media, AI/ML
- **Allowed**: Content fetchers, monitoring, HTTP libraries

## Monitoring and Alerting

### CloudWatch Metrics

- Blocked requests per rule
- Allowed requests per rule
- Bot control blocks
- Method restriction blocks

### CloudWatch Alarms

- High blocked request count
- Bot control violations
- Method restriction violations

### Logging

- **Log Group**: `/aws/wafv2/{waf-name}`
- **Retention**: 30 days
- **Sampling**: Enabled

## Customization

### Adding Custom Method Rules

```hcl
rules = [
  {
    name                  = "BlockCustomMethod"
    priority              = 10
    action                = "block"
    statement_type        = "byte_match"
    search_string         = "CUSTOM_METHOD"
    field_to_match        = "method"
    text_transformation   = "NONE"
    positional_constraint = "EXACTLY"
  }
]
```

### Modifying Bot Control Categories

```hcl
rule_action_overrides = {
  CategorySearchEngine      = "allow"  # Allow search engines
  CategoryContentFetcher    = "block"  # Block content fetchers
  CategoryMonitoring        = "allow"  # Allow monitoring
  CategoryHttpLibrary       = "allow"  # Allow HTTP libraries
  CategoryScraping          = "block"  # Block scraping
  CategoryAdvertising       = "block"  # Block advertising
  CategorySocialMedia       = "allow"  # Allow social media
  CategoryScrapingFramework = "block"  # Block scraping frameworks
  CategoryAI                = "allow"  # Allow AI/ML bots
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

## Outputs

| Name | Description |
|------|-------------|
| `alb_alb_dns` | ALB DNS name for testing |
| `waf_web_acl_name` | WAF Web ACL name |
| `dashboard_url` | CloudWatch dashboard URL |

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

1. **Method not blocked**: Check rule priority and conditions
2. **Bot control not working**: Verify category overrides
3. **Logs not appearing**: Check CloudWatch log group permissions
4. **Alarms not triggering**: Check alarm thresholds

### Debugging

1. **Check WAF logs**:

   ```bash
   aws logs filter-log-events --log-group-name "aws-waf-logs-$(terraform output -raw waf_web_acl_name)"
   ```

2. **Test specific methods**:

   ```bash
   curl -X DELETE http://$(terraform output -raw alb_alb_dns)/
   curl -X PATCH http://$(terraform output -raw alb_alb_dns)/
   ```

3. **Monitor CloudWatch metrics**:

   ```bash
   aws cloudwatch get-metric-statistics --namespace AWS/WAFV2 --metric-name BlockedRequests
   ```

## Security Best Practices

1. **Method Restrictions**: Only allow necessary HTTP methods
2. **Bot Control**: Configure categories based on your use case
3. **Monitoring**: Set up appropriate alarms and dashboards
4. **Logging**: Enable comprehensive logging for security analysis
5. **Rule Priorities**: Order rules by importance and processing speed
6. **Regular Updates**: Keep managed rule sets updated

## Use Cases

### API Protection

- Block unnecessary HTTP methods
- Allow only GET, POST, PUT for REST APIs
- Block DELETE, PATCH for read-only APIs

### Web Application Security

- Restrict methods based on application needs
- Block dangerous methods like TRACE, CONNECT
- Allow OPTIONS for CORS if needed

### Bot Management

- Block search engines for internal APIs
- Allow monitoring tools for reliability
- Block scraping and automated access

## Support

For issues and questions:

- Check CloudWatch logs for detailed error information
- Review WAF rule priorities and conditions
- Verify bot control category configurations
- Monitor CloudWatch metrics and alarms
