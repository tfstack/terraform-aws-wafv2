locals {
  # Default Rules
  default_rules = [
    var.default_rules.block_disallowed_methods ? {
      name                     = "BlockedMethods"
      priority                 = 5
      action                   = "block"
      statement_type           = "regex_match"
      search_string            = null
      field_to_match           = "method"
      text_transformation      = "NONE"
      positional_constraint    = null
      header_name              = null
      size                     = null
      comparison_operator      = null
      limit                    = null
      aggregate_key_type       = null
      ip_set_arn               = null
      country_codes            = null
      regex_string             = "GET|HEAD|OPTIONS|POST|PUT"
      custom_response_body_key = null
      response_code            = 405
      response_headers         = {}
      negated                  = true
    } : null,
    var.default_rules.general_rate_limit ? {
      name                     = "GeneralRateLimit"
      priority                 = 10
      action                   = "block"
      statement_type           = "rate_based"
      search_string            = null
      field_to_match           = null
      text_transformation      = "NONE"
      positional_constraint    = null
      header_name              = null
      size                     = null
      comparison_operator      = null
      limit                    = 1000
      aggregate_key_type       = "IP"
      evaluation_window_sec    = 300
      ip_set_arn               = null
      country_codes            = null
      regex_string             = null
      custom_response_body_key = "rate_limit_message"
      response_code            = 429
      response_headers = {
        "Retry-After"  = "60"
        "X-Rate-Limit" = "1000"
      }
      negated = false
    } : null
  ]

  all_rules = concat(coalesce(var.rules, []), [for rule in local.default_rules : rule if rule != null])

  # Add default custom response bodies when default rules are enabled
  all_custom_response_bodies = merge(
    var.custom_response_bodies,
    var.default_rules.general_rate_limit ? {
      rate_limit_message = {
        key          = "rate_limit_message"
        content      = "Rate limit exceeded. Please try again later."
        content_type = "TEXT_PLAIN"
      }
    } : {}
  )

  # Default Managed Rule Sets
  default_managed_rule_sets = [
    var.default_managed_rule_sets.core_rule_set ? {
      name                  = "CoreRuleSet"
      priority              = 100
      rule_group_name       = "AWSManagedRulesCommonRuleSet"
      override_action       = "none"
      rule_action_overrides = {}
    } : null,
    var.default_managed_rule_sets.known_bad_inputs ? {
      name                  = "KnownBadInputs"
      priority              = 101
      rule_group_name       = "AWSManagedRulesKnownBadInputsRuleSet"
      override_action       = "none"
      rule_action_overrides = {}
    } : null,
    var.default_managed_rule_sets.sql_injection ? {
      name                  = "SQLInjection"
      priority              = 103
      rule_group_name       = "AWSManagedRulesSQLiRuleSet"
      override_action       = "none"
      rule_action_overrides = {}
    } : null,
    var.default_managed_rule_sets.ip_reputation ? {
      name                  = "IPReputation"
      priority              = 104
      rule_group_name       = "AWSManagedRulesAmazonIpReputationList"
      override_action       = "none"
      rule_action_overrides = {}
    } : null,
    var.default_managed_rule_sets.anonymous_ip ? {
      name                  = "AnonymousIP"
      priority              = 105
      rule_group_name       = "AWSManagedRulesAnonymousIpList"
      override_action       = "none"
      rule_action_overrides = {}
    } : null
  ]

  all_managed_rule_sets = concat(coalesce(var.managed_rule_sets, []), [for rule_set in local.default_managed_rule_sets : rule_set if rule_set != null])

  # Logging Configuration
  waf_log_destinations = compact([
    var.logging != null && try(var.logging.cloudwatch_log_group_name, null) != null ? (
      length(aws_cloudwatch_log_group.waf_logs) > 0 ? aws_cloudwatch_log_group.waf_logs[0].arn :
      length(aws_cloudwatch_log_group.waf_logs_destroyable) > 0 ? aws_cloudwatch_log_group.waf_logs_destroyable[0].arn :
      "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:${var.logging != null ? var.logging.cloudwatch_log_group_name : ""}"
    ) : null,
  ])

  waf_redacted_fields = var.logging != null ? try(var.logging.redacted_fields, []) : []
}
