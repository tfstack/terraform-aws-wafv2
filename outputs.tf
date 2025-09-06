# Web ACL outputs
output "web_acl_id" {
  description = "ID of the Web ACL"
  value       = module.web_acl.web_acl_id
}

output "web_acl_arn" {
  description = "ARN of the Web ACL"
  value       = module.web_acl.web_acl_arn
}

output "web_acl_name" {
  description = "Name of the Web ACL"
  value       = module.web_acl.web_acl_name
}

# Association outputs (only if associations were created)
output "association_ids" {
  description = "Map of resource ARN to association ID"
  value       = length(module.association) > 0 ? module.association[0].association_ids : {}
}

output "associated_resources" {
  description = "List of associated resource ARNs"
  value       = length(module.association) > 0 ? module.association[0].associated_resources : []
}

output "ip_set_arns" {
  description = "Map of IP set names to their ARNs"
  value       = module.web_acl.ip_set_arns
}

output "rule_alarms" {
  description = "WAF CloudWatch alarms"
  value       = module.web_acl.rule_alarms
}

output "dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.web_acl.dashboard_url
}
