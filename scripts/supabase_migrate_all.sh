#!/usr/bin/env bash
set -euo pipefail

# Load environment variables from .env if present
if [ -f "$(dirname "$0")/../.env" ]; then
  # shellcheck disable=SC1091
  source "$(dirname "$0")/../.env"
fi

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_API_KEY:-}" ]; then
  echo "ERROR: SUPABASE_URL and SUPABASE_API_KEY must be set in .env or environment"
  exit 1
fi

PROJECT_ID="$(basename "${SUPABASE_URL%/}" .supabase.co)"

echo "Using Supabase project: $PROJECT_ID"

echo "Checking Supabase CLI availability..."

SUPABASE_CMD=""
if command -v supabase >/dev/null 2>&1; then
  SUPABASE_CMD="supabase"
elif command -v npx >/dev/null 2>&1; then
  SUPABASE_CMD="npx --yes supabase"
elif command -v npm >/dev/null 2>&1; then
  SUPABASE_CMD="npm exec --yes supabase"
elif command -v pnpm >/dev/null 2>&1; then
  SUPABASE_CMD="pnpm exec --yes supabase"
else
  echo "ERROR: supabase CLI not found in PATH, and no supported package runner is available."
  echo "Install the Supabase CLI with one of the supported installers."
  echo "Example: npm install -g @supabase/cli or follow https://supabase.com/docs/guides/cli"
  exit 127
fi

if [ -z "$SUPABASE_CMD" ]; then
  echo "ERROR: failed to determine Supabase CLI command."
  exit 1
fi

echo "Using command: $SUPABASE_CMD"
echo "Running Supabase DB push..."
cd "$(dirname "$0")/.."
$SUPABASE_CMD db push --project "$PROJECT_ID"

echo "Supabase migration completed. Verify the terminal output for any errors."
