# WAF Rate Limiting with Exclusions Example

This example demonstrates AWS WAFv2 rate limiting with IP exclusions, custom response bodies, CloudWatch monitoring, and alerting.

## Features

- **Rate Limiting**: 10 requests per 5 minutes per IP
- **IP Exclusions**: Specific IPs can bypass rate limiting
- **IP Blocking**: Specific IPs can be blocked immediately
- **Custom Response Bodies**: JSON responses for blocked/rate-limited requests
- **CloudWatch Monitoring**: Alarms and dashboard for all rules
- **SNS Alerts**: Email notifications for rule violations

## Architecture

```plaintext
Internet → ALB → WAF → Target
                ↓
            CloudWatch
                ↓
            SNS Alerts
```

## Rule Priority

1. **Priority 10**: Block specific IPs (immediate block with 403 + custom JSON)
2. **Priority 20**: Allow specific IPs (bypasses rate limiting)
3. **Priority 100**: Rate limit all other IPs (429 + custom JSON)

## Custom Response Bodies

The example includes custom JSON responses for different scenarios:

### Blocked IP Response (403)

```json
{
  "error": "Access Denied",
  "message": "Your IP address has been blocked",
  "code": "BLOCKED_IP",
  "timestamp": "$context.requestTime"
}
```

### Rate Limited Response (429)

```json
{
  "error": "Rate Limit Exceeded",
  "message": "Too many requests. Please try again later.",
  "code": "RATE_LIMITED",
  "retry_after": "300",
  "timestamp": "$context.requestTime"
}
```

## Usage

1. **Deploy**:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

2. **Test**:

   ```bash
   chmod +x test-waf.sh
   ./test-waf.sh
   ```

3. **Monitor**:
   - View dashboard: `terraform output -raw dashboard_url`
   - Check alarms in CloudWatch console

## Configuration

- **Allowed IPs**: `203.0.113.0/24`, `198.51.100.0/24` (bypass rate limiting)
- **Blocked IPs**: `10.0.0.100/32` (immediate block with 403 response)
- **Rate Limit**: 10 requests per 5 minutes per IP
- **Rate Limit Response**: 429 with custom JSON body
- **Alarm Threshold**: 10 blocked requests per 5 minutes

## Customization

Edit `variables.tf` to customize:

- IP addresses
- Rate limits
- Alarm thresholds
- Email notifications

## Monitoring

This example includes comprehensive monitoring:

- **CloudWatch Alarms**: One alarm per rule
- **CloudWatch Dashboard**: Overview and per-rule metrics
- **SNS Notifications**: Email alerts for rule violations

## Testing

The included test script validates:

- Basic requests are allowed (200 response)
- Rate limiting triggers after 10 requests (429 response)
- Custom response bodies are returned for rate-limited requests
- WAF logs show blocked requests
- CloudWatch monitoring is working

### Test Script Features

- **Multiple Attempts**: Tests rate limiting with retry logic
- **Custom Response Validation**: Checks for JSON response bodies
- **WAF Log Analysis**: Verifies blocking in CloudWatch logs
- **Progress Indicators**: Shows test progress and results
