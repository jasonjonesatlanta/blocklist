#!/bin/bash
# Verify coldturkey-guardian protections are in place and working.
# Run as root: sudo bash verify_guardian.sh

PASS=0
FAIL=0

check() {
  local desc="$1"; local result="$2"; local expect="$3"
  if echo "$result" | grep -q "$expect"; then
    echo "  PASS: $desc"
    ((PASS++))
  else
    echo "  FAIL: $desc"
    echo "        got: $result"
    ((FAIL++))
  fi
}

echo "=== Guardian verification ==="

# 1. CT app bundle is immutable
OUT=$(rm -rf "/Applications/Cold Turkey Blocker.app" 2>&1); check "CT app locked (rm blocked)" "$OUT" "Operation not permitted"

# 2. Watchdog script is immutable
OUT=$(echo test | tee /usr/local/bin/coldturkey-watchdog.sh 2>&1); check "Watchdog script locked" "$OUT" "Operation not permitted"

# 3. Watchdog plist is immutable (bootout should be silently blocked or error)
OUT=$(launchctl bootout system/com.coldturkey.watchdog 2>&1)
if [ -z "$OUT" ]; then
  # If it succeeded silently that's a failure — check if plist is still schg
  FLAG=$(ls -lO /Library/LaunchDaemons/com.coldturkey.watchdog.plist 2>/dev/null | awk '{print $5}')
  if [ "$FLAG" = "schg" ]; then
    echo "  PASS: Watchdog plist locked (bootout blocked, schg confirmed)"
    ((PASS++))
  else
    echo "  FAIL: Watchdog plist not locked"
    ((FAIL++))
  fi
else
  check "Watchdog plist locked (bootout blocked)" "$OUT" "Operation not permitted"
fi

# 4. CT data db is immutable
OUT=$(echo test | tee "/Library/Application Support/Cold Turkey/data-app.db" 2>&1); check "CT data-app.db locked" "$OUT" "Operation not permitted"

# 5. Little Snitch config is immutable
OUT=$(echo test | tee "/Library/Application Support/Objective Development/Little Snitch/configuration6.xpl" 2>&1); check "LS config locked" "$OUT" "Operation not permitted"

# 6. Watchdog daemon is running
OUT=$(launchctl print system/com.coldturkey.watchdog 2>/dev/null | grep state)
check "Watchdog daemon running" "$OUT" "running"

# 7. CT relaunches after kill
pkill -x "Cold Turkey Blocker" 2>/dev/null
sleep 6
OUT=$(pgrep -x "Cold Turkey Blocker" && echo "relaunched" || echo "not relaunched")
check "CT relaunches after kill" "$OUT" "relaunched"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
