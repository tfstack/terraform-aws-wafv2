# Basic Configuration
variable "name_prefix" {
  description = "Name prefix for the Web ACL"
  type        = string
}

variable "description" {
  description = "Description for the Web ACL"
  type        = string
  default     = null
}

variable "scope" {
  description = "Scope of the Web ACL (REGIONAL or CLOUDFRONT)"
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "CLOUDFRONT"], var.scope)
    error_message = "Scope must be either 'REGIONAL' or 'CLOUDFRONT'."
  }
}

variable "default_action" {
  description = "Default action for the Web ACL (allow or block)"
  type        = string
  default     = "allow"

  validation {
    condition     = contains(["allow", "block"], var.default_action)
    error_message = "Default action must be either 'allow' or 'block'."
  }
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# AWS Managed Rule Sets
variable "managed_rule_sets" {
  description = "AWS managed rule sets to include"
  type = list(object({
    name                  = string
    priority              = number
    rule_group_name       = string
    override_action       = optional(string, "none")
    rule_action_overrides = optional(map(string), {})
  }))
  default = []

  validation {
    condition = var.managed_rule_sets == null || alltrue([
      for rule in coalesce(var.managed_rule_sets, []) : contains(["none", "count"], rule.override_action)
    ])
    error_message = "managed_rule_sets: override_action must be 'none' or 'count'."
  }
}

# Rules Configuration - All rules defined here, no hardcoded rules
variable "rules" {
  description = "WAF rules to apply (in priority order)"
  type = list(object({
    name                     = string
    priority                 = number
    action                   = string
    statement_type           = string
    search_string            = optional(string, null)
    field_to_match           = optional(string, null)
    text_transformation      = optional(string, "NONE")
    positional_constraint    = optional(string, "EXACTLY")
    header_name              = optional(string, null)
    size                     = optional(number, null)
    comparison_operator      = optional(string, null)
    limit                    = optional(number, null)
    aggregate_key_type       = optional(string, null)
    evaluation_window_sec    = optional(number, null)
    ip_set_arn               = optional(string, null)
    country_codes            = optional(list(string), null)
    regex_string             = optional(string, null)
    custom_response_body_key = optional(string, null)
    response_code            = optional(number, null)
    response_headers         = optional(map(string), {})
    negated                  = optional(bool, false)
  }))
  default = []

  validation {
    condition = alltrue([
      for r in var.rules : contains(["allow", "block", "count"], r.action)
    ])
    error_message = "rules: action must be 'allow', 'block', or 'count'."
  }

  validation {
    condition = alltrue([
      for r in var.rules : contains(["byte_match", "size_constraint", "rate_based", "ip_set", "geo_match", "regex_match"], r.statement_type)
    ])
    error_message = "rules: statement_type must be 'byte_match', 'size_constraint', 'rate_based', 'ip_set', 'geo_match', or 'regex_match'."
  }

  validation {
    condition = alltrue([
      for r in var.rules : r.statement_type != "byte_match" || (
        r.search_string != null && r.search_string != "" &&
        r.text_transformation != null && r.text_transformation != "" &&
        r.positional_constraint != null && r.positional_constraint != "" &&
        r.field_to_match != null && r.field_to_match != "" &&
        (r.field_to_match != "header" || (r.header_name != null && r.header_name != ""))
      )
    ])
    error_message = "rules: byte_match requires search_string, text_transformation, positional_constraint, field_to_match, and header_name if field_to_match is 'header'."
  }

  validation {
    condition = alltrue([
      for r in var.rules : r.statement_type != "size_constraint" || (
        r.size != null && r.comparison_operator != null &&
        r.field_to_match != null && r.field_to_match != "" &&
        (r.field_to_match != "header" || (r.header_name != null && r.header_name != ""))
      )
    ])
    error_message = "rules: size_constraint requires size, comparison_operator, field_to_match, and header_name if field_to_match is 'header'."
  }

  validation {
    condition = alltrue([
      for r in var.rules : r.statement_type != "rate_based" || (
        r.limit != null && r.aggregate_key_type != null
      )
    ])
    error_message = "rules: rate_based requires limit and aggregate_key_type."
  }

  validation {
    condition = alltrue([
      for r in var.rules : r.statement_type != "ip_set" || (
        r.ip_set_arn != null && r.ip_set_arn != ""
      )
    ])
    error_message = "rules: ip_set requires ip_set_arn."
  }

  validation {
    condition = alltrue([
      for r in var.rules : r.statement_type != "geo_match" || (
        try(r.country_codes, null) != null && try(length(r.country_codes), 0) > 0
      )
    ])
    error_message = "rules: geo_match requires country_codes."
  }

  validation {
    condition = alltrue([
      for r in var.rules : r.statement_type != "regex_match" || (
        r.regex_string != null && r.regex_string != "" &&
        r.field_to_match != null && r.field_to_match != "" &&
        (r.field_to_match != "header" || (r.header_name != null && r.header_name != ""))
      )
    ])
    error_message = "rules: regex_match requires regex_string, field_to_match, and header_name if field_to_match is 'header'."
  }
}

# IP Sets for reference in rules
variable "ip_sets" {
  description = "IP sets that can be referenced in rules"
  type = map(object({
    name               = string
    ip_address_version = optional(string, "IPV4")
    addresses          = list(string)
  }))
  default = {}
}

# Logging Configuration
variable "logging" {
  description = "Logging configuration for the Web ACL"
  type = object({
    enabled                   = bool
    cloudwatch_log_group_name = optional(string, null)
    cloudwatch_retention_days = optional(number, 30)
    redacted_fields           = optional(list(string), [])
    destroy_log_group         = optional(bool, false)
    sampled_requests_enabled  = optional(bool, true)
  })
  default = null

  validation {
    condition = var.logging == null ? true : (
      var.logging.cloudwatch_log_group_name == null
      || can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]*$", var.logging.cloudwatch_log_group_name))
    )
    error_message = "CloudWatch log group name must be valid."
  }
}

# Resource ARNs to associate with the Web ACL
variable "resource_arns" {
  description = "List of resource ARNs to associate with the Web ACL"
  type        = list(string)
  default     = []
}

# Monitoring Configuration
variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring (alarms + dashboard) for all rules"
  type        = bool
  default     = false
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for WAF alarms"
  type        = string
  default     = null
}

variable "alarm_threshold" {
  description = "Threshold for WAF rule alarms"
  type        = number
  default     = 10
}

# Default Rules
variable "default_rules" {
  description = "Enable/disable default security rules"
  type = object({
    block_disallowed_methods = optional(bool, false)
    general_rate_limit       = optional(bool, false)
  })
  default = {}
}

# Default Managed Rule Sets
variable "default_managed_rule_sets" {
  description = "Enable/disable default managed rule sets"
  type = object({
    core_rule_set    = optional(bool, false)
    known_bad_inputs = optional(bool, false)
    sql_injection    = optional(bool, false)
    ip_reputation    = optional(bool, false)
    anonymous_ip     = optional(bool, false)
  })
  default = {}
}

# Custom Response Bodies
variable "custom_response_bodies" {
  description = "Custom response bodies for WAF rules"
  type = map(object({
    key          = string
    content      = string
    content_type = string
  }))
  default = {}
}
