# Outputs
output "web_acl_id" {
  description = "ID of the Web ACL"
  value       = aws_wafv2_web_acl.main.id
}

output "web_acl_arn" {
  description = "ARN of the Web ACL"
  value       = aws_wafv2_web_acl.main.arn
}

output "web_acl_name" {
  description = "Name of the Web ACL"
  value       = aws_wafv2_web_acl.main.name
}

output "ip_set_arns" {
  description = "Map of IP set names to their ARNs"
  value = {
    for name, ip_set in aws_wafv2_ip_set.sets : name => ip_set.arn
  }
}

output "rule_alarms" {
  description = "Map of rule names to CloudWatch alarm ARNs"
  value = {
    for name, alarm in aws_cloudwatch_metric_alarm.rule_alarms : name => alarm.arn
  }
}

output "dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = var.enable_monitoring ? aws_cloudwatch_dashboard.waf_dashboard[0].dashboard_name : null
}

output "dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = var.enable_monitoring ? "https://${data.aws_region.current.region}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.region}#dashboards:name=${aws_cloudwatch_dashboard.waf_dashboard[0].dashboard_name}" : null
}
