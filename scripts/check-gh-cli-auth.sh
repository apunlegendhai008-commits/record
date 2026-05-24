#!/usr/bin/env bash
set -euo pipefail

# Simple static check for unsafe `gh` CLI usage.
# Exits non-zero when a file contains `gh` but no auth/token usage.

echo "GH CLI safety check: scanning repository for 'gh' usages..."

# Find files that reference `gh` as a standalone word
matches=$(git grep -n --untracked -E '\bgh\b' || true)

if [ -z "${matches}" ]; then
  echo "No 'gh' CLI usage found."
  exit 0
fi

errors=0

# Get unique file list
files=$(echo "${matches}" | awk -F: '{print $1}' | sort -u)

for file in ${files}; do
  # skip the check script itself
  if [ "${file}" = "scripts/check-gh-cli-auth.sh" ]; then
    continue
  fi

  # Look for evidence that the file handles auth or uses the GITHUB_TOKEN/GH_TOKEN
  if git grep -n -E 'auth login|with-token|GITHUB_TOKEN|GH_TOKEN|gh auth|permissions:.*actions' -- "${file}" > /dev/null 2>&1; then
    echo "OK: ${file} (auth/token or permission hint found)"
  else
    echo "ERROR: ${file} contains 'gh' but no 'auth login' or token usage found"
    errors=$((errors+1))
  fi
done

if [ "${errors}" -gt 0 ]; then
  echo "Found ${errors} unsafe 'gh' usages. Please add authentication (example: echo \"\$GITHUB_TOKEN\" | gh auth login --with-token) or set workflow permissions."
  exit 1
fi

echo "All 'gh' usages appear to be authenticated or documented."
exit 0
