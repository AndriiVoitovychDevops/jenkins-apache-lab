#!/usr/bin/env bash
# Counts 4xx and 5xx errors in Apache access log.
# Runs ON the web VM as root:  ssh ... 'sudo bash -s' < check_logs.sh
set -euo pipefail

if [ -f /var/log/apache2/access.log ]; then
    LOG=/var/log/apache2/access.log          # Ubuntu
elif [ -f /var/log/httpd/access_log ]; then
    LOG=/var/log/httpd/access_log            # Rocky
else
    echo "ERROR: Apache access log not found" >&2
    exit 1
fi

# Helper function: prints ONLY status codes, one per line.
codes() {
    awk -F'"' '{ split($3, a, " "); print a[1] }' "$LOG"
}

TOTAL=$(wc -l < "$LOG")
C4XX=$(codes | grep -c '^4' || true)
C5XX=$(codes | grep -c '^5' || true)

echo "========== Apache log report: $(hostname) =========="
echo "Log file   : $LOG"
echo "All lines  : $TOTAL"
echo "4xx errors : $C4XX"
echo "5xx errors : $C5XX"

echo
echo "--- Errors by status code ---"
codes | grep -E '^[45]' | sort | uniq -c | sort -rn || true

echo
echo "--- Top 5 URLs with errors ---"
awk -F'"' '{ split($3, s, " "); split($2, r, " ");
             if (s[1] ~ /^[45]/) print s[1], substr(r[2], 1, 50) }' "$LOG" \
    | sort | uniq -c | sort -rn | head -n 5 || true
