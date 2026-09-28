#!/usr/bin/env bash
# Installs Apache on Debian/Ubuntu (apache2) or RHEL/Rocky (httpd). Idempotent.
# Usage: sudo bash install_apache.sh
set -euo pipefail

if command -v apt-get >/dev/null 2>&1; then
    SVC=apache2
    export DEBIAN_FRONTEND=noninteractive

	if dpkg -s "$SVC" >/dev/null 2>&1; then
		echo "$SVC already installed"
	else
		apt-get update && apt-get install "$SVC" -y
	fi

elif command -v dnf >/dev/null 2>&1; then
    SVC=httpd
	if rpm -q "$SVC" >/dev/null 2>&1; then
                echo "$SVC already installed"
        else
                dnf install "$SVC" -y
	fi
		if systemctl is-active --quiet firewalld >/dev/null 2>&1; then
                        firewall-cmd --permanent --add-service=http
                        firewall-cmd --reload
                fi
else
    echo "ERROR: unsupported OS" >&2
    exit 1
fi

echo "Enabling and starting $SVC"
systemctl enable "$SVC" || true
systemctl start "$SVC" || true

if systemctl is-active --quiet "$SVC"; then
    echo "Apache ($SVC) is running on $(hostname)"
    "$SVC" -v | grep "Server version"
else
    echo "ERROR: $SVC failed to start. Current status:" >&2
	systemctl status "$SVC" --no-pager || true
    exit 1
fi
