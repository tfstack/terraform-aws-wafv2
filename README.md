# Terraform AWS WAFv2

Terraform module to create and manage AWS WAFv2 Web ACLs and resource associations

<!-- BEGIN_TF_DOCS -->
# Terraform AWS WAFv2

Terraform module to create and manage AWS WAFv2 Web ACLs and resource associations

<!-- BEGIN\_TF\_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input\_alarm\_sns\_topic\_arn"></a> [alarm\\_sns\\_topic\\_arn](#input\\_alarm\\_sns\\_topic\\_arn) | SNS topic ARN for WAF alarms | `string` | `null` | no |
| <a name="input\_alarm\_threshold"></a> [alarm\\_threshold](#input\\_alarm\\_threshold) | Threshold for WAF rule alarms | `number` | `10` | no |
| <a name="input\_custom\_response\_bodies"></a> [custom\\_response\\_bodies](#input\\_custom\\_response\\_bodies) | Custom response bodies for WAF rules | <pre>map(object({<br/>    key          = string<br/>    content      = string<br/>    content\_type = string<br/>  }))</pre> | `{}` | no |
| <a name="input\_default\_action"></a> [default\\_action](#input\\_default\\_action) | Default action for the Web ACL (allow or block) | `string` | `"allow"` | no |
| <a name="input\_description"></a> [description](#input\\_description) | Description for the Web ACL | `string` | `null` | no |
| <a name="input\_enable\_monitoring"></a> [enable\\_monitoring](#input\\_enable\\_monitoring) | Enable CloudWatch monitoring (alarms + dashboard) for all rules | `bool` | `false` | no |
| <a name="input\_ip\_sets"></a> [ip\\_sets](#input\\_ip\\_sets) | IP sets that can be referenced in rules | <pre>map(object({<br/>    name               = string<br/>    ip\_address\_version = optional(string, "IPV4")<br/>    addresses          = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input\_logging"></a> [logging](#input\\_logging) | Logging configuration for the Web ACL | <pre>object({<br/>    enabled                   = bool<br/>    cloudwatch\_log\_group\_name = optional(string, null)<br/>    cloudwatch\_retention\_days = optional(number, 30)<br/>    redacted\_fields           = optional(list(string), [])<br/>    destroy\_log\_group         = optional(bool, false)<br/>    sampled\_requests\_enabled  = optional(bool, true)<br/>  })</pre> | `null` | no |
| <a name="input\_managed\_rule\_sets"></a> [managed\\_rule\\_sets](#input\\_managed\\_rule\\_sets) | AWS managed rule sets to include | <pre>list(object({<br/>    name                  = string<br/>    priority              = number<br/>    rule\_group\_name       = string<br/>    override\_action       = optional(string, "none")<br/>    rule\_action\_overrides = optional(map(string), {})<br/>  }))</pre> | `[]` | no |
| <a name="input\_name\_prefix"></a> [name\\_prefix](#input\\_name\\_prefix) | Name prefix for the Web ACL | `string` | n/a | yes |
| <a name="input\_resource\_arns"></a> [resource\\_arns](#input\\_resource\\_arns) | List of resource ARNs to associate with the Web ACL | `list(string)` | `[]` | no |
| <a name="input\_rules"></a> [rules](#input\\_rules) | WAF rules to apply (in priority order) | <pre>list(object({<br/>    name                     = string<br/>    priority                 = number<br/>    action                   = string<br/>    statement\_type           = string<br/>    search\_string            = optional(string, null)<br/>    field\_to\_match           = optional(string, null)<br/>    text\_transformation      = optional(string, "NONE")<br/>    positional\_constraint    = optional(string, "EXACTLY")<br/>    header\_name              = optional(string, null)<br/>    size                     = optional(number, null)<br/>    comparison\_operator      = optional(string, null)<br/>    limit                    = optional(number, null)<br/>    aggregate\_key\_type       = optional(string, null)<br/>    ip\_set\_arn               = optional(string, null)<br/>    country\_codes            = optional(list(string), null)<br/>    custom\_response\_body\_key = optional(string, null)<br/>    response\_code            = optional(number, null)<br/>    response\_headers         = optional(map(string), {})<br/>  }))</pre> | `[]` | no |
| <a name="input\_scope"></a> [scope](#input\\_scope) | Scope of the Web ACL (REGIONAL or CLOUDFRONT) | `string` | `"REGIONAL"` | no |
| <a name="input\_tags"></a> [tags](#input\\_tags) | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output\_associated\_resources"></a> [associated\\_resources](#output\\_associated\\_resources) | List of associated resource ARNs |
| <a name="output\_association\_ids"></a> [association\\_ids](#output\\_association\\_ids) | Map of resource ARN to association ID |
| <a name="output\_dashboard\_url"></a> [dashboard\\_url](#output\\_dashboard\\_url) | CloudWatch dashboard URL |
| <a name="output\_ip\_set\_arns"></a> [ip\\_set\\_arns](#output\\_ip\\_set\\_arns) | Map of IP set names to their ARNs |
| <a name="output\_rule\_alarms"></a> [rule\\_alarms](#output\\_rule\\_alarms) | WAF CloudWatch alarms |
| <a name="output\_web\_acl\_arn"></a> [web\\_acl\\_arn](#output\\_web\\_acl\\_arn) | ARN of the Web ACL |
| <a name="output\_web\_acl\_id"></a> [web\\_acl\\_id](#output\\_web\\_acl\\_id) | ID of the Web ACL |
| <a name="output\_web\_acl\_name"></a> [web\\_acl\\_name](#output\\_web\\_acl\\_name) | Name of the Web ACL |

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement\_terraform"></a> [terraform](#requirement\\_terraform) | >= 1.0 |
| <a name="requirement\_aws"></a> [aws](#requirement\\_aws) | >= 6.0.0 |

## Providers

No providers.
<!-- END\_TF\_DOCS -->

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alarm_sns_topic_arn"></a> [alarm\_sns\_topic\_arn](#input\_alarm\_sns\_topic\_arn) | SNS topic ARN for WAF alarms | `string` | `null` | no |
| <a name="input_alarm_threshold"></a> [alarm\_threshold](#input\_alarm\_threshold) | Threshold for WAF rule alarms | `number` | `10` | no |
| <a name="input_custom_response_bodies"></a> [custom\_response\_bodies](#input\_custom\_response\_bodies) | Custom response bodies for WAF rules | <pre>map(object({<br/>    key          = string<br/>    content      = string<br/>    content_type = string<br/>  }))</pre> | `{}` | no |
| <a name="input_default_action"></a> [default\_action](#input\_default\_action) | Default action for the Web ACL (allow or block) | `string` | `"allow"` | no |
| <a name="input_description"></a> [description](#input\_description) | Description for the Web ACL | `string` | `null` | no |
| <a name="input_enable_monitoring"></a> [enable\_monitoring](#input\_enable\_monitoring) | Enable CloudWatch monitoring (alarms + dashboard) for all rules | `bool` | `false` | no |
| <a name="input_ip_sets"></a> [ip\_sets](#input\_ip\_sets) | IP sets that can be referenced in rules | <pre>map(object({<br/>    name               = string<br/>    ip_address_version = optional(string, "IPV4")<br/>    addresses          = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_logging"></a> [logging](#input\_logging) | Logging configuration for the Web ACL | <pre>object({<br/>    enabled                   = bool<br/>    cloudwatch_log_group_name = optional(string, null)<br/>    cloudwatch_retention_days = optional(number, 30)<br/>    redacted_fields           = optional(list(string), [])<br/>    destroy_log_group         = optional(bool, false)<br/>    sampled_requests_enabled  = optional(bool, true)<br/>  })</pre> | `null` | no |
| <a name="input_managed_rule_sets"></a> [managed\_rule\_sets](#input\_managed\_rule\_sets) | AWS managed rule sets to include | <pre>list(object({<br/>    name                  = string<br/>    priority              = number<br/>    rule_group_name       = string<br/>    override_action       = optional(string, "none")<br/>    rule_action_overrides = optional(map(string), {})<br/>  }))</pre> | `[]` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Name prefix for the Web ACL | `string` | n/a | yes |
| <a name="input_resource_arns"></a> [resource\_arns](#input\_resource\_arns) | List of resource ARNs to associate with the Web ACL | `list(string)` | `[]` | no |
| <a name="input_rules"></a> [rules](#input\_rules) | WAF rules to apply (in priority order) | <pre>list(object({<br/>    name                     = string<br/>    priority                 = number<br/>    action                   = string<br/>    statement_type           = string<br/>    search_string            = optional(string, null)<br/>    field_to_match           = optional(string, null)<br/>    text_transformation      = optional(string, "NONE")<br/>    positional_constraint    = optional(string, "EXACTLY")<br/>    header_name              = optional(string, null)<br/>    size                     = optional(number, null)<br/>    comparison_operator      = optional(string, null)<br/>    limit                    = optional(number, null)<br/>    aggregate_key_type       = optional(string, null)<br/>    ip_set_arn               = optional(string, null)<br/>    country_codes            = optional(list(string), null)<br/>    custom_response_body_key = optional(string, null)<br/>    response_code            = optional(number, null)<br/>    response_headers         = optional(map(string), {})<br/>  }))</pre> | `[]` | no |
| <a name="input_scope"></a> [scope](#input\_scope) | Scope of the Web ACL (REGIONAL or CLOUDFRONT) | `string` | `"REGIONAL"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_associated_resources"></a> [associated\_resources](#output\_associated\_resources) | List of associated resource ARNs |
| <a name="output_association_ids"></a> [association\_ids](#output\_association\_ids) | Map of resource ARN to association ID |
| <a name="output_dashboard_url"></a> [dashboard\_url](#output\_dashboard\_url) | CloudWatch dashboard URL |
| <a name="output_ip_set_arns"></a> [ip\_set\_arns](#output\_ip\_set\_arns) | Map of IP set names to their ARNs |
| <a name="output_rule_alarms"></a> [rule\_alarms](#output\_rule\_alarms) | WAF CloudWatch alarms |
| <a name="output_web_acl_arn"></a> [web\_acl\_arn](#output\_web\_acl\_arn) | ARN of the Web ACL |
| <a name="output_web_acl_id"></a> [web\_acl\_id](#output\_web\_acl\_id) | ID of the Web ACL |
| <a name="output_web_acl_name"></a> [web\_acl\_name](#output\_web\_acl\_name) | Name of the Web ACL |

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0.0 |

## Providers

No providers.
<!-- END_TF_DOCS -->
