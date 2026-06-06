#!/usr/bin/env bash
# scan-for-secrets.sh — Scan repository for potential secrets before publishing
# Usage: ./scripts/scan-for-secrets.sh <directory>
# Returns: 0=clean, 1=potential secrets found

set -euo pipefail

SCAN_DIR="${1:-.}"
ISSUES=0

# Patterns that indicate potential secrets
# Excludes: documentation files that discuss these terms legitimately
# Excludes: placeholder patterns like <TUNNEL-UUID>, REPLACE_ME, example.com

echo "=== Secret Scan ==="
echo "  Scanning: ${SCAN_DIR}"
echo ""

# Build find command — exclude .git and binary files
FIND_EXCLUDE="-not -path '*/.git/*' -not -name '*.png' -not -name '*.jpg' -not -name '*.gif' -not -name '*.ico' -not -name '*.woff*' -not -name '*.ttf'"

# Pattern definitions
# Each pattern is: label|regex
PATTERNS=(
    "Private key|BEGIN (OPENSSH |RSA |EC |DSA )?PRIVATE KEY"
    "Cloudflare API token|cfut-[A-Za-z0-9_-]+"
    "UUID in credentials|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.json"
    "Password assignment|password\s*=\s*['\"][^'\"]{8,}['\"]"
    "Secret assignment|secret\s*=\s*['\"][^'\"]{16,}['\"]"
    "Token assignment|token\s*=\s*['\"][^'\"]{16,}['\"]"
    "Cookie with value|cookie.*=.*[A-Za-z0-9+/]{20,}"
    "JWT secret|jwt_secret\s*[:=]\s*['\"]?[A-Za-z0-9+/]{20,}"
    "Session secret|session_secret\s*[:=]\s*['\"]?[A-Za-z0-9+/]{20,}"
    "Storage encryption key|encryption_key\s*[:=]\s*['\"]?[A-Za-z0-9+/]{20,}"
    "Real IP address|\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b"
    "Credentials file path|credentials-file.*\.json"
)

# Files to skip (documentation that legitimately discusses these terms)
SKIP_FILES=(
    "scan-for-secrets.sh"
    "do-not-publish-checklist.md"
    "security.md"
    "troubleshooting.md"
    "config.yml"
)

should_skip_file() {
    local file="$1"
    for skip in "${SKIP_FILES[@]}"; do
        if [[ "$file" == *"$skip" ]]; then
            return 0
        fi
    done
    return 0
}

for pattern_def in "${PATTERNS[@]}"; do
    label="${pattern_def%%|*}"
    regex="${pattern_def#*|}"

    # Search, excluding .git and skip files
    matches=$(find "$SCAN_DIR" -type f $FIND_EXCLUDE -exec grep -lInE "$regex" {} + 2>/dev/null | grep -v "scan-for-secrets.sh" | grep -v "do-not-publish-checklist.md" | grep -v "security.md" | grep -v "config.yml" || true)

    if [ -n "$matches" ]; then
        # Filter out lines with placeholders
        real_matches=$(echo "$matches" | while IFS= read -r line; do
            file="${line%%:*}"
            content=$(echo "$line" | cut -d: -f3-)
            # Skip if it's a placeholder example
            if echo "$content" | grep -qE "TUNNEL_UUID|<TUNNEL|REPLACE_ME|YOUR_|example\.com|placeholder|# .*secret\|// .*secret"; then
                continue
            fi
            echo "$line"
        done)

        if [ -n "$real_matches" ]; then
            echo "  WARN  ${label}:"
            echo "$real_matches" | head -5 | while IFS= read -r m; do
                echo "         ${m}"
            done
            match_count=$(echo "$real_matches" | wc -l)
            if [ "$match_count" -gt 5 ]; then
                echo "         ... and $((match_count - 5)) more"
            fi
            ((ISSUES++))
            echo ""
        fi
    fi
done

echo "-- Summary --"
if [ "$ISSUES" -gt 0 ]; then
    echo "  ${ISSUES} potential issue(s) found"
    echo ""
    echo "RESULT: WARN — Review the matches above before publishing"
    echo "  Placeholders like <TUNNEL-UUID> and example.com are OK."
    echo "  Real secrets, tokens, keys, and IPs must be removed."
    exit 1
else
    echo "  No potential secrets detected"
    echo ""
    echo "RESULT: PASS — Clean (but always review manually)"
    exit 0
fi
