variable "web_acl_arn" {
  description = "ARN of the Web ACL to associate"
  type        = string
}

variable "resource_arns" {
  description = "List of resource ARNs to associate with the Web ACL (ALBs, API Gateways, etc.)"
  type        = list(string)
}
