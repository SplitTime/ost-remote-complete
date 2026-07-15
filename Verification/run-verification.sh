#!/usr/bin/env bash
# Runs the offline verification suite (the autonomous gate). Live API tests are
# skipped unless OST_LIVE_TESTS=1 is exported with OST_EMAIL / OST_PASSWORD.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodebuild test \
  -workspace "OST Tracker.xcworkspace" \
  -scheme "OST Remote" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"OST TrackerTests" \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "Test Case .*(passed|failed)|Executed .* test|TEST (SUCCEEDED|FAILED)|error:" | tail -40
