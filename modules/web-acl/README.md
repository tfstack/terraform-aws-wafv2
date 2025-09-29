# Web ACL Module

This module creates an AWS WAFv2 Web ACL with support for AWS managed rule sets and custom rules.

## Features

- Support for REGIONAL and CLOUDFRONT scopes
- AWS managed rule sets integration
- Custom rules including rate limiting, IP sets, and geo-blocking
- **Default Security Rules** (method blocking, rate limiting)
- **Default Managed Rule Sets** (Core Rule Set, SQL Injection, IP Reputation, etc.)
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

  # Enable default managed rule sets
  default_managed_rule_sets = {
    core_rule_set    = true
    known_bad_inputs = true
    sql_injection    = true
    ip_reputation    = true
    anonymous_ip     = true
  }

  # Enable default security rules
  default_rules = {
    block_disallowed_methods = true
    general_rate_limit       = true
  }

  tags = {
    Environment = "production"
  }
}
```

### Custom Managed Rule Sets

```hcl
module "web_acl" {
  source = "./modules/web-acl"

  name_prefix = "my-app-waf"
  scope       = "REGIONAL"
  default_action = "allow"

  # Custom managed rule sets with specific priorities
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

  tags = {
    Environment = "production"
  }
}
```

### Advanced Usage with Default Rules and Custom Configuration

```hcl
module "web_acl" {
  source = "./modules/web-acl"

  name_prefix = "advanced-waf"
  scope       = "REGIONAL"
  default_action = "allow"

  # Enable default managed rule sets
  default_managed_rule_sets = {
    core_rule_set    = true
    known_bad_inputs = true
    sql_injection    = true
    ip_reputation    = true
    anonymous_ip     = true
  }

  # Enable default security rules
  default_rules = {
    block_disallowed_methods = true
    general_rate_limit       = true
  }

  # Additional custom managed rule sets
  managed_rule_sets = [
    {
      name            = "AWSManagedRulesBotControlRuleSet"
      priority        = 200
      rule_group_name = "AWSManagedRulesBotControlRuleSet"
      override_action = "none"
    }
  ]

  # Custom rules for specific requirements
  rules = [
    {
      name                     = "BlockSpecificIPs"
      priority                 = 1
      action                   = "block"
      statement_type           = "ip_set"
      ip_set_arn               = aws_wafv2_ip_set.blocked_ips.arn
      custom_response_body_key = "blocked_ip_message"
      response_code            = 403
      response_headers         = {}
    }
  ]

  # IP Sets for Allowlist/Blocklist
  ip_sets = {
    blocked_ips = {
      name      = "blocked-ips"
      addresses = [
        "10.0.0.0/8",        # Internal networks
        "172.16.0.0/12",     # Internal networks
        "192.168.0.0/16",    # Internal networks
        "127.0.0.0/8"        # Localhost
      ]
    }
  }

  # Custom response bodies
  custom_response_bodies = {
    blocked_ip_message = {
      key          = "blocked_ip_message"
      content      = "Access denied from this IP address."
      content_type = "TEXT_PLAIN"
    }
  }

  # CloudWatch Logging
  logging = {
    enabled                   = true
    cloudwatch_log_group_name = "/aws/wafv2/advanced-waf"
    cloudwatch_retention_days = 7
    redacted_fields           = ["authorization", "cookie"]
    destroy_log_group         = true
  }

  tags = {
    Environment = "production"
  }
}
```

## Default Rules and Managed Rule Sets

### Default Security Rules

The module provides two default security rules that can be easily enabled:

#### `block_disallowed_methods`

- **Priority**: 5
- **Action**: Block
- **Purpose**: Blocks HTTP methods other than GET, HEAD, OPTIONS, POST, PUT
- **Response**: 405 Method Not Allowed

#### `general_rate_limit`

- **Priority**: 10
- **Action**: Block
- **Purpose**: Rate limiting at 1000 requests per 5 minutes per IP
- **Response**: 429 Too Many Requests with Retry-After header

### Default Managed Rule Sets

The module provides five commonly used AWS managed rule sets that can be easily enabled:

#### `core_rule_set` (Priority 100)

- **Rule Group**: AWSManagedRulesCommonRuleSet
- **Purpose**: Core web application security rules

#### `known_bad_inputs` (Priority 101)

- **Rule Group**: AWSManagedRulesKnownBadInputsRuleSet
- **Purpose**: Blocks known bad inputs and attack patterns

#### `sql_injection` (Priority 103)

- **Rule Group**: AWSManagedRulesSQLiRuleSet
- **Purpose**: SQL injection attack protection

#### `ip_reputation` (Priority 104)

- **Rule Group**: AWSManagedRulesAmazonIpReputationList
- **Purpose**: Blocks requests from known malicious IPs

#### `anonymous_ip` (Priority 105)

- **Rule Group**: AWSManagedRulesAnonymousIpList
- **Purpose**: Blocks requests from anonymous IP services (VPNs, proxies, etc.)

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name_prefix | Name prefix for the Web ACL | `string` | n/a | yes |
| scope | Scope of the Web ACL (REGIONAL or CLOUDFRONT) | `string` | `"REGIONAL"` | no |
| default_action | Default action for the Web ACL (allow or block) | `string` | `"allow"` | no |
| managed_rule_sets | List of AWS managed rule sets to include | `list(object)` | `[]` | no |
| default_managed_rule_sets | Enable/disable default managed rule sets | `object` | `{}` | no |
| rules | List of custom rules to include | `list(object)` | `[]` | no |
| default_rules | Enable/disable default security rules | `object` | `{}` | no |
| ip_sets | IP sets that can be referenced in rules | `map(object)` | `{}` | no |
| custom_response_bodies | Custom response bodies for WAF rules | `map(object)` | `{}` | no |
| logging | Logging configuration for the Web ACL | `object` | `null` | no |
| enable_monitoring | Enable CloudWatch monitoring for all rules | `bool` | `false` | no |
| alarm_sns_topic_arn | SNS topic ARN for alarm notifications | `string` | `null` | no |
| alarm_threshold | Threshold for rule alarms (blocked requests per 5 minutes) | `number` | `10` | no |
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
