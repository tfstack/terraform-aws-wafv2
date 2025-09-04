# Associate Regional Module

This module associates a WAFv2 Web ACL with regional AWS resources such as Application Load Balancers, API Gateways, or AppSync APIs.

## Features

- Associate Web ACL with multiple resources
- Support for regional resources (ALB, API Gateway, AppSync)
- Automatic association ID tracking
- Flexible resource ARN input

## Usage

```hcl
module "waf_association" {
  source = "./modules/associate-regional"

  web_acl_arn   = "arn:aws:wafv2:ap-southeast-2:123456789012:regional/webacl/example/12345678-1234-1234-1234-123456789012"
  resource_arns = [
    "arn:aws:elasticloadbalancing:ap-southeast-2:123456789012:loadbalancer/app/my-alb/1234567890123456",
    "arn:aws:apigateway:ap-southeast-2::/restapis/1234567890/stages/prod"
  ]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| web_acl_arn | ARN of the Web ACL to associate | `string` | n/a | yes |
| resource_arns | List of resource ARNs to associate with the Web ACL | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| association_ids | Map of resource ARN to association ID |
| web_acl_arn | ARN of the associated Web ACL |
| associated_resources | List of associated resource ARNs |

## Supported Resources

This module supports the following AWS resources:

- **Application Load Balancer (ALB)**: `arn:aws:elasticloadbalancing:region:account:loadbalancer/app/name/id`
- **API Gateway REST API**: `arn:aws:apigateway:region::/restapis/api-id/stages/stage-name`
- **API Gateway HTTP API**: `arn:aws:apigateway:region::/apis/api-id/stages/stage-name`
- **AppSync GraphQL API**: `arn:aws:appsync:region:account:apis/api-id`

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.40.0 |

## Notes

- All resources must be in the same region as the Web ACL
- For CloudFront distributions, use the distribution's `web_acl_id` parameter instead of this module
- Each resource can only be associated with one Web ACL at a time
