data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# IP Sets - created from ip_sets variable
resource "aws_wafv2_ip_set" "sets" {
  for_each = coalesce(var.ip_sets, {})

  name               = each.value.name
  scope              = var.scope
  ip_address_version = each.value.ip_address_version
  addresses          = each.value.addresses

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# Web ACL for WAFv2
resource "aws_wafv2_web_acl" "main" {
  name        = var.name_prefix
  description = var.description
  scope       = var.scope

  depends_on = [aws_wafv2_ip_set.sets]

  default_action {
    dynamic "allow" {
      for_each = var.default_action == "allow" ? [1] : []
      content {}
    }
    dynamic "block" {
      for_each = var.default_action == "block" ? [1] : []
      content {}
    }
  }

  # Custom Response Bodies
  dynamic "custom_response_body" {
    for_each = local.all_custom_response_bodies
    content {
      key          = custom_response_body.value.key
      content      = custom_response_body.value.content
      content_type = custom_response_body.value.content_type
    }
  }

  # AWS Managed Rule Sets
  dynamic "rule" {
    for_each = local.all_managed_rule_sets
    content {
      name     = rule.value.name
      priority = rule.value.priority

      override_action {
        dynamic "count" {
          for_each = rule.value.override_action == "count" ? [1] : []
          content {}
        }
        dynamic "none" {
          for_each = rule.value.override_action == "none" || try(rule.value.override_action, null) == null ? [1] : []
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.rule_group_name
          vendor_name = "AWS"

          dynamic "rule_action_override" {
            for_each = rule.value.rule_action_overrides != null ? rule.value.rule_action_overrides : {}
            content {
              name = rule_action_override.key
              action_to_use {
                dynamic "allow" {
                  for_each = rule_action_override.value == "allow" ? [1] : []
                  content {}
                }
                dynamic "block" {
                  for_each = rule_action_override.value == "block" ? [1] : []
                  content {}
                }
                dynamic "count" {
                  for_each = rule_action_override.value == "count" ? [1] : []
                  content {}
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.name
        sampled_requests_enabled   = true
      }
    }
  }

  # All rules
  dynamic "rule" {
    for_each = local.all_rules
    content {
      name     = rule.value.name
      priority = rule.value.priority

      action {
        dynamic "allow" {
          for_each = rule.value.action == "allow" ? [1] : []
          content {}
        }
        dynamic "block" {
          for_each = rule.value.action == "block" ? [1] : []
          content {
            dynamic "custom_response" {
              for_each = rule.value.response_code != null || rule.value.custom_response_body_key != null || length(rule.value.response_headers) > 0 ? [1] : []
              content {
                response_code            = rule.value.response_code
                custom_response_body_key = rule.value.custom_response_body_key

                dynamic "response_header" {
                  for_each = rule.value.response_headers
                  content {
                    name  = response_header.key
                    value = response_header.value
                  }
                }
              }
            }
          }
        }
        dynamic "count" {
          for_each = rule.value.action == "count" ? [1] : []
          content {}
        }
      }

      statement {
        # When negated, wrap the appropriate statement in not_statement
        dynamic "not_statement" {
          for_each = rule.value.negated && rule.value.statement_type == "rate_based" ? [rule.value] : []
          content {
            statement {
              dynamic "rate_based_statement" {
                for_each = [not_statement.value]
                content {
                  limit                 = rate_based_statement.value.limit
                  aggregate_key_type    = rate_based_statement.value.aggregate_key_type
                  evaluation_window_sec = rate_based_statement.value.evaluation_window_sec
                }
              }
            }
          }
        }

        dynamic "not_statement" {
          for_each = rule.value.negated && rule.value.statement_type == "ip_set" ? [rule.value] : []
          content {
            statement {
              dynamic "ip_set_reference_statement" {
                for_each = [not_statement.value]
                content {
                  arn = ip_set_reference_statement.value.ip_set_arn
                }
              }
            }
          }
        }

        dynamic "not_statement" {
          for_each = rule.value.negated && rule.value.statement_type == "geo_match" ? [rule.value] : []
          content {
            statement {
              dynamic "geo_match_statement" {
                for_each = [not_statement.value]
                content {
                  country_codes = geo_match_statement.value.country_codes
                }
              }
            }
          }
        }

        dynamic "not_statement" {
          for_each = (
            rule.value.negated && rule.value.statement_type == "size_constraint"
            && try(rule.value.field_to_match, null) != null
            && (
              try(rule.value.field_to_match, "") == "body"
              || try(rule.value.field_to_match, "") == "query_string"
              || try(rule.value.field_to_match, "") == "uri_path"
              || (try(rule.value.field_to_match, "") == "header"
              && try(trim(rule.value.header_name), "") != "")
            )
          ) ? [rule.value] : []
          content {
            statement {
              dynamic "size_constraint_statement" {
                for_each = [not_statement.value]
                content {
                  size                = size_constraint_statement.value.size
                  comparison_operator = size_constraint_statement.value.comparison_operator
                  dynamic "field_to_match" {
                    for_each = (
                      size_constraint_statement.value.field_to_match == "body"
                      || size_constraint_statement.value.field_to_match == "query_string"
                      || size_constraint_statement.value.field_to_match == "uri_path"
                      || (size_constraint_statement.value.field_to_match == "header" && try(trim(size_constraint_statement.value.header_name), "") != "")
                    ) ? [1] : []
                    content {
                      dynamic "body" {
                        for_each = size_constraint_statement.value.field_to_match == "body" ? [1] : []
                        content {}
                      }
                      dynamic "single_header" {
                        for_each = (
                          size_constraint_statement.value.field_to_match == "header"
                          && try(size_constraint_statement.value.header_name, null) != null
                          && try(trim(size_constraint_statement.value.header_name), "") != ""
                        ) ? [1] : []
                        content {
                          name = size_constraint_statement.value.header_name
                        }
                      }
                      dynamic "query_string" {
                        for_each = size_constraint_statement.value.field_to_match == "query_string" ? [1] : []
                        content {}
                      }
                      dynamic "uri_path" {
                        for_each = (try(size_constraint_statement.value.field_to_match, null) != null && try(size_constraint_statement.value.field_to_match, "") == "uri_path") ? [1] : []
                        content {}
                      }
                    }
                  }
                  text_transformation {
                    priority = 0
                    type     = "NONE"
                  }
                }
              }
            }
          }
        }

        dynamic "not_statement" {
          for_each = (
            rule.value.negated && rule.value.statement_type == "byte_match"
            && try(rule.value.search_string, null) != null
            && try(rule.value.search_string, "") != ""
            && try(rule.value.text_transformation, null) != null
            && try(rule.value.positional_constraint, null) != null
            && try(rule.value.field_to_match, null) != null
            && (
              try(rule.value.field_to_match, "") == "uri_path"
              || try(rule.value.field_to_match, "") == "query_string"
              || try(rule.value.field_to_match, "") == "method"
              || (try(rule.value.field_to_match, "") == "header"
              && try(trim(rule.value.header_name), "") != "")
            )
          ) ? [rule.value] : []
          content {
            statement {
              dynamic "byte_match_statement" {
                for_each = [not_statement.value]
                content {
                  search_string = byte_match_statement.value.search_string
                  dynamic "field_to_match" {
                    for_each = (
                      try(byte_match_statement.value.field_to_match, null) != null
                      && (
                        try(byte_match_statement.value.field_to_match, "") == "uri_path"
                        || try(byte_match_statement.value.field_to_match, "") == "query_string"
                        || try(byte_match_statement.value.field_to_match, "") == "method"
                        || (try(byte_match_statement.value.field_to_match, "") == "header" && try(trim(byte_match_statement.value.header_name), "") != "")
                      )
                    ) ? [1] : []
                    content {
                      dynamic "uri_path" {
                        for_each = (try(byte_match_statement.value.field_to_match, null) != null && try(byte_match_statement.value.field_to_match, "") == "uri_path") ? [1] : []
                        content {}
                      }
                      dynamic "query_string" {
                        for_each = (try(byte_match_statement.value.field_to_match, null) != null && try(byte_match_statement.value.field_to_match, "") == "query_string") ? [1] : []
                        content {}
                      }
                      dynamic "single_header" {
                        for_each = (
                          try(byte_match_statement.value.field_to_match, null) != null
                          && try(byte_match_statement.value.field_to_match, "") == "header"
                          && try(trim(byte_match_statement.value.header_name), "") != ""
                        ) ? [1] : []
                        content {
                          name = byte_match_statement.value.header_name
                        }
                      }
                      dynamic "method" {
                        for_each = byte_match_statement.value.field_to_match == "method" ? [1] : []
                        content {}
                      }
                    }
                  }
                  text_transformation {
                    priority = 0
                    type     = byte_match_statement.value.text_transformation
                  }
                  positional_constraint = byte_match_statement.value.positional_constraint
                }
              }
            }
          }
        }

        dynamic "not_statement" {
          for_each = (
            rule.value.negated && rule.value.statement_type == "regex_match"
            && try(rule.value.regex_string, null) != null
            && try(rule.value.regex_string, "") != ""
            && try(rule.value.field_to_match, null) != null
            && (
              try(rule.value.field_to_match, "") == "uri_path"
              || try(rule.value.field_to_match, "") == "query_string"
              || try(rule.value.field_to_match, "") == "method"
              || (try(rule.value.field_to_match, "") == "header"
              && try(trim(rule.value.header_name), "") != "")
            )
          ) ? [rule.value] : []
          content {
            statement {
              dynamic "regex_match_statement" {
                for_each = [not_statement.value]
                content {
                  regex_string = regex_match_statement.value.regex_string
                  dynamic "field_to_match" {
                    for_each = (
                      try(regex_match_statement.value.field_to_match, null) != null
                      && (
                        try(regex_match_statement.value.field_to_match, "") == "uri_path"
                        || try(regex_match_statement.value.field_to_match, "") == "query_string"
                        || try(regex_match_statement.value.field_to_match, "") == "method"
                        || (try(regex_match_statement.value.field_to_match, "") == "header" && try(trim(regex_match_statement.value.header_name), "") != "")
                      )
                    ) ? [1] : []
                    content {
                      dynamic "uri_path" {
                        for_each = (try(regex_match_statement.value.field_to_match, null) != null && try(regex_match_statement.value.field_to_match, "") == "uri_path") ? [1] : []
                        content {}
                      }
                      dynamic "query_string" {
                        for_each = (try(regex_match_statement.value.field_to_match, null) != null && try(regex_match_statement.value.field_to_match, "") == "query_string") ? [1] : []
                        content {}
                      }
                      dynamic "single_header" {
                        for_each = (
                          try(regex_match_statement.value.field_to_match, null) != null
                          && try(regex_match_statement.value.field_to_match, "") == "header"
                          && try(trim(regex_match_statement.value.header_name), "") != ""
                        ) ? [1] : []
                        content {
                          name = regex_match_statement.value.header_name
                        }
                      }
                      dynamic "method" {
                        for_each = regex_match_statement.value.field_to_match == "method" ? [1] : []
                        content {}
                      }
                    }
                  }
                  text_transformation {
                    priority = 0
                    type     = "NONE"
                  }
                }
              }
            }
          }
        }

        # Direct statements (when not negated)
        dynamic "rate_based_statement" {
          for_each = !rule.value.negated && rule.value.statement_type == "rate_based" ? [rule.value] : []
          content {
            limit                 = rate_based_statement.value.limit
            aggregate_key_type    = rate_based_statement.value.aggregate_key_type
            evaluation_window_sec = rate_based_statement.value.evaluation_window_sec
          }
        }

        dynamic "ip_set_reference_statement" {
          for_each = !rule.value.negated && rule.value.statement_type == "ip_set" ? [rule.value] : []
          content {
            arn = ip_set_reference_statement.value.ip_set_arn
          }
        }

        dynamic "geo_match_statement" {
          for_each = !rule.value.negated && rule.value.statement_type == "geo_match" ? [rule.value] : []
          content {
            country_codes = geo_match_statement.value.country_codes
          }
        }

        dynamic "size_constraint_statement" {
          for_each = (
            !rule.value.negated && rule.value.statement_type == "size_constraint"
            && try(rule.value.field_to_match, null) != null
            && (
              try(rule.value.field_to_match, "") == "body"
              || try(rule.value.field_to_match, "") == "query_string"
              || try(rule.value.field_to_match, "") == "uri_path"
              || (try(rule.value.field_to_match, "") == "header"
              && try(trim(rule.value.header_name), "") != "")
            )
          ) ? [rule.value] : []
          content {
            size                = size_constraint_statement.value.size
            comparison_operator = size_constraint_statement.value.comparison_operator
            dynamic "field_to_match" {
              for_each = (
                size_constraint_statement.value.field_to_match == "body"
                || size_constraint_statement.value.field_to_match == "query_string"
                || size_constraint_statement.value.field_to_match == "uri_path"
                || (size_constraint_statement.value.field_to_match == "header" && try(trim(size_constraint_statement.value.header_name), "") != "")
              ) ? [1] : []
              content {
                dynamic "body" {
                  for_each = size_constraint_statement.value.field_to_match == "body" ? [1] : []
                  content {}
                }
                dynamic "single_header" {
                  for_each = (
                    size_constraint_statement.value.field_to_match == "header"
                    && try(size_constraint_statement.value.header_name, null) != null
                    && try(trim(size_constraint_statement.value.header_name), "") != ""
                  ) ? [1] : []
                  content {
                    name = size_constraint_statement.value.header_name
                  }
                }
                dynamic "query_string" {
                  for_each = size_constraint_statement.value.field_to_match == "query_string" ? [1] : []
                  content {}
                }
                dynamic "uri_path" {
                  for_each = (try(size_constraint_statement.value.field_to_match, null) != null && try(size_constraint_statement.value.field_to_match, "") == "uri_path") ? [1] : []
                  content {}
                }
              }
            }
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }

        dynamic "byte_match_statement" {
          for_each = (
            !rule.value.negated && rule.value.statement_type == "byte_match"
            && try(rule.value.search_string, null) != null
            && try(rule.value.search_string, "") != ""
            && try(rule.value.text_transformation, null) != null
            && try(rule.value.positional_constraint, null) != null
            && try(rule.value.field_to_match, null) != null
            && (
              try(rule.value.field_to_match, "") == "uri_path"
              || try(rule.value.field_to_match, "") == "query_string"
              || try(rule.value.field_to_match, "") == "method"
              || (try(rule.value.field_to_match, "") == "header"
              && try(trim(rule.value.header_name), "") != "")
            )
          ) ? [rule.value] : []
          content {
            search_string = rule.value.search_string
            dynamic "field_to_match" {
              for_each = (
                try(rule.value.field_to_match, null) != null
                && (
                  try(rule.value.field_to_match, "") == "uri_path"
                  || try(rule.value.field_to_match, "") == "query_string"
                  || try(rule.value.field_to_match, "") == "method"
                  || (try(rule.value.field_to_match, "") == "header" && try(trim(rule.value.header_name), "") != "")
                )
              ) ? [1] : []
              content {
                dynamic "uri_path" {
                  for_each = (try(rule.value.field_to_match, null) != null && try(rule.value.field_to_match, "") == "uri_path") ? [1] : []
                  content {}
                }
                dynamic "query_string" {
                  for_each = (try(rule.value.field_to_match, null) != null && try(rule.value.field_to_match, "") == "query_string") ? [1] : []
                  content {}
                }
                dynamic "single_header" {
                  for_each = (
                    try(rule.value.field_to_match, null) != null
                    && try(rule.value.field_to_match, "") == "header"
                    && try(trim(rule.value.header_name), "") != ""
                  ) ? [1] : []
                  content {
                    name = rule.value.header_name
                  }
                }
                dynamic "method" {
                  for_each = rule.value.field_to_match == "method" ? [1] : []
                  content {}
                }
              }
            }
            text_transformation {
              priority = 0
              type     = rule.value.text_transformation
            }
            positional_constraint = rule.value.positional_constraint
          }
        }

        dynamic "regex_match_statement" {
          for_each = (
            !rule.value.negated && rule.value.statement_type == "regex_match"
            && try(rule.value.regex_string, null) != null
            && try(rule.value.regex_string, "") != ""
            && try(rule.value.field_to_match, null) != null
            && (
              try(rule.value.field_to_match, "") == "uri_path"
              || try(rule.value.field_to_match, "") == "query_string"
              || try(rule.value.field_to_match, "") == "method"
              || (try(rule.value.field_to_match, "") == "header"
              && try(trim(rule.value.header_name), "") != "")
            )
          ) ? [rule.value] : []
          content {
            regex_string = rule.value.regex_string
            dynamic "field_to_match" {
              for_each = (
                try(rule.value.field_to_match, null) != null
                && (
                  try(rule.value.field_to_match, "") == "uri_path"
                  || try(rule.value.field_to_match, "") == "query_string"
                  || try(rule.value.field_to_match, "") == "method"
                  || (try(rule.value.field_to_match, "") == "header" && try(trim(rule.value.header_name), "") != "")
                )
              ) ? [1] : []
              content {
                dynamic "uri_path" {
                  for_each = (try(rule.value.field_to_match, null) != null && try(rule.value.field_to_match, "") == "uri_path") ? [1] : []
                  content {}
                }
                dynamic "query_string" {
                  for_each = (try(rule.value.field_to_match, null) != null && try(rule.value.field_to_match, "") == "query_string") ? [1] : []
                  content {}
                }
                dynamic "single_header" {
                  for_each = (
                    try(rule.value.field_to_match, null) != null
                    && try(rule.value.field_to_match, "") == "header"
                    && try(trim(rule.value.header_name), "") != ""
                  ) ? [1] : []
                  content {
                    name = rule.value.header_name
                  }
                }
                dynamic "method" {
                  for_each = rule.value.field_to_match == "method" ? [1] : []
                  content {}
                }
              }
            }
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.name
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.name_prefix
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

# CloudWatch Log Group for WAF logs (optional) - with destroy protection
resource "aws_cloudwatch_log_group" "waf_logs" {
  count = var.logging.enabled && var.logging.cloudwatch_log_group_name != null && var.logging.destroy_log_group == false ? 1 : 0

  name              = var.logging.cloudwatch_log_group_name
  retention_in_days = var.logging.cloudwatch_retention_days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-waf-logs"
  })

  lifecycle {
    prevent_destroy = true
  }
}

# CloudWatch Log Group for WAF logs (optional) - without destroy protection
resource "aws_cloudwatch_log_group" "waf_logs_destroyable" {
  count = var.logging.enabled && var.logging.cloudwatch_log_group_name != null && var.logging.destroy_log_group == true ? 1 : 0

  name              = var.logging.cloudwatch_log_group_name
  retention_in_days = var.logging.cloudwatch_retention_days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-waf-logs"
  })
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  count = var.logging.enabled ? 1 : 0

  resource_arn            = aws_wafv2_web_acl.main.arn
  log_destination_configs = local.waf_log_destinations

  dynamic "redacted_fields" {
    for_each = toset(local.waf_redacted_fields)
    content {
      single_header {
        name = redacted_fields.value
      }
    }
  }

  # Logging filter configuration
  dynamic "logging_filter" {
    for_each = try(var.logging.logging_filter, null) != null ? [var.logging.logging_filter] : []
    content {
      default_behavior = logging_filter.value.default_behavior

      dynamic "filter" {
        for_each = try(logging_filter.value.filters, [])
        content {
          behavior    = filter.value.behavior
          requirement = filter.value.requirement

          dynamic "condition" {
            for_each = filter.value.conditions
            content {
              dynamic "action_condition" {
                for_each = try(condition.value.action_condition, null) != null ? [condition.value.action_condition] : []
                content {
                  action = action_condition.value.action
                }
              }

              dynamic "label_name_condition" {
                for_each = try(condition.value.label_name_condition, null) != null ? [condition.value.label_name_condition] : []
                content {
                  label_name = label_name_condition.value.label_name
                }
              }
            }
          }
        }
      }
    }
  }
}

# IAM role policy for WAF to write to Kinesis Data Firehose
resource "aws_iam_role_policy" "waf_firehose_logging" {
  count = var.logging.enabled && try(var.logging.kinesis_firehose_arn, null) != null ? 1 : 0

  name = "${var.name_prefix}-waf-firehose-logging-policy"
  role = try(var.logging.kinesis_firehose_role_arn, null) != null ? split("/", var.logging.kinesis_firehose_role_arn)[1] : null

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "firehose:PutRecord",
          "firehose:PutRecordBatch"
        ]
        Resource = var.logging.kinesis_firehose_arn
      }
    ]
  })
}

# CloudWatch alarms for each rule
resource "aws_cloudwatch_metric_alarm" "rule_alarms" {
  for_each = var.enable_monitoring ? {
    for rule in var.rules : rule.name => rule
  } : {}

  alarm_name          = "${var.name_prefix}-${each.value.name}-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.alarm_threshold
  alarm_description   = "WAF rule ${each.value.name} blocked ${var.alarm_threshold}+ requests in 5 minutes"
  alarm_actions       = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = aws_wafv2_web_acl.main.name
    Rule   = each.value.name
  }

  tags = var.tags
}

# CloudWatch dashboard
resource "aws_cloudwatch_dashboard" "waf_dashboard" {
  count = var.enable_monitoring ? 1 : 0

  dashboard_name = "${var.name_prefix}-waf-dashboard"

  dashboard_body = jsonencode({
    widgets = concat([
      # Overview widget
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 24
        height = 6
        properties = {
          metrics = [
            ["AWS/WAFV2", "BlockedRequests", "WebACL", aws_wafv2_web_acl.main.name],
            [".", "AllowedRequests", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.region
          title   = "WAF Overview - ${var.name_prefix}"
          period  = 300
        }
      }
      ], [
      # Individual rule widgets (2 per row)
      for i, rule in var.rules : {
        type   = "metric"
        x      = (i % 2) * 12
        y      = 6 + (i / 2) * 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/WAFV2", "BlockedRequests", "WebACL", aws_wafv2_web_acl.main.name, "Rule", rule.name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.region
          title   = "Rule: ${rule.name}"
          period  = 300
        }
      }
    ])
  })
}
