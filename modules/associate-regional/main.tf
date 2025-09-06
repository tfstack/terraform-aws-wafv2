# Associate Web ACL with regional resources (ALBs)
resource "aws_wafv2_web_acl_association" "main" {
  count = length(var.resource_arns)

  resource_arn = var.resource_arns[count.index]
  web_acl_arn  = var.web_acl_arn
}
