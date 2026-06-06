#!/usr/bin/env bash
# check-local-stack.sh — Validate local services for Hermes Dashboard
# Usage: ./scripts/check-local-stack.sh
# Returns: 0=PASS, 1=WARN, 2=FAIL

set -euo pipefail

PASS=0
WARN=0
FAIL=0

check_port() {
    local label="$1"
    local host="$2"
    local port="$3"
    if curl -s --max-time 3 "http://${host}:${port}" > /dev/null 2>&1; then
        echo "  PASS  ${label} (${host}:${port})"
        ((PASS++))
    else
        echo "  FAIL  ${label} (${host}:${port})"
        ((FAIL++))
    fi
}

check_service() {
    local name="$1"
    if systemctl is-active --quiet "$name" 2>/dev/null; then
        echo "  PASS  ${name} (systemd)"
        ((PASS++))
    else
        echo "  WARN  ${name} (systemd — not running or not installed)"
        ((WARN++))
    fi
}

echo "=== Local Stack Check ==="
echo ""

echo "-- Ports --"
check_port  "Hermes Dashboard"  "127.0.0.1" 9119
check_port  "Nginx local"      "127.0.0.1" 4180
check_port  "Authelia"         "127.0.0.1" 9091

echo ""
echo "-- Services --"
check_service "nginx"
check_service "cloudflared"
check_service "authelia-hermes-kvm4" 2>/dev/null || true
check_service "hermes-kvm4-dashboard" 2>/dev/null || true

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
