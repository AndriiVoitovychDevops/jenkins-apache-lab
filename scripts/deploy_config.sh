#!/usr/bin/env bash
# Puts lab-errors.conf into Apache and reloads it.
# Runs ON the web VM as root. The file must already be in /tmp.

set -euo pipefail

SRC=/tmp/lab-errors.conf

if [ ! -f "$SRC" ]; then
	echo "Error $SRC not found" >&2
	exit 1
fi

if [ -d /etc/apache2 ]; then
	SVC=apache2
	install -m 644 "$SRC" /etc/apache2/conf-available/lab-errors.conf
    	a2enconf -q lab-errors
else
	SVC=httpd
  	install -m 644 "$SRC" /etc/httpd/conf.d/lab-errors.conf
fi

apachectl configtest

systemctl reload "$SVC"

rm -f "$SRC"

echo "Config deployed on $(hostname)"
