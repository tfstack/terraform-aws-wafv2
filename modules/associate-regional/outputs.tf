output "association_ids" {
  description = "Map of resource ARN to association ID"
  value = {
    for i, association in aws_wafv2_web_acl_association.main : var.resource_arns[i] => association.id
  }
}

output "web_acl_arn" {
  description = "ARN of the associated Web ACL"
  value       = var.web_acl_arn
}

output "associated_resources" {
  description = "List of associated resource ARNs"
  value       = var.resource_arns
}
