#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

run() {
  echo
  echo "==> $*"
  "$@"
}

# Ensure all required tools are present
for tool in git python3 rg swift xcodebuild xcodegen swiftlint swiftformat; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "Missing required tool: $tool" >&2
    exit 127
  }
done

run xcodegen generate
run xcodebuild -list -project LangoTrace.xcodeproj

# Run tests sequentially to ensure steady output
run swift test --package-path Packages/LangoTraceCore
run swift test --package-path Packages/LangoTraceData
run swift test --package-path Packages/LangoTraceAI
run swift test --package-path Packages/LangoTraceSpeech
run swift test --package-path Packages/LangoTraceSync
run swift test --package-path Packages/LangoTraceUI

run python3 -m unittest discover -s Tests/Tooling -p 'test_*.py'

# Progress reporter to prevent timeouts
heartbeat() {
  while true; do
    sleep 30
    echo "... still working ($1) ..."
  done
}

run_with_heartbeat() {
  local name="$1"
  shift
  echo "==> Running $name"
  heartbeat "$name" &
  local pid=$!
  # Run command and filter to keep log size manageable but alive
  "$@" | grep --line-buffered -iE "error:|warning:|built|failed|linking|passed|suite" || true
  kill $pid
}

run_with_heartbeat "LangoTrace-iOS (iPhone 17) build" \
  xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build

run_with_heartbeat "LangoTrace-iOS (iPad Pro 13-inch (M5)) build" \
  xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build

run_with_heartbeat "LangoTrace-macOS build" \
  xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build

run_with_heartbeat "LangoTrace-macOS AppTests" \
  xcodebuild test -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -only-testing:LangoTraceAppTests

run swiftlint --cache
run swiftformat --lint . --exclude .build,build,DerivedData,LangoTrace.xcodeproj --cache use

run scripts/check-docs.sh
run git diff --check
run git status --short

echo
echo "==> Verification Successful!"
