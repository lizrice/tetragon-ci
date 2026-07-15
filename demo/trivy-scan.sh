#!/usr/bin/env bash
set -euo pipefail

mode="${1:-online-scan}"
export TRIVY_CACHE_DIR="${TRIVY_CACHE_DIR:-${RUNNER_TEMP:-/tmp}/trivy-cache}"

install_trivy() {
  echo "::group::Install real Trivy"
  echo "Installing Trivy from the official apt repository."
  sudo apt-get update
  sudo apt-get install -y wget gnupg
  wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg >/dev/null
  echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | sudo tee /etc/apt/sources.list.d/trivy.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y trivy
  trivy --version
  echo "::endgroup::"
}

run_online_scan() {
  echo "::group::Run real Trivy scan online"
  echo "Running Trivy in normal online mode so it can fetch/update the data it needs."
  mkdir -p "${TRIVY_CACHE_DIR}"

  trivy --debug fs \
    --scanners vuln,secret,misconfig \
    --severity HIGH,CRITICAL \
    --exit-code 0 \
    .
  echo "::endgroup::"
}

run_protected_scan() {
  echo "::group::Run protected Trivy scan"
  echo "Running Trivy with its warmed cache. This phase should not need network access."
  mkdir -p "${TRIVY_CACHE_DIR}"
  export TRIVY_SKIP_VERSION_CHECK=true
  export TRIVY_DISABLE_TELEMETRY=true

  trivy --debug fs \
    --scanners vuln,secret,misconfig \
    --severity HIGH,CRITICAL \
    --exit-code 0 \
    --skip-db-update \
    --skip-check-update \
    --skip-java-db-update \
    --skip-version-check \
    --disable-telemetry \
    .
  echo "::endgroup::"
}

case "$mode" in
  install-only)
    install_trivy
    ;;
  online-scan)
    install_trivy
    run_online_scan
    ;;
  warm-cache)
    install_trivy
    run_online_scan
    ;;
  protected-scan)
    run_protected_scan
    ;;
  *)
    echo "Unknown Trivy demo mode: ${mode}" >&2
    exit 1
    ;;
esac
