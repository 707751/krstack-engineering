#!/usr/bin/env bash
set -euo pipefail

service_name="${SERVICE_NAME:-flask-app}"
listener="${LISTENER:-127.0.0.1:5000}"
download_root="${DOWNLOAD_ROOT:-/srv/downloads}"

printf '%s\n' 'Controlled File Delivery reference: local verification'

if command -v python3 >/dev/null 2>&1; then
  python3 --version
else
  printf '%s\n' 'python3 is not available' >&2
fi

if command -v redis-cli >/dev/null 2>&1; then
  redis-cli ping || printf '%s\n' 'Redis did not answer PING; check the configured connection before deployment.' >&2
else
  printf '%s\n' 'redis-cli is not available; Redis connectivity was not checked.' >&2
fi

if command -v ss >/dev/null 2>&1; then
  ss -ltn | grep -F "$listener" || printf '%s\n' "No listener found at $listener." >&2
fi

if [ -d "$download_root" ]; then
  printf '%s\n' "Download root exists: $download_root"
else
  printf '%s\n' "Download root is missing: $download_root" >&2
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl is-active --quiet "$service_name" && printf '%s\n' "Service $service_name is active." || printf '%s\n' "Service $service_name is not active." >&2
fi

if command -v nginx >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
  sudo nginx -t
else
  printf '%s\n' 'Nginx syntax test not run: nginx or passwordless sudo is unavailable.'
fi

printf '%s\n' 'Review Nginx and application logs using local operational procedures; do not log credentials or file paths unnecessarily.'
