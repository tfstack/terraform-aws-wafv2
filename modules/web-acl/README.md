# Web ACL Module

This module creates an AWS WAFv2 Web ACL with support for AWS managed rule sets and custom rules.

## Features

- Support for REGIONAL and CLOUDFRONT scopes
- AWS managed rule sets integration
- Custom rules including rate limiting, IP sets, and geo-blocking
- **Advanced Rate Limiting** with scope-down statements
- **Bandwidth Control** (request/response size limits)
- **IP Allowlist/Blocklist** functionality
- **Advanced Security Rules** (path protection, method filtering, user agent filtering)
- Optional logging configuration
- Flexible rule priority management

## Usage

### Basic Usage

```hcl
module "web_acl" {
  source = "./modules/web-acl"

  name_prefix = "my-app-waf"
  scope       = "REGIONAL"
  default_action = "allow"

  managed_rule_sets = [
    {
      name            = "AWSManagedRulesCommonRuleSet"
      priority        = 1
      rule_group_name = "AWSManagedRulesCommonRuleSet"
      override_action = "none"
    }
  ]

  tags = {
    Environment = "production"
  }
}
```

### Advanced Usage with Rate Limiting & Bandwidth Control

```hcl
module "web_acl" {
  source = "./modules/web-acl"

  name_prefix = "advanced-waf"
  scope       = "REGIONAL"
  default_action = "allow"

  # AWS Managed Rules
  managed_rule_sets = [
    {
      name            = "AWSManagedRulesCommonRuleSet"
      priority        = 1
      rule_group_name = "AWSManagedRulesCommonRuleSet"
      override_action = "none"
    },
    {
      name            = "AWSManagedRulesSQLiRuleSet"
      priority        = 2
      rule_group_name = "AWSManagedRulesSQLiRuleSet"
      override_action = "none"
    }
  ]

  # IP Sets for Allowlist/Blocklist
  blocked_ips = [
    "10.0.0.0/8",        # Internal networks
    "172.16.0.0/12",     # Internal networks
    "192.168.0.0/16",    # Internal networks
    "127.0.0.0/8"        # Localhost
  ]

  allowed_ips = [
    "203.0.113.0/24",    # Your office network
    "198.51.100.0/24",   # Your VPN network
  ]

  # Rate Limiting Configuration
  rate_limiting = {
    enabled        = true
    general_limit  = 2000  # 2000 requests per 5 minutes
    api_limit      = 500   # 500 requests per 5 minutes for API
    download_limit = 100   # 100 requests per 5 minutes for downloads
    api_paths      = ["/api/"]
    download_paths = ["/download/"]
  }

  # Bandwidth Control Configuration
  bandwidth_control = {
    enabled               = true
    max_request_size      = 1048576  # 1MB max request size
    max_query_string_size = 1024     # 1KB max query string
    max_header_size       = 8192     # 8KB max header size
  }

  # Advanced Security Rules
  advanced_security = {
    enabled                        = true
    block_admin_paths              = true
    admin_paths                    = ["/admin", "/administrator", "/wp-admin"]
    block_dangerous_methods        = true
    dangerous_methods              = ["TRACE", "OPTIONS"]
    block_suspicious_user_agents   = true
    suspicious_user_agents         = ["sqlmap", "nikto", "nmap"]
  }

  # CloudWatch Logging
  logging = {
    enabled                   = true
    cloudwatch_log_group_name = "/aws/wafv2/advanced-waf"
    cloudwatch_retention_days = 7
    redacted_fields           = ["authorization", "cookie"]
    destroy_log_group         = true
  }

  resource_arns = ["arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/my-alb/1234567890123456"]

  tags = {
    Environment = "production"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name_prefix | Name prefix for the Web ACL | `string` | n/a | yes |
| scope | Scope of the Web ACL (REGIONAL or CLOUDFRONT) | `string` | `"REGIONAL"` | no |
| default_action | Default action for the Web ACL (allow or block) | `string` | `"allow"` | no |
| managed_rule_sets | List of AWS managed rule sets to include | `list(object)` | `[]` | no |
| custom_rules | List of custom rules to include | `list(object)` | `[]` | no |
| logging | Logging configuration for the Web ACL | `object` | `null` | no |
| tags | Tags to apply to the Web ACL | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| web_acl_id | ID of the Web ACL |
| web_acl_arn | ARN of the Web ACL |
| web_acl_name | Name of the Web ACL |
| web_acl_scope | Scope of the Web ACL |

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.40.0 |
