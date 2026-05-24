done
#!/usr/bin/env bash
set -euo pipefail

# Robust static check for real `gh` CLI invocations.
# This avoids false positives for filenames like "check-gh-cli-auth.sh".

echo "GH CLI safety check: scanning repository for real 'gh' CLI invocations..."

# Find files that invoke `gh` as a command. Match 'gh' preceded by line-start,
# whitespace, or common shell separators and followed by whitespace (e.g. "gh run list",
# "| gh auth login"). This reduces accidental matches inside hyphenated filenames.
matches=$(git grep -n --untracked -E '(^|[[:space:];&|])gh[[:space:]]' || true)

if [ -z "${matches}" ]; then
  echo "No real 'gh' CLI invocations found."
  exit 0
fi

errors=0

# Get unique file list from matching lines
files=$(echo "${matches}" | awk -F: '{print $1}' | sort -u)

for file in ${files}; do
  # skip the check script itself
  if [ "${file}" = "scripts/check-gh-cli-auth.sh" ]; then
    continue
  fi

  # Look for evidence that the file handles auth or uses the GITHUB_TOKEN/GH_TOKEN
  if git grep -n -E 'auth login|with-token|GITHUB_TOKEN|GH_TOKEN|gh auth|permissions:.*actions|gh workflow run|gh run list|gh secret set' -- "${file}" > /dev/null 2>&1; then
    echo "OK: ${file} (auth/token or permission hint found)"
  else
    echo "ERROR: ${file} contains 'gh' invocations but no 'auth login' or token usage found"
    errors=$((errors+1))
  fi


if [ "${errors}" -gt 0 ]; then
  echo "Found ${errors} unsafe 'gh' usages. Please add authentication (example: echo \"\$GITHUB_TOKEN\" | gh auth login --with-token) or set workflow permissions."
  exit 1
fi

echo "All 'gh' invocations appear to be authenticated or documented."
exit 0
