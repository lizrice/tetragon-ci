#!/usr/bin/env bash
set -euo pipefail

echo "::group::Benign CI activity"
echo "hello from CI"

workspace="${RUNNER_TEMP:-/tmp}/tetragon-ci"
mkdir -p "$workspace"

printf 'build artifact generated at %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$workspace/build.txt"
wc -c "$workspace/build.txt"

ls -la
cat /etc/hosts >/dev/null

echo "Benign CI activity completed."
echo "::endgroup::"
