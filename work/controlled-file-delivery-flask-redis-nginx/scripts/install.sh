#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' 'Controlled File Delivery reference: prerequisite check'
printf '%s\n' 'This script does not install packages or change system configuration.'

required=(python3 nginx redis-cli systemctl)
missing=0
for command in "${required[@]}"; do
  if command -v "$command" >/dev/null 2>&1; then
    printf '%-12s %s\n' "$command" 'available'
  else
    printf '%-12s %s\n' "$command" 'missing'
    missing=1
  fi
done

if [ "$missing" -ne 0 ]; then
  printf '%s\n' 'Install missing prerequisites with your distribution package manager, then create a dedicated service account, Python environment, Redis connection, and /srv/downloads/ directory according to local policy.' >&2
  exit 1
fi

printf '%s\n' 'Prerequisite check complete. Review README.md before adapting this reference.'
