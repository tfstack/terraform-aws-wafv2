# WAFv2 Minimal Example

This example demonstrates a basic AWS WAFv2 setup with AWS managed rules protecting an Application Load Balancer (ALB) with a Lambda function backend.

## 🏗️ Architecture

```plaintext
Internet → WAFv2 → ALB → Lambda Function
           ↓
    CloudWatch Logs
           ↓
    CloudWatch Dashboard
```

### Components

- **WAFv2**: Web Application Firewall with AWS managed rules
- **ALB**: Application Load Balancer with Lambda target
- **Lambda**: Node.js function serving API responses
- **VPC**: Complete networking setup with public/private subnets
- **CloudWatch**: Logging, metrics, and monitoring dashboard

## 🚀 Features

- **AWS Managed Rules**: 3 AWS managed rule sets for common security threats
- **Lambda Backend**: Simple Node.js Lambda function for testing
- **ALB Integration**: Application Load Balancer with WAF protection
- **VPC Setup**: Complete VPC with public/private subnets
- **WAF Logging**: CloudWatch Logs integration with proper naming
- **CloudWatch Dashboard**: Real-time WAF monitoring dashboard
- **CloudWatch Alarms**: Automated alerting for WAF events
- **Test Script**: Simple testing tool with 7 focused test categories

## 📋 Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- jq (for JSON parsing in test scripts)
- curl (for testing)

## 🛠️ Quick Start

### 1. Deploy the Infrastructure

```bash
cd examples/alb-regional-minimal
terraform init
terraform plan
terraform apply
```

### 2. Test the WAF Rules

```bash
chmod +x test-waf.sh
./test-waf.sh
```

### 3. Monitor WAF Activity

#### View CloudWatch Dashboard

```bash
terraform output -raw dashboard_url
```

#### Check WAF Logs

```bash
aws logs filter-log-events --region ap-southeast-2 --log-group-name $(terraform output -raw waf_web_acl_name) --start-time $(date -d '5 minutes ago' +%s)000
```

#### View WAF Metrics

```bash
aws cloudwatch get-metric-statistics --region ap-southeast-2 --namespace AWS/WAFV2 --metric-name BlockedRequests --dimensions Name=WebACL,Value=$(terraform output -raw waf_web_acl_name) --start-time $(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%S) --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 300 --statistics Sum
```

## 🧪 Test Scenarios

### Test Script (`test-waf.sh`)

| Test | Description | Expected Result |
|------|-------------|-----------------|
| **Basic Request** | Basic GET request to `/` | ✅ Allowed (HTTP 200) |
| **SQL Injection** | Malicious query parameters | ❌ Blocked (HTTP 403) |
| **XSS Attack** | Script injection attempt | ❌ Blocked (HTTP 403) |
| **Path Traversal** | Directory traversal attack | ❌ Blocked (HTTP 403) |
| **Command Injection** | Command execution attempt | ❌ Blocked (HTTP 403) |
| **WAF Logs** | Check CloudWatch logs for blocked requests | ✅ Logs found |
| **Status Summary** | WAF status and configuration | ✅ Active protection |

## 🛡️ WAF Rules Configuration

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
  }
]
```

## 📊 Monitoring

### CloudWatch Metrics

- `BlockedRequests`: Number of requests blocked by WAF
- `AllowedRequests`: Number of requests allowed through
- `CountedRequests`: Number of requests counted (for monitoring)

### Viewing Metrics

```bash
# Get blocked requests count
aws cloudwatch get-metric-statistics \
  --namespace AWS/WAFV2 \
  --metric-name BlockedRequests \
  --dimensions Name=WebACL,Value=$(terraform output -raw waf_web_acl_arn | cut -d/ -f2) \
  --start-time $(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

## 🔧 Customization

### Adding More Managed Rules

```hcl
managed_rule_sets = [
  # ... existing rules ...
  {
    name            = "AWSManagedRulesKnownBadInputsRuleSet"
    priority        = 4
    rule_group_name = "AWSManagedRulesKnownBadInputsRuleSet"
    override_action = "none"
  }
]
```

### Custom Rules

```hcl
custom_rules = [
  {
    name           = "CustomBlockRule"
    priority       = 100
    action         = "block"
    statement_type = "byte_match"
    search_string  = "malicious"
    field_to_match = "uri_path"
  }
]
```

## 📊 Outputs

After deployment, you can access:

- **ALB DNS**: `terraform output -raw alb_alb_dns`
- **CloudWatch Dashboard**: `terraform output -raw dashboard_url`
- **WAF Web ACL Name**: `terraform output -raw waf_web_acl_name`

## 🧹 Cleanup

```bash
# Destroy the infrastructure
terraform destroy

# Confirm destruction
terraform destroy -auto-approve
```

## 📚 Related Examples

- [`alb-regional-rate-limited`](../alb-regional-rate-limited/) - Basic WAF with rate limiting
- [`alb-regional-advanced`](../alb-regional-advanced/) - Advanced configuration with comprehensive rules

## 🔗 Additional Resources

- [AWS WAFv2 Documentation](https://docs.aws.amazon.com/waf/latest/developerguide/waf-chapter.html)
- [WAFv2 Pricing](https://aws.amazon.com/waf/pricing/)
- [WAFv2 Best Practices](https://docs.aws.amazon.com/waf/latest/developerguide/waf-best-practices.html)
