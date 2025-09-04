# Main WAFv2 module that combines web-acl and association functionality

# Create Web ACL
module "web_acl" {
  source = "./modules/web-acl"

  name_prefix            = var.name_prefix
  description            = var.description
  scope                  = var.scope
  default_action         = var.default_action
  managed_rule_sets      = var.managed_rule_sets
  rules                  = var.rules
  ip_sets                = var.ip_sets
  logging                = var.logging
  enable_monitoring      = var.enable_monitoring
  alarm_sns_topic_arn    = var.alarm_sns_topic_arn
  alarm_threshold        = var.alarm_threshold
  custom_response_bodies = var.custom_response_bodies
  tags                   = var.tags
}

# Associate Web ACL with resources (if provided)
module "association" {
  count = length(var.resource_arns) > 0 ? 1 : 0

  source = "./modules/associate-regional"

  web_acl_arn   = module.web_acl.web_acl_arn
  resource_arns = var.resource_arns
}
