#!/usr/bin/env bash
set -euo pipefail

echo "::group::Sensitive file access"
echo "This simulates a build step reading a sensitive host file from the runner."

workspace="${RUNNER_TEMP:-/tmp}/tetragon-ci"
mkdir -p "$workspace"
printf 'normal-looking test output\n' > "$workspace/test.txt"

echo "Attempting sensitive file access..."
sudo head -c 64 /etc/shadow >/dev/null

echo "Sensitive file access scenario completed."
echo "::endgroup::"
