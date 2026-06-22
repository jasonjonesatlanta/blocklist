#!/bin/bash

# ── Abort if SIP is off ──
if ! csrutil status | grep -q "enabled"; then
  echo "ERROR: SIP is disabled. Enable SIP before running this script or protections will not hold."
  exit 1
fi

# ── Watchdog script: polls for CT, relaunches if missing OR stopped (SIGSTOP) ──
sudo tee /usr/local/bin/coldturkey-watchdog.sh > /dev/null << 'SCRIPT'
#!/bin/bash
while true; do
  CT_PID=$(pgrep -x "Cold Turkey Blocker" 2>/dev/null)
  CT_STATE=$(ps -o state= -p "$CT_PID" 2>/dev/null | tr -d ' ')
  if [ -z "$CT_PID" ] || [[ "$CT_STATE" == *T* ]]; then
    CONSOLE_UID=$(stat -f '%u' /dev/console 2>/dev/null)
    if [ -n "$CONSOLE_UID" ] && [ "$CONSOLE_UID" -gt 0 ]; then
      [ -n "$CT_PID" ] && kill -9 "$CT_PID" 2>/dev/null
      launchctl asuser "$CONSOLE_UID" /usr/bin/open -jg "/Applications/Cold Turkey Blocker.app"
    fi
  fi
  sleep 5
done
SCRIPT

# ── LaunchDaemon (system context, requires sudo to unload) ──
sudo tee /Library/LaunchDaemons/com.coldturkey.watchdog.plist > /dev/null << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.coldturkey.watchdog</string>
<key>ProgramArguments</key><array><string>/usr/local/bin/coldturkey-watchdog.sh</string></array>
<key>KeepAlive</key><true/><key>ThrottleInterval</key><integer>5</integer><key>RunAtLoad</key><true/>
</dict></plist>
PLIST

sudo chmod +x /usr/local/bin/coldturkey-watchdog.sh

# Disable CT's own built-in launch agent so it doesn't conflict
sudo launchctl bootout gui/$(id -u)/com.getcoldturkey.blocker.agent 2>/dev/null
sudo rm -f /Library/LaunchAgents/com.getcoldturkey.blocker.agent.plist

# ── Flush WAL to main db before locking ──
# Boot out launchkeep first so CT doesn't restart itself during checkpoint
sudo launchctl bootout system/launchkeep.cold-turkey 2>/dev/null
launchctl bootout gui/$(id -u)/launchkeep.cold-turkey 2>/dev/null
pkill -x "Cold Turkey Blocker" 2>/dev/null
# Wait for CT to fully exit before checkpointing
while pgrep -x "Cold Turkey Blocker" > /dev/null; do sleep 0.5; done
sqlite3 "/Library/Application Support/Cold Turkey/data-app.db" "PRAGMA wal_checkpoint(TRUNCATE);" 2>/dev/null

# ── Lock everything BEFORE starting watchdog to avoid race condition ──
sudo chflags schg /Library/LaunchDaemons/com.coldturkey.watchdog.plist
sudo chflags schg /usr/local/bin/coldturkey-watchdog.sh
sudo chflags -R schg "/Library/Application Support/Cold Turkey"
sudo chflags -R schg "/Applications/Cold Turkey Blocker.app"

# ── Lock Little Snitch ──
sudo chflags -R schg "/Applications/Little Snitch.app"
# Lock whichever config version exists (handles configuration6.xpl, configuration7.xpl, etc.)
for f in "/Library/Application Support/Objective Development/Little Snitch/configuration"*.xpl; do
  [ -f "$f" ] && sudo chflags schg "$f"
done
sudo chflags schg /Library/LaunchDaemons/at.obdev.littlesnitch.daemon.plist
sudo chflags schg /Library/LaunchAgents/at.obdev.littlesnitch.agent.plist

# ── Start watchdog AFTER all locks are applied ──
sudo launchctl bootstrap system /Library/LaunchDaemons/com.coldturkey.watchdog.plist

echo "All done"
