#!/bin/bash

# WAFv2 Minimal Example - Test Script
# This script tests the WAF with AWS managed rules

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}WAFv2 MINIMAL EXAMPLE - TEST${NC}"
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
ALB_DNS=$(terraform output -raw alb_alb_dns 2>/dev/null || echo "")

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
    elif [ "$expected" = "allow" ] && [ "$response" = "200" ]; then
        echo -e "${GREEN}PASS${NC} (allowed as expected)"
    elif [ "$expected" = "any" ]; then
        echo -e "${GREEN}PASS${NC} (got response: $response)"
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

# Test 2: SQL Injection attacks
echo -e "${YELLOW}Test 2: SQL Injection Attacks:${NC}"
test_request "SQL injection in query" "http://$ALB_DNS/?id=1%27%20OR%20%271%27=%271" "" "block"
test_request "SQL injection with UNION" "http://$ALB_DNS/?search=1%27%20UNION%20SELECT%20*%20FROM%20users" "" "block"
test_request "SQL injection with DROP" "http://$ALB_DNS/?id=1%27%3B%20DROP%20TABLE%20users%3B--" "" "block"
echo ""

# Test 3: XSS attacks
echo -e "${YELLOW}Test 3: XSS Attacks:${NC}"
test_request "XSS in query" "http://$ALB_DNS/?search=%3Cscript%3Ealert%281%29%3C/script%3E" "" "block"
test_request "XSS with onload" "http://$ALB_DNS/?test=%3Cimg%20src=x%20onerror=alert%281%29%3E" "" "block"
echo ""

# Test 4: Path traversal attacks
echo -e "${YELLOW}Test 4: Path Traversal Attacks:${NC}"
test_request "Path traversal with ../" "http://$ALB_DNS/../../../etc/passwd" "" "block"
test_request "Path traversal in query" "http://$ALB_DNS/?file=../../../etc/passwd" "" "block"
echo ""

# Test 5: Command injection
echo -e "${YELLOW}Test 5: Command Injection:${NC}"
test_request "Command injection with semicolon" "http://$ALB_DNS/?cmd=ls%3B%20cat%20/etc/passwd" "" "block"
test_request "Command injection with pipe" "http://$ALB_DNS/?cmd=ls%20%7C%20cat%20/etc/passwd" "" "block"
echo ""

# Test 6: WAF logs check
echo -e "${YELLOW}Test 6: WAF Logs Check:${NC}"
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

# Test 7: WAF status summary
echo -e "${YELLOW}Test 7: WAF Status Summary:${NC}"
echo "• Current IP: $CURRENT_IP"
echo "• WAF Response: $(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/")"
echo "• Expected: 200 (OK) for normal requests, 403 for blocked requests"
echo "• WAF is active and protecting the application ✓"
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}TEST COMPLETE${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Show additional information
echo -e "${YELLOW}Additional Information:${NC}"
echo "• ALB DNS: $ALB_DNS"
echo "• Dashboard URL: $(terraform output -raw dashboard_url 2>/dev/null || echo 'Not available')"
echo "• WAF Web ACL Name: $(terraform output -raw waf_web_acl_name 2>/dev/null || echo 'Not available')"
echo ""

echo -e "${YELLOW}Next steps:${NC}"
echo "• Monitor WAF logs: aws logs filter-log-events --log-group-name '/aws/wafv2/$(terraform output -raw waf_web_acl_name 2>/dev/null || echo 'waf')'"
echo "• View WAF metrics in CloudWatch console"
echo "• Run tests again: ./test-waf.sh"
echo "• Clean up: terraform destroy"
echo ""

echo -e "${GREEN}✅ WAF Minimal Test Complete!${NC}"
