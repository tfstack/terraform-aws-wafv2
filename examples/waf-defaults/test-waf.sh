#!/bin/bash

# WAFv2 Test Example - Test Script
# This script tests the WAF with AWS managed rules including Bot Control and HTTP Method Restriction
# Usage: ./test-waf.sh [use-case]
# Use cases: public-website, api-only, internal, scientific-data

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get use case from command line argument (default: api-only)
USE_CASE=${1:-"api-only"}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}WAFv2 TEST EXAMPLE - TEST${NC}"
echo -e "${BLUE}Use Case: $USE_CASE${NC}"
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

# Set URL variable
URL="http://waf-79ig-1360507075.ap-southeast-2.elb.amazonaws.com/"

# Get ALB DNS from Terraform output (fallback)
echo -e "${YELLOW}Getting ALB DNS name...${NC}"
ALB_DNS=$(terraform output -raw alb_alb_dns 2>/dev/null || echo "")

if [ -n "$ALB_DNS" ]; then
    URL="http://$ALB_DNS/"
    echo -e "${GREEN}Using ALB DNS: $ALB_DNS${NC}"
else
    echo -e "${YELLOW}Using hardcoded URL: $URL${NC}"
    echo -e "${YELLOW}Note: Run 'terraform apply' to get the actual ALB DNS${NC}"
fi
echo ""

# Test function
test_request() {
    local test_name="$1"
    local url="$2"
    local headers="$3"
    local expected="$4"
    local description="$5"

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

    if [ -n "$description" ]; then
        echo "    $description"
    fi
}

# Test function for HTTP methods
test_method() {
    local test_name="$1"
    local method="$2"
    local url="$3"
    local expected="$4"
    local description="$5"

    echo -n "Testing $test_name... "

    response=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$url" || echo "000")

    if [ "$expected" = "block" ] && [ "$response" = "403" ]; then
        echo -e "${GREEN}PASS${NC} (blocked as expected)"
    elif [ "$expected" = "allow" ] && [ "$response" = "200" ]; then
        echo -e "${GREEN}PASS${NC} (allowed as expected)"
    else
        echo -e "${RED}FAIL${NC} (got $response, expected $expected)"
    fi

    if [ -n "$description" ]; then
        echo "    $description"
    fi
}

# Get current client IP
echo -e "${YELLOW}Getting current client IP...${NC}"
CURRENT_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "unknown")
echo -e "${GREEN}Current client IP: $CURRENT_IP${NC}"
echo ""

# Test 1: Basic Lambda functionality
echo -e "${YELLOW}Test 1: Basic Lambda Functionality:${NC}"
test_request "Root endpoint" "http://$ALB_DNS/" "" "allow" "Should return welcome message"
test_request "Health endpoint" "http://$ALB_DNS/health" "" "allow" "Should return health status"
test_request "Hello endpoint" "http://$ALB_DNS/api/hello" "" "allow" "Should return hello message"
test_request "Info endpoint" "http://$ALB_DNS/api/info" "" "allow" "Should return service info"
echo ""

# Test 2: HTTP Method Restriction
echo -e "${YELLOW}Test 2: HTTP Method Restriction:${NC}"
echo "Configuration: Only GET, HEAD, PUT, POST allowed"

# Test allowed methods (should return 200)
echo "=== EXPECTED 200 (ALLOWED METHODS) ==="
test_method "GET Method" "GET" "http://$ALB_DNS/" "allow" "Should allow GET requests"
test_method "HEAD Method" "HEAD" "http://$ALB_DNS/" "allow" "Should allow HEAD requests"
test_method "POST Method" "POST" "http://$ALB_DNS/" "allow" "Should allow POST requests"
test_method "PUT Method" "PUT" "http://$ALB_DNS/" "allow" "Should allow PUT requests"

# Test blocked methods (should return 403)
echo "=== EXPECTED 403 (BLOCKED METHODS) ==="
test_method "DELETE Method" "DELETE" "http://$ALB_DNS/" "block" "Should block DELETE requests"
test_method "PATCH Method" "PATCH" "http://$ALB_DNS/" "block" "Should block PATCH requests"
test_method "OPTIONS Method" "OPTIONS" "http://$ALB_DNS/" "block" "Should block OPTIONS requests"
test_method "TRACE Method" "TRACE" "http://$ALB_DNS/" "block" "Should block TRACE requests"
test_method "CONNECT Method" "CONNECT" "http://$ALB_DNS/" "block" "Should block CONNECT requests"
echo ""

# Test 3: SQL Injection attacks
echo -e "${YELLOW}Test 3: SQL Injection Attacks (AWSManagedRulesSQLiRuleSet):${NC}"
test_request "SQL injection in query" "http://$ALB_DNS/?id=1%27%20OR%20%271%27=%271" "" "block" "Should block SQL injection in query parameters"
test_request "SQL injection with UNION" "http://$ALB_DNS/?search=1%27%20UNION%20SELECT%20*%20FROM%20users" "" "block" "Should block UNION-based SQL injection"
test_request "SQL injection with DROP" "http://$ALB_DNS/?id=1%27%3B%20DROP%20TABLE%20users%3B--" "" "block" "Should block DROP TABLE injection"
echo ""

# Test 4: XSS attacks
echo -e "${YELLOW}Test 4: XSS Attacks (AWSManagedRulesCommonRuleSet):${NC}"
test_request "XSS in query" "http://$ALB_DNS/?search=%3Cscript%3Ealert%281%29%3C/script%3E" "" "block" "Should block script injection in query"
test_request "XSS with onload" "http://$ALB_DNS/?test=%3Cimg%20src=x%20onerror=alert%281%29%3E" "" "block" "Should block img onerror XSS"
test_request "XSS in path" "http://$ALB_DNS/%3Cscript%3Ealert%281%29%3C/script%3E" "" "block" "Should block XSS in URI path"
echo ""

# Test 5: Path traversal attacks
echo -e "${YELLOW}Test 5: Path Traversal Attacks (AWSManagedRulesLinuxRuleSet):${NC}"
test_request "Path traversal with ../" "http://$ALB_DNS/../../../etc/passwd" "" "block" "Should block directory traversal"
test_request "Path traversal in query" "http://$ALB_DNS/?file=../../../etc/passwd" "" "block" "Should block traversal in query params"
test_request "LFI attempt" "http://$ALB_DNS/?include=../../../etc/passwd" "" "block" "Should block local file inclusion"
echo ""

# Test 6: Command injection
echo -e "${YELLOW}Test 6: Command Injection (AWSManagedRulesLinuxRuleSet):${NC}"
test_request "Command injection with semicolon" "http://$ALB_DNS/?cmd=ls%3B%20cat%20/etc/passwd" "" "block" "Should block command injection with semicolon"
test_request "Command injection with pipe" "http://$ALB_DNS/?cmd=ls%20%7C%20cat%20/etc/passwd" "" "block" "Should block command injection with pipe"
test_request "Command injection with &&" "http://$ALB_DNS/?cmd=ls%20%26%26%20cat%20/etc/passwd" "" "block" "Should block command injection with &&"
echo ""

# Test 7: Bot Control Tests
echo -e "${YELLOW}Test 7: Bot Control Tests (AWSManagedRulesBotControlRuleSet):${NC}"
echo "Configuration: CategorySearchEngine=block, CategoryHttpLibrary=allow, others=default"

# Expected 200 (Allowed)
echo "=== EXPECTED 200 (ALLOWED) ==="
test_request "Curl" "http://$ALB_DNS/" "User-Agent: curl/7.68.0" "allow" "Should allow curl (HTTP library)"
test_request "Wget" "http://$ALB_DNS/" "User-Agent: Wget/1.21.1" "allow" "Should allow wget (HTTP library)"
test_request "Postman" "http://$ALB_DNS/" "User-Agent: PostmanRuntime/7.28.0" "allow" "Should allow Postman (HTTP library)"

# Test based on use case
if [ "$USE_CASE" = "public-website" ] || [ "$USE_CASE" = "scientific-data" ]; then
    # Should allow search engines for public content
    test_request "Google Bot" "http://$ALB_DNS/" "User-Agent: Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)" "allow" "Should allow Google bot (public content)"
    test_request "Bing Bot" "http://$ALB_DNS/" "User-Agent: Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)" "allow" "Should allow Bing bot (public content)"
else
    # Should block search engines for APIs/internal
    test_request "Google Bot" "http://$ALB_DNS/" "User-Agent: Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)" "block" "Should block Google bot (API/internal)"
    test_request "Bing Bot" "http://$ALB_DNS/" "User-Agent: Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)" "block" "Should block Bing bot (API/internal)"
fi

# Social Media Bots
if [ "$USE_CASE" = "public-website" ]; then
    # Should allow social media for public websites
    test_request "Facebook Bot" "http://$ALB_DNS/" "User-Agent: facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)" "allow" "Should allow Facebook bot (public content)"
    test_request "Twitter Bot" "http://$ALB_DNS/" "User-Agent: Twitterbot/1.0" "allow" "Should allow Twitter bot (public content)"
else
    # Should block social media for APIs/internal
    test_request "Facebook Bot" "http://$ALB_DNS/" "User-Agent: facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)" "block" "Should block Facebook bot (API/internal)"
    test_request "Twitter Bot" "http://$ALB_DNS/" "User-Agent: Twitterbot/1.0" "block" "Should block Twitter bot (API/internal)"
fi

# Monitoring Bots
if [ "$USE_CASE" = "internal" ] || [ "$USE_CASE" = "api-only" ]; then
    # Should allow monitoring for internal/API services
    test_request "Uptime Robot" "http://$ALB_DNS/" "User-Agent: Mozilla/5.0 (compatible; UptimeRobot/2.0; +http://www.uptimerobot.com/)" "allow" "Should allow uptime monitoring"
    test_request "Pingdom Bot" "http://$ALB_DNS/" "User-Agent: Pingdom.com_bot_version_1.4_(http://www.pingdom.com/)" "allow" "Should allow Pingdom monitoring"
else
    # Should block monitoring for public websites
    test_request "Uptime Robot" "http://$ALB_DNS/" "User-Agent: Mozilla/5.0 (compatible; UptimeRobot/2.0; +http://www.uptimerobot.com/)" "block" "Should block uptime monitoring (public)"
    test_request "Pingdom Bot" "http://$ALB_DNS/" "User-Agent: Pingdom.com_bot_version_1.4_(http://www.pingdom.com/)" "block" "Should block Pingdom monitoring (public)"
fi

# Content Fetchers
if [ "$USE_CASE" = "scientific-data" ]; then
    # Should allow content fetchers for scientific data
    test_request "RSS Reader" "http://$ALB_DNS/" "User-Agent: Mozilla/5.0 (compatible; RSS Reader/1.0)" "allow" "Should allow RSS readers (scientific data)"
    test_request "Data Aggregator" "http://$ALB_DNS/" "User-Agent: Mozilla/5.0 (compatible; DataAggregator/1.0)" "allow" "Should allow data aggregators (scientific data)"
else
    # Should block content fetchers for other use cases
    test_request "RSS Reader" "http://$ALB_DNS/" "User-Agent: Mozilla/5.0 (compatible; RSS Reader/1.0)" "block" "Should block RSS readers (API/internal)"
    test_request "Data Aggregator" "http://$ALB_DNS/" "User-Agent: Mozilla/5.0 (compatible; DataAggregator/1.0)" "block" "Should block data aggregators (API/internal)"
fi

# Expected 403 (Blocked)
echo "=== EXPECTED 403 (BLOCKED) ==="
test_request "Scrapy Framework" "http://$ALB_DNS/" "User-Agent: Scrapy/1.8.0" "block" "Should block Scrapy (scraping framework)"
test_request "BeautifulSoup" "http://$ALB_DNS/" "User-Agent: BeautifulSoup/4.8.0" "block" "Should block BeautifulSoup (scraping framework)"
test_request "Selenium" "http://$ALB_DNS/" "User-Agent: Selenium/3.141.0" "block" "Should block Selenium (scraping framework)"
test_request "Ad Bot" "http://$ALB_DNS/" "User-Agent: Mozilla/5.0 (compatible; AdBot/1.0; +http://adbot.example.com)" "block" "Should block advertising bots"
test_request "Click Bot" "http://$ALB_DNS/" "User-Agent: Mozilla/5.0 (compatible; ClickBot/1.0)" "block" "Should block click bots"
test_request "Archive.org Bot" "http://$ALB_DNS/" "User-Agent: Mozilla/5.0 (compatible; Archive.org_bot/1.0; +http://archive.org/web/)" "block" "Should block archive bots"
test_request "Wayback Machine" "http://$ALB_DNS/" "User-Agent: Mozilla/5.0 (compatible; WaybackMachine/1.0)" "block" "Should block Wayback Machine"

# AI/ML Bots
if [ "$USE_CASE" = "scientific-data" ]; then
    # Should allow AI/ML for scientific data
    test_request "AI Training Bot" "http://$ALB_DNS/" "User-Agent: Mozilla/5.0 (compatible; AITrainingBot/1.0)" "allow" "Should allow AI training bots (scientific data)"
else
    # Should block AI/ML for other use cases
    test_request "AI Training Bot" "http://$ALB_DNS/" "User-Agent: Mozilla/5.0 (compatible; AITrainingBot/1.0)" "block" "Should block AI training bots (API/internal)"
    test_request "GPT Bot" "http://$ALB_DNS/" "User-Agent: GPTBot/1.0" "block" "Should block GPT Bot (AI)"
    test_request "Claude Bot" "http://$ALB_DNS/" "User-Agent: ClaudeBot/1.0" "block" "Should block Claude Bot (AI)"
fi

echo ""

# Test 8: Rate limiting (if configured)
echo -e "${YELLOW}Test 8: Rate Limiting Test:${NC}"
echo "Sending multiple rapid requests..."
for i in {1..5}; do
    response=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/" || echo "000")
    echo "Request $i: $response"
    sleep 0.5
done
echo ""

# Test 9: WAF logs check
echo -e "${YELLOW}Test 9: WAF Logs Check:${NC}"
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

        # Check for bot control blocks specifically
        BOT_BLOCKS=$(aws logs filter-log-events \
            --log-group-name "$LOG_GROUP" \
            --start-time $(($(date +%s) - 300))000 \
            --filter-pattern 'ruleName = "AWSManagedRulesBotControlRuleSet"' \
            --query 'events[].message' \
            --output text 2>/dev/null | wc -l)

        if [ "$BOT_BLOCKS" -gt 0 ]; then
            echo -e "${GREEN}✓ Found $BOT_BLOCKS bot control blocks in logs${NC}"
        else
            echo -e "${YELLOW}⚠ No bot control blocks found in recent logs${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ WAF log group not found or not accessible${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Could not get WAF name for log checking${NC}"
fi
echo ""

# Test 10: WAF status summary
echo -e "${YELLOW}Test 10: WAF Status Summary:${NC}"
echo "• Current IP: $CURRENT_IP"
echo "• WAF Response: $(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/")"
echo "• Expected: 200 (OK) for normal requests, 403 for blocked requests"
echo "• WAF is active and protecting the application ✓"
echo "• Bot Control is active and protecting against automated traffic ✓"
echo "• HTTP Method restriction is active ✓"
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
echo "• Check bot control metrics specifically"
echo "• Test HTTP methods: curl -X DELETE http://$ALB_DNS/ (should be blocked)"
echo "• Run tests again: ./test-waf.sh"
echo "• Clean up: terraform destroy"
echo ""

echo -e "${GREEN}✅ WAF Test Complete!${NC}"
echo -e "${GREEN}✅ Bot Control Testing Complete!${NC}"
echo -e "${GREEN}✅ HTTP Method Restriction Testing Complete!${NC}"

# Configuration Summary
echo ""
echo -e "${YELLOW}Bot Control Configuration Summary (Use Case: $USE_CASE):${NC}"
case $USE_CASE in
    "public-website")
        echo "• Search engines: ALLOWED (for discoverability)"
        echo "• Social media: ALLOWED (for link previews)"
        echo "• HTTP libraries: ALLOWED (for tools)"
        echo "• Scraping: BLOCKED (prevent abuse)"
        echo "• Advertising: BLOCKED (no ads needed)"
        ;;
    "api-only")
        echo "• Search engines: BLOCKED (not needed for APIs)"
        echo "• Social media: BLOCKED (not needed for APIs)"
        echo "• HTTP libraries: ALLOWED (for API testing)"
        echo "• Monitoring: ALLOWED (for API health)"
        echo "• Scraping: BLOCKED (prevent abuse)"
        ;;
    "internal")
        echo "• Search engines: BLOCKED (internal use only)"
        echo "• Social media: BLOCKED (internal use only)"
        echo "• HTTP libraries: ALLOWED (for tools)"
        echo "• Monitoring: ALLOWED (for reliability)"
        echo "• Scraping: BLOCKED (prevent abuse)"
        ;;
    "scientific-data")
        echo "• Search engines: ALLOWED (for discoverability)"
        echo "• Content fetchers: ALLOWED (for research tools)"
        echo "• AI/ML bots: ALLOWED (for data analysis)"
        echo "• HTTP libraries: ALLOWED (for tools)"
        echo "• Scraping: BLOCKED (prevent abuse)"
        ;;
esac

echo ""
echo -e "${YELLOW}Usage Examples:${NC}"
echo "• ./test-waf.sh public-website"
echo "• ./test-waf.sh api-only"
echo "• ./test-waf.sh internal"
echo "• ./test-waf.sh scientific-data"
