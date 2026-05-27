#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

run() {
  echo
  echo "==> $*"
  "$@"
}

for tool in git python3 rg swift xcodebuild xcodegen swiftlint swiftformat; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "Missing required tool: $tool" >&2
    exit 127
  }
done

run xcodegen generate
run xcodebuild -list -project LangoTrace.xcodeproj
run swift test --package-path Packages/LangoTraceCore
run swift test --package-path Packages/LangoTraceData
run swift test --package-path Packages/LangoTraceAI
run swift test --package-path Packages/LangoTraceSpeech
run swift test --package-path Packages/LangoTraceSync
run swift test --package-path Packages/LangoTraceUI
run python3 -m unittest discover -s Tests/Tooling -p 'test_*.py'
run xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
run xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
run xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build
run xcodebuild test -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -only-testing:LangoTraceAppTests
run swiftlint --no-cache
run swiftformat --lint . --exclude .build,build,DerivedData,LangoTrace.xcodeproj --cache ignore
run scripts/check-docs.sh
run git diff --check
run git status --short
