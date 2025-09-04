# WAFv2 Advanced Example

This example demonstrates an advanced AWS WAFv2 setup with comprehensive security features, CloudWatch logging, IP sets, rate limiting, geo-blocking, and advanced monitoring.

## 🏗️ Architecture

```plaintext
Internet → WAFv2 (Advanced) → ALB → Lambda Function
           ↓
    CloudWatch Logs
           ↓
    CloudWatch Dashboard
           ↓
    CloudWatch Alarms
```

### Components

- **WAFv2**: Advanced Web Application Firewall with comprehensive rules
- **ALB**: Application Load Balancer with Lambda target
- **Lambda**: Node.js function serving API responses
- **VPC**: Complete networking setup with public/private subnets
- **CloudWatch**: Advanced logging, metrics, and monitoring dashboard

## 🚀 Advanced Features

### Security Features

- **AWS Managed Rules**: 4 comprehensive rule sets for common threats
- **IP Allowlist/Blocklist**: IP-based access control with 2 IP sets
- **Rate Limiting**: 2000 requests per 5 minutes per IP
- **Bandwidth Control**: Request size limits and URI length protection
- **Advanced Security Rules**: 18 custom rules for specific threats
- **Geo-blocking**: Geographic access control (CN, RU, KP)
- **File Extension Blocking**: Protection against sensitive file access

### Logging & Monitoring

- **CloudWatch Logging**: Comprehensive WAF logs with field redaction
- **Data Protection**: PII redaction and field filtering
- **Advanced Dashboard**: Comprehensive monitoring with multiple widgets
- **CloudWatch Alarms**: Automated alerting for various scenarios

## 📋 Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- jq (for JSON parsing in test scripts)
- curl (for testing)

## 🛠️ Quick Start

### 1. Deploy the Infrastructure

```bash
cd examples/alb-regional-advanced
terraform init
terraform plan
terraform apply
```

### 2. Test the Advanced WAF Rules

#### Comprehensive Test (20+ test categories)

```bash
chmod +x test-waf.sh
./test-waf.sh
```

### 3. Monitor WAF Activity

#### View CloudWatch Dashboard

```bash
# Get dashboard URL from state
echo "https://ap-southeast-2.console.aws.amazon.com/cloudwatch/home?region=ap-southeast-2#dashboards:name=waf-dashboard-$(terraform state show 'module.waf.aws_wafv2_web_acl.main' | grep name | awk '{print $3}' | tr -d '"' | sed 's/-waf$//')"
```

#### Check WAF Logs in CloudWatch

```bash
aws logs filter-log-events --region ap-southeast-2 --log-group-name "aws-waf-logs-$(terraform state show 'module.waf.aws_wafv2_web_acl.main' | grep name | awk '{print $3}' | tr -d '"' | sed 's/-waf$//')" --start-time $(date -d '5 minutes ago' +%s)000
```

#### View WAF Metrics

```bash
aws cloudwatch get-metric-statistics --region ap-southeast-2 --namespace AWS/WAFV2 --metric-name BlockedRequests --dimensions Name=WebACL,Value=$(terraform state show 'module.waf.aws_wafv2_web_acl.main' | grep name | awk '{print $3}' | tr -d '"') --start-time $(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%S) --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 300 --statistics Sum
```

## 🧪 Advanced Test Scenarios

### Rate Limiting Tests

| Test | Description | Expected Result |
|------|-------------|-----------------|
| **General Rate Limit** | 2000+ requests in 5 minutes | ❌ Blocked after limit |

### IP-based Tests

| Test | Description | Expected Result |
|------|-------------|-----------------|
| **Blocked IP** | Request from blocked IP | ❌ Blocked immediately |
| **Allowed IP** | Request from allowed IP | ✅ Bypasses rate limiting |

### Bandwidth Control Tests

| Test | Description | Expected Result |
|------|-------------|-----------------|
| **Large Request** | Request body > 1MB | ❌ Blocked by size limit |
| **Large URI Path** | URI path > 1KB | ❌ Blocked by size limit |
| **Very Large URI Path** | URI path > 2KB | ❌ Blocked by size limit |

### Advanced Security Tests

| Test | Description | Expected Result |
|------|-------------|-----------------|
| **Admin Path Access** | Request to `/admin/` | ❌ Blocked by admin path rule |
| **Dangerous Method** | TRACE/PROPFIND request | ❌ Blocked by method rule |
| **Suspicious Query** | eval() function in query | ❌ Blocked by query parameter rule |
| **File Extension** | Access to .env/.bak/.exe files | ❌ Blocked by file extension rule |
| **Directory Traversal** | ../ patterns in query | ❌ Blocked by directory traversal rule |

## 🛡️ Advanced WAF Rules Configuration

### AWS Managed Rule Sets

```hcl
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
```

### Rate Limiting Configuration

```hcl
# Single rate limiting rule
{
  name               = "GeneralRateLimit"
  priority           = 100
  action             = "block"
  statement_type     = "rate_based"
  limit              = 2000  # 2000 requests per 5 minutes per IP
  aggregate_key_type = "IP"
}
```

### Bandwidth Control

```hcl
# Request body size limit
{
  name                = "BlockLargeRequests"
  priority            = 500
  action              = "block"
  statement_type      = "size_constraint"
  field_to_match      = "body"
  size                = 1048576  # 1MB
  comparison_operator = "GT"
},
# URI path size limits
{
  name                = "BlockLargeURIs"
  priority            = 700
  action              = "block"
  statement_type      = "size_constraint"
  field_to_match      = "uri_path"
  size                = 1024     # 1KB
  comparison_operator = "GT"
},
{
  name                = "BlockVeryLargeURIs"
  priority            = 900
  action              = "block"
  statement_type      = "size_constraint"
  field_to_match      = "uri_path"
  size                = 2048     # 2KB
  comparison_operator = "GT"
}
```

### Advanced Security Rules

```hcl
# Admin path blocking
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
# Method blocking
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
  name                  = "BlockSuspiciousMethods"
  priority              = 1100
  action                = "block"
  statement_type        = "byte_match"
  search_string         = "PROPFIND"
  field_to_match        = "method"
  text_transformation   = "NONE"
  positional_constraint = "EXACTLY"
}
```

### Custom Rules

```hcl
# IP-based rules
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
# Query parameter blocking
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
# Geographic blocking
{
  name           = "BlockSuspiciousCountries"
  priority       = 600
  action         = "block"
  statement_type = "geo_match"
  country_codes  = ["CN", "RU", "KP"]
}
```

## 📊 Advanced Monitoring

### CloudWatch Metrics

- `BlockedRequests`: Number of requests blocked by WAF
- `AllowedRequests`: Number of requests allowed through
- `CountedRequests`: Number of requests counted (for monitoring)
- Rate limiting metrics by rule type
- Bandwidth control metrics
- IP-based blocking metrics

### CloudWatch Log Analysis

```bash
# Analyze WAF logs with jq (using state since outputs are commented out)
aws logs filter-log-events --region ap-southeast-2 --log-group-name "aws-waf-logs-$(terraform state show 'module.waf.aws_wafv2_web_acl.main' 2>/dev/null | grep 'name' | awk '{print $3}' | tr -d '"' | sed 's/-waf$//')" --start-time $(date -d '1 hour ago' +%s)000 --query 'events[].message' --output text | jq -r '.action' | sort | uniq -c
```

## 🔧 Customization

### Adding More IPs to Blocklist

```hcl
blocked_ips = [
  "192.168.1.100/32",
  "10.0.0.100/32",
  "203.0.113.0/24"  # Add new IP range
]
```

### Adjusting Rate Limits

```hcl
# Modify the GeneralRateLimit rule
{
  name               = "GeneralRateLimit"
  priority           = 100
  action             = "block"
  statement_type     = "rate_based"
  limit              = 5000  # Increase to 5000 requests per 5 minutes per IP
  aggregate_key_type = "IP"
}
```

### Adding Custom Rules

```hcl
# Add to the rules array in the WAF module
{
  name                  = "BlockSpecificPath"
  priority              = 1700  # Use next available priority
  action                = "block"
  statement_type        = "byte_match"
  search_string         = "/sensitive-path"
  field_to_match        = "uri_path"
  text_transformation   = "LOWERCASE"
  positional_constraint = "EXACTLY"
}
```

## 📊 Outputs

**Note**: All outputs are currently commented out in the example. To access resources, use Terraform state commands:

- **ALB DNS**: `terraform state show 'module.alb.aws_lb.main' | grep dns_name`
- **CloudWatch Dashboard**: `https://ap-southeast-2.console.aws.amazon.com/cloudwatch/home?region=ap-southeast-2#dashboards:name=waf-dashboard-$(terraform state show 'module.waf.aws_wafv2_web_acl.main' | grep name | awk '{print $3}' | tr -d '"' | sed 's/-waf$//')`
- **WAF Web ACL Name**: `terraform state show 'module.waf.aws_wafv2_web_acl.main' | grep name`
- **WAF Web ACL ARN**: `terraform state show 'module.waf.aws_wafv2_web_acl.main' | grep arn`
- **WAF Log Group**: `aws-waf-logs-$(terraform state show 'module.waf.aws_wafv2_web_acl.main' | grep name | awk '{print $3}' | tr -d '"' | sed 's/-waf$//')`

## 🧹 Cleanup

```bash
# Destroy the infrastructure
terraform destroy

# Confirm destruction
terraform destroy -auto-approve
```

## 📚 Related Examples

- [`alb-regional-minimal`](../alb-regional-minimal/) - Basic WAF setup
- [`alb-regional-cloudwatch`](../alb-regional-cloudwatch/) - CloudWatch logging only

## 🔗 Additional Resources

- [AWS WAFv2 Documentation](https://docs.aws.amazon.com/waf/latest/developerguide/waf-chapter.html)
- [WAFv2 Pricing](https://aws.amazon.com/waf/pricing/)
- [WAFv2 Best Practices](https://docs.aws.amazon.com/waf/latest/developerguide/waf-best-practices.html)
- [AWS Security Lake](https://aws.amazon.com/security-lake/)
- [Kinesis Data Firehose](https://aws.amazon.com/kinesis/data-firehose/)
