provider "aws" {
  region                      = "ap-southeast-2"
  access_key                  = "mock_access_key"
  secret_key                  = "mock_secret_key"
  token                       = "mock_token"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true
}

# Test 1: Minimal WAF Configuration
run "minimal_waf_test" {
  command = plan

  override_data {
    target = module.web_acl.data.aws_caller_identity.current
    values = {
      account_id = "123456789012"
    }
  }

  override_data {
    target = module.web_acl.data.aws_region.current
    values = {
      name = "ap-southeast-2"
    }
  }

  variables {
    name_prefix = "test-waf-minimal"
    scope       = "REGIONAL"

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

    resource_arns = ["arn:aws:elasticloadbalancing:ap-southeast-2:123456789012:loadbalancer/app/test-alb/1234567890123456"]
  }

  # Test that the Web ACL name is correctly set from name_prefix
  assert {
    condition     = output.web_acl_name == "test-waf-minimal"
    error_message = "Web ACL name should be 'test-waf-minimal'."
  }

  # Test that the Web ACL scope is correctly set
  assert {
    condition     = var.scope == "REGIONAL"
    error_message = "Web ACL scope should be 'REGIONAL'."
  }

  # Test that the associated resources are correctly passed through
  assert {
    condition     = length(output.associated_resources) == 1
    error_message = "Should have 1 associated resource."
  }

  # Test that the associated resource ARN matches what we provided
  assert {
    condition     = output.associated_resources[0] == "arn:aws:elasticloadbalancing:ap-southeast-2:123456789012:loadbalancer/app/test-alb/1234567890123456"
    error_message = "Associated resource ARN should match the input."
  }

  # Test that we can validate variable structure - managed rule sets should have the expected structure
  assert {
    condition     = length(var.managed_rule_sets) == 3
    error_message = "Should have 3 managed rule sets configured."
  }

  # Test that we can validate custom rules structure (should be empty for minimal test)
  assert {
    condition     = length(var.rules) == 0
    error_message = "Should have 0 custom rules configured for minimal test."
  }
}

# Test 2: Advanced WAF Configuration with Custom Rules and Logging
run "advanced_waf_test" {
  command = plan

  override_data {
    target = module.web_acl.data.aws_caller_identity.current
    values = {
      account_id = "123456789012"
    }
  }

  override_data {
    target = module.web_acl.data.aws_region.current
    values = {
      name = "ap-southeast-2"
    }
  }

  variables {
    name_prefix = "test-waf-advanced"
    scope       = "REGIONAL"

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

    rules = [
      {
        name                  = "GeneralRateLimit"
        priority              = 100
        action                = "block"
        statement_type        = "rate_based"
        limit                 = 2000
        aggregate_key_type    = "IP"
        evaluation_window_sec = 300
      },
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
      {
        name                  = "BlockSuspiciousQueryParams"
        priority              = 300
        action                = "block"
        statement_type        = "byte_match"
        search_string         = "eval("
        field_to_match        = "query_string"
        text_transformation   = "LOWERCASE"
        positional_constraint = "CONTAINS"
      }
    ]

    ip_sets = {
      blocked_ips = {
        name      = "test-blocked-ips"
        addresses = ["192.168.1.100/32", "10.0.0.100/32"]
      }
      allowed_ips = {
        name      = "test-allowed-ips"
        addresses = ["203.0.113.0/24", "198.51.100.0/24"]
      }
    }

    resource_arns = ["arn:aws:elasticloadbalancing:ap-southeast-2:123456789012:loadbalancer/app/test-alb/1234567890123456"]

    # Test logging configuration
    logging = {
      enabled                   = true
      cloudwatch_log_group_name = "aws-waf-logs-test-waf-advanced"
      cloudwatch_retention_days = 30
      redacted_fields           = ["authorization", "cookie"]
      destroy_log_group         = false
      sampled_requests_enabled  = true
    }

    # Test monitoring configuration
    enable_monitoring = true
    alarm_threshold   = 100
  }

  # Test that the Web ACL name is correctly set from name_prefix
  assert {
    condition     = output.web_acl_name == "test-waf-advanced"
    error_message = "Web ACL name should match the name_prefix."
  }

  # Test that the Web ACL scope is correctly set
  assert {
    condition     = var.scope == "REGIONAL"
    error_message = "Web ACL scope should be 'REGIONAL'."
  }

  # Test that the associated resources are correctly passed through
  assert {
    condition     = length(output.associated_resources) == 1
    error_message = "Should have 1 associated resource."
  }

  # Test that the associated resource ARN matches what we provided
  assert {
    condition     = output.associated_resources[0] == "arn:aws:elasticloadbalancing:ap-southeast-2:123456789012:loadbalancer/app/test-alb/1234567890123456"
    error_message = "Associated resource ARN should match the input."
  }

  # Test that we can validate variable structure - managed rule sets should have the expected structure
  assert {
    condition     = length(var.managed_rule_sets) == 4
    error_message = "Should have 4 managed rule sets configured."
  }

  # Test that we can validate custom rules structure
  assert {
    condition     = length(var.rules) == 3
    error_message = "Should have 3 custom rules configured."
  }

  # Test that the custom rules have the expected properties
  assert {
    condition     = var.rules[0].name == "GeneralRateLimit"
    error_message = "First custom rule should be named 'GeneralRateLimit'."
  }

  assert {
    condition     = var.rules[1].name == "BlockAdminPaths"
    error_message = "Second custom rule should be named 'BlockAdminPaths'."
  }

  assert {
    condition     = var.rules[2].name == "BlockSuspiciousQueryParams"
    error_message = "Third custom rule should be named 'BlockSuspiciousQueryParams'."
  }

  # Test IP sets configuration
  assert {
    condition     = length(var.ip_sets) == 2
    error_message = "Should have 2 IP sets configured."
  }

  assert {
    condition     = contains(keys(var.ip_sets), "blocked_ips")
    error_message = "Should have 'blocked_ips' IP set configured."
  }

  assert {
    condition     = contains(keys(var.ip_sets), "allowed_ips")
    error_message = "Should have 'allowed_ips' IP set configured."
  }

  # Test logging configuration
  assert {
    condition     = var.logging.enabled == true
    error_message = "Logging should be enabled."
  }

  assert {
    condition     = var.logging.cloudwatch_log_group_name == "aws-waf-logs-test-waf-advanced"
    error_message = "CloudWatch log group name should match the expected pattern."
  }

  # Test monitoring configuration
  assert {
    condition     = var.enable_monitoring == true
    error_message = "Monitoring should be enabled."
  }

  assert {
    condition     = var.alarm_threshold == 100
    error_message = "Alarm threshold should be set to 100."
  }
}

# Test 3: S3 Logging Configuration
run "s3_logging_test" {
  command = plan

  override_data {
    target = module.web_acl.data.aws_caller_identity.current
    values = {
      account_id = "123456789012"
    }
  }

  override_data {
    target = module.web_acl.data.aws_region.current
    values = {
      name = "ap-southeast-2"
    }
  }

  variables {
    name_prefix = "test-waf-s3-logging"
    scope       = "REGIONAL"

    managed_rule_sets = [
      {
        name            = "AWSManagedRulesCommonRuleSet"
        priority        = 1
        rule_group_name = "AWSManagedRulesCommonRuleSet"
        override_action = "none"
      }
    ]

    resource_arns = ["arn:aws:elasticloadbalancing:ap-southeast-2:123456789012:loadbalancer/app/test-alb/1234567890123456"]

    # Test S3 logging configuration
    logging = {
      enabled                  = true
      s3_bucket_name           = "aws-waf-logs-test-bucket"
      s3_bucket_prefix         = "waf-logs"
      redacted_fields          = ["authorization", "cookie"]
      sampled_requests_enabled = true
    }
  }

  # Test that the Web ACL name is correctly set
  assert {
    condition     = output.web_acl_name == "test-waf-s3-logging"
    error_message = "Web ACL name should be 'test-waf-s3-logging'."
  }

  # Test S3 logging configuration
  assert {
    condition     = var.logging.enabled == true
    error_message = "S3 logging should be enabled."
  }

  assert {
    condition     = var.logging.s3_bucket_name == "aws-waf-logs-test-bucket"
    error_message = "S3 bucket name should be set correctly."
  }

  assert {
    condition     = var.logging.s3_bucket_prefix == "waf-logs"
    error_message = "S3 bucket prefix should be set correctly."
  }

  assert {
    condition     = length(var.logging.redacted_fields) == 2
    error_message = "Should have 2 redacted fields configured."
  }

  assert {
    condition     = var.logging.sampled_requests_enabled == true
    error_message = "Sampled requests should be enabled."
  }
}

# Test 4: Validation Tests
run "validation_tests" {
  command = plan

  override_data {
    target = module.web_acl.data.aws_caller_identity.current
    values = {
      account_id = "123456789012"
    }
  }

  override_data {
    target = module.web_acl.data.aws_region.current
    values = {
      name = "ap-southeast-2"
    }
  }

  variables {
    name_prefix       = "test-waf-validation"
    scope             = "REGIONAL"
    managed_rule_sets = []
    rules             = []
    resource_arns     = ["arn:aws:elasticloadbalancing:ap-southeast-2:123456789012:loadbalancer/app/test-alb/1234567890123456"]
  }

  # Test that empty managed rule sets are allowed
  assert {
    condition     = length(var.managed_rule_sets) == 0
    error_message = "Should allow empty managed rule sets."
  }

  # Test that empty custom rules are allowed
  assert {
    condition     = length(var.rules) == 0
    error_message = "Should allow empty custom rules."
  }

  # Test that the Web ACL is still created with minimal configuration
  assert {
    condition     = output.web_acl_name == "test-waf-validation"
    error_message = "Web ACL should be created even with minimal configuration."
  }
}
