#!/usr/bin/env bash
# Sends fake requests to generate 4xx errors in Apache access log.
# Usage: bash fake_requests.sh <host>

HOST="${1:?Usage: $0 <host>}"
BASE="http://$HOST"

req() {
    local desc="$1"
    shift 
    local code
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$@")
    echo "$desc -> $code"
}

echo "=== Fake requests to $BASE ==="
req "200/403 home page" "$BASE/"

for i in {1..3}; do
	req "404 page not found" "$BASE/page-$i"
done

req "404 bot scan wp-login" "$BASE/wp-login.php"

req "400 request without host" -H 'Host:' "$BASE/"

LONG=$(head -c 9000 /dev/zero | tr '\0' 'a')
req "414 URI too long" "$BASE/$LONG"

echo "=== done ==="
