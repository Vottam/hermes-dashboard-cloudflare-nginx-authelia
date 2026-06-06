#!/usr/bin/env bash
# check-public-endpoint.sh — Validate public endpoint for Hermes Dashboard
# Usage: ./scripts/check-public-endpoint.sh https://hermes-kvm4.example.com
# Returns: 0=PASS, 1=WARN, 2=FAIL

set -euo pipefail

PASS=0
WARN=0
FAIL=0

if [ $# -lt 1 ]; then
    echo "Usage: $0 <url>"
    echo "Example: $0 https://hermes-kvm4.example.com"
    exit 2
fi

BASE_URL="$1"
BASE_URL="${BASE_URL%/}"  # strip trailing slash

echo "=== Public Endpoint Check ==="
echo "  URL: ${BASE_URL}"
echo ""

# Check 1: HTTP status
echo "-- HTTP Status --"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${BASE_URL}/" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "200" ]; then
    echo "  PASS  HTTP ${HTTP_CODE} (redirect or OK)"
    ((PASS++))
elif [ "$HTTP_CODE" = "000" ]; then
    echo "  FAIL  Connection refused or timeout"
    ((FAIL++))
else
    echo "  WARN  HTTP ${HTTP_CODE} (unexpected)"
    ((WARN++))
fi

# Check 2: Server header (should be cloudflare)
echo ""
echo "-- Server Header --"
SERVER=$(curl -sI --max-time 10 "${BASE_URL}/" 2>/dev/null | grep -i "^server:" | head -1 | awk '{print $2}' | tr -d '\r' || echo "unknown")
if echo "$SERVER" | grep -qi "cloudflare"; then
    echo "  PASS  Server: ${SERVER} (Cloudflare detected)"
    ((PASS++))
else
    echo "  WARN  Server: ${SERVER} (expected cloudflare)"
    ((WARN++))
fi

# Check 3: Redirect to Authelia
echo ""
echo "-- Authelia Redirect --"
LOCATION=$(curl -sI --max-time 10 "${BASE_URL}/" 2>/dev/null | grep -i "^location:" | head -1 | awk '{print $2}' | tr -d '\r' || echo "")
if echo "$LOCATION" | grep -qi "portal"; then
    echo "  PASS  Redirects to Authelia portal"
    ((PASS++))
elif [ -n "$LOCATION" ]; then
    echo "  WARN  Redirects to: ${LOCATION} (expected portal redirect)"
    ((WARN++))
else
    echo "  WARN  No redirect detected"
    ((WARN++))
fi

# Check 4: DNS resolves to Cloudflare
echo ""
echo "-- DNS Check --"
DOMAIN=$(echo "$BASE_URL" | sed 's|https\?://||' | cut -d'/' -f1)
DNS_RESULT=$(dig +short "$DOMAIN" 2>/dev/null | head -1 || echo "")
if echo "$DNS_RESULT" | grep -qE '^104\.|^172\.'; then
    echo "  PASS  DNS resolves to Cloudflare IP: ${DNS_RESULT}"
    ((PASS++))
elif [ -n "$DNS_RESULT" ]; then
    echo "  WARN  DNS resolves to: ${DNS_RESULT} (expected Cloudflare IP)"
    ((WARN++))
else
    echo "  FAIL  DNS resolution failed"
    ((FAIL++))
fi

echo ""
echo "-- Summary --"
echo "  PASS: ${PASS}  WARN: ${WARN}  FAIL: ${FAIL}"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "RESULT: FAIL — ${FAIL} check(s) failed"
    exit 2
elif [ "$WARN" -gt 0 ]; then
    echo ""
    echo "RESULT: WARN — ${WARN} check(s) warning"
    exit 1
else
    echo ""
    echo "RESULT: PASS — All checks passed"
    exit 0
fi
