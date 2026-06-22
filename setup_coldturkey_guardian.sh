#!/bin/bash
sudo tee /Library/LaunchDaemons/com.coldturkey.guardian.plist > /dev/null << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.coldturkey.guardian</string>
<key>ProgramArguments</key><array><string>/Applications/Cold Turkey Blocker.app/Contents/MacOS/Cold Turkey Blocker</string></array>
<key>KeepAlive</key><true/><key>ThrottleInterval</key><integer>1</integer><key>RunAtLoad</key><true/>
<key>AbandonProcessGroup</key><true/>
</dict></plist>
PLIST

sudo tee /usr/local/bin/coldturkey-watchdog.sh > /dev/null << 'SCRIPT'
#!/bin/bash
while true; do
  launchctl list 2>/dev/null | grep -q "com.coldturkey.guardian" || launchctl load -w /Library/LaunchDaemons/com.coldturkey.guardian.plist 2>/dev/null
  sleep 3
done
SCRIPT

sudo tee /Library/LaunchDaemons/com.coldturkey.watchdog.plist > /dev/null << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.coldturkey.watchdog</string>
<key>ProgramArguments</key><array><string>/usr/local/bin/coldturkey-watchdog.sh</string></array>
<key>KeepAlive</key><true/><key>ThrottleInterval</key><integer>1</integer><key>RunAtLoad</key><true/>
</dict></plist>
PLIST

sudo chmod +x /usr/local/bin/coldturkey-watchdog.sh

# Disable CT's own built-in launch agent so it doesn't conflict with guardian
sudo launchctl bootout gui/$(id -u)/com.getcoldturkey.blocker.agent 2>/dev/null
sudo rm -f /Library/LaunchAgents/com.getcoldturkey.blocker.agent.plist

sudo launchctl load -w /Library/LaunchDaemons/com.coldturkey.guardian.plist
sudo launchctl load -w /Library/LaunchDaemons/com.coldturkey.watchdog.plist
sudo chflags schg /Library/LaunchDaemons/com.coldturkey.guardian.plist
sudo chflags schg /Library/LaunchDaemons/com.coldturkey.watchdog.plist
sudo chflags schg /usr/local/bin/coldturkey-watchdog.sh

# Flush WAL to main db before locking
pkill -x "Cold Turkey Blocker" 2>/dev/null
sleep 2
sqlite3 "/Library/Application Support/Cold Turkey/data-app.db" "PRAGMA wal_checkpoint(TRUNCATE);" 2>/dev/null
sudo chflags -R schg "/Library/Application Support/Cold Turkey"

echo "All done"
