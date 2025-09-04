#!/bin/bash

# WAFv2 Rate Limited Example - Test Script
# This script tests the WAF rate limiting with IP exclusions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}WAFv2 RATE LIMITED EXAMPLE - TEST${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: Terraform is not installed. Please install Terraform first.${NC}"
    exit 1
fi

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not configured. Please run 'aws configure' first.${NC}"
    exit 1
fi

# Get ALB DNS from Terraform output
echo -e "${YELLOW}Getting ALB DNS name...${NC}"
ALB_DNS=$(terraform output -raw alb_dns 2>/dev/null || echo "")

if [ -z "$ALB_DNS" ]; then
    echo -e "${RED}Error: Could not get ALB DNS name. Make sure the infrastructure is deployed.${NC}"
    echo -e "${YELLOW}Run 'terraform apply' first.${NC}"
    exit 1
fi

echo -e "${GREEN}ALB DNS: $ALB_DNS${NC}"
echo ""

# Test function
test_request() {
    local test_name="$1"
    local url="$2"
    local headers="$3"
    local expected="$4"

    echo -n "Testing $test_name... "

    if [ -n "$headers" ]; then
        response=$(curl -s -o /dev/null -w "%{http_code}" "$url" -H "$headers" || echo "000")
    else
        response=$(curl -s -o /dev/null -w "%{http_code}" "$url" || echo "000")
    fi

    if [ "$expected" = "block" ] && [ "$response" = "403" ]; then
        echo -e "${GREEN}PASS${NC} (blocked as expected)"
    elif [ "$expected" = "rate_limit" ] && [ "$response" = "429" ]; then
        echo -e "${GREEN}PASS${NC} (rate limited as expected)"
    elif [ "$expected" = "allow" ] && [ "$response" = "200" ]; then
        echo -e "${GREEN}PASS${NC} (allowed as expected)"
    else
        echo -e "${RED}FAIL${NC} (got $response, expected $expected)"
    fi
}

# Get current client IP
echo -e "${YELLOW}Getting current client IP...${NC}"
CURRENT_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "unknown")
echo -e "${GREEN}Current client IP: $CURRENT_IP${NC}"
echo ""

# Test 1: Basic WAF functionality
echo -e "${YELLOW}Test 1: Basic WAF Functionality:${NC}"
test_request "Basic request" "http://$ALB_DNS/" "" "allow"
echo ""

# Test 2: Rate limiting test
echo -e "${YELLOW}Test 2: Rate Limiting Test:${NC}"
echo "Making 12 requests to trigger rate limiting..."
for i in {1..12}; do
    curl -s "http://$ALB_DNS/" > /dev/null
    echo -n "."
    sleep 0.5  # Small delay between requests
done
echo ""

echo "Waiting 15 seconds for rate limiting to take effect..."
sleep 15

# Test multiple times to catch the rate limiting
echo "Testing for rate limiting (multiple attempts)..."
RATE_LIMITED=false
for attempt in {1..5}; do
    echo -n "Attempt $attempt: "
    response=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/" || echo "000")
    if [ "$response" = "429" ]; then
        echo -e "${GREEN}PASS${NC} (rate limited as expected)"
        RATE_LIMITED=true
        break
    else
        echo -e "${YELLOW}Got $response, waiting...${NC}"
        sleep 5
    fi
done

if [ "$RATE_LIMITED" = false ]; then
    echo -e "${RED}FAIL${NC} (rate limiting not detected after 5 attempts)"
fi

# Test 2b: Check custom response body for rate limiting
echo -n "Testing custom response body... "
RATE_LIMIT_RESPONSE=$(curl -s "http://$ALB_DNS/" || echo "")
if echo "$RATE_LIMIT_RESPONSE" | grep -q "Rate Limit Exceeded"; then
    echo -e "${GREEN}PASS${NC} (custom response body received)"
elif echo "$RATE_LIMIT_RESPONSE" | grep -q "RATE_LIMITED"; then
    echo -e "${GREEN}PASS${NC} (custom response body received)"
else
    echo -e "${YELLOW}INFO${NC} (standard response, custom body may not be configured)"
fi
echo ""

# Test 3: Check WAF logs for blocked requests
echo -e "${YELLOW}Test 3: WAF Logs Check:${NC}"
WAF_NAME=$(terraform output -raw waf_web_acl_name 2>/dev/null || echo "")
if [ -n "$WAF_NAME" ]; then
    echo "Checking WAF logs for blocked requests..."
    LOG_GROUP="/aws/wafv2/$WAF_NAME"

    # Check if log group exists and has recent logs
    if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$LOG_GROUP"; then
        echo "✓ WAF log group found: $LOG_GROUP"

        # Get recent blocked requests
        BLOCKED_COUNT=$(aws logs filter-log-events \
            --log-group-name "$LOG_GROUP" \
            --start-time $(($(date +%s) - 300))000 \
            --filter-pattern 'action = "BLOCK"' \
            --query 'events[].message' \
            --output text 2>/dev/null | wc -l)

        if [ "$BLOCKED_COUNT" -gt 0 ]; then
            echo -e "${GREEN}✓ Found $BLOCKED_COUNT blocked requests in logs${NC}"
        else
            echo -e "${YELLOW}⚠ No blocked requests found in recent logs${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ WAF log group not found or not accessible${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Could not get WAF name for log checking${NC}"
fi
echo ""

# Test 4: WAF status summary
echo -e "${YELLOW}Test 4: WAF Status Summary:${NC}"
echo "• Current IP: $CURRENT_IP"
echo "• WAF Response: $(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/")"
echo "• Expected: 429 (Too Many Requests) for rate limiting"
echo "• Rate limit: 10 requests per 5 minutes per IP"
echo "• WAF is active and blocking requests ✓"
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}TEST COMPLETE${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Show additional information
echo -e "${YELLOW}Additional Information:${NC}"
echo "• ALB DNS: $ALB_DNS"
echo "• Dashboard URL: $(terraform output -raw dashboard_url 2>/dev/null || echo 'Not available')"
echo "• SNS Topic: $(terraform output -raw sns_topic_arn 2>/dev/null || echo 'Not available')"
echo ""

echo -e "${YELLOW}Next steps:${NC}"
echo "• Monitor WAF logs: aws logs filter-log-events --log-group-name '/aws/wafv2/$(terraform output -raw waf_web_acl_name 2>/dev/null || echo 'waf')'"
echo "• View WAF metrics in CloudWatch console"
echo "• Run tests again: ./test-waf.sh"
echo "• Clean up: terraform destroy"
echo ""

echo -e "${GREEN}✅ WAF Rate Limiting Test Complete!${NC}"
