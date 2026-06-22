# Blocklist Repo

## Git Identity

Always commit in this repo as:

```
git -c user.name="jasonjonesatlanta" -c user.email="jasonjonesatlanta@gmail.com" commit ...
```

Or set it locally before committing:

```
git config user.name "jasonjonesatlanta"
git config user.email "jasonjonesatlanta@gmail.com"
```

Every commit made in this repo must use the name `jasonjonesatlanta`.

---

## Cold Turkey Guardian Setup

### What `setup_coldturkey_guardian.sh` does

1. Installs a watchdog script at `/usr/local/bin/coldturkey-watchdog.sh` that polls every 5s and relaunches CT if it's not running
2. Installs a LaunchDaemon at `/Library/LaunchDaemons/com.coldturkey.watchdog.plist` — runs as root, requires sudo to unload
3. Uses `launchctl asuser <uid> open -jg` to relaunch CT in the user's GUI session (prevents focus stealing)
4. Removes CT's own built-in launch agent (`com.getcoldturkey.blocker.agent.plist`) to avoid conflicts
5. Boots out `launchkeep.cold-turkey` (CT's runtime-registered self-restart service) before killing CT
6. Checkpoints the SQLite WAL into the main db before locking
7. Locks with `chflags schg`: watchdog plist, watchdog script, CT data dir, CT app bundle, Little Snitch app, Little Snitch config, Little Snitch daemons
8. Aborts if SIP is off

### Key file locations

| Path | Purpose |
|------|---------|
| `/Library/LaunchDaemons/com.coldturkey.watchdog.plist` | Watchdog daemon |
| `/usr/local/bin/coldturkey-watchdog.sh` | Watchdog script |
| `/Library/Application Support/Cold Turkey/` | CT block config (SQLite databases) |
| `/Library/Application Support/Cold Turkey/data-app.db` | Main CT settings database (obfuscated, CTB-prefixed hex) |
| `/Library/Application Support/Objective Development/Little Snitch/configuration6.xpl` | Little Snitch rules |

### How Cold Turkey stores data

- Block config is NOT in `~/Library/Application Support/Cold Turkey/` — that directory doesn't exist
- Real data is in `/Library/Application Support/Cold Turkey/` (system-level)
- `data-app.db` is SQLite with a single `settings` table — value is obfuscated with a CTB prefix + hex-encoded encrypted blob
- `data-browser.db` and `data-helper.db` are stats only
- The plist files in `~/Library/Group Containers/group.getcoldturkey.blocker-shared-data/` and `~/Library/Group Containers/com.getcoldturkey.blocker-shared-data/` contain block list JSON but appear to be a secondary/cache store

### How to undo protections (requires SIP off or Recovery Mode)

```bash
sudo launchctl unload /Library/LaunchDaemons/com.coldturkey.watchdog.plist
sudo chflags noschg /Library/LaunchDaemons/com.coldturkey.watchdog.plist
sudo chflags noschg /usr/local/bin/coldturkey-watchdog.sh
sudo chflags -R noschg "/Library/Application Support/Cold Turkey"
sudo chflags -R noschg "/Applications/Cold Turkey Blocker.app"
sudo chflags -R noschg "/Applications/Little Snitch.app"
sudo chflags noschg "/Library/Application Support/Objective Development/Little Snitch/configuration6.xpl"
sudo chflags noschg /Library/LaunchDaemons/at.obdev.littlesnitch.daemon.plist
sudo chflags noschg /Library/LaunchAgents/at.obdev.littlesnitch.agent.plist
sudo rm -f /Library/LaunchDaemons/com.coldturkey.watchdog.plist /usr/local/bin/coldturkey-watchdog.sh
pkill -x "Cold Turkey Blocker"
```

### Known remaining holes

- **Firmware password not set** — without it, anyone can boot into Recovery Mode and disable SIP. Set via `System Settings → Privacy & Security → Startup Security` (Apple Silicon) or inside Recovery Mode (Intel)
- **Safe Mode** — holding Shift at boot disables LaunchDaemons; CT and Little Snitch won't run. Firmware password closes this
- **New admin account** — CT runs system-wide via LaunchDaemon so should be fine, but worth testing
- **System clock manipulation** — changing date forward can skip CT scheduled blocks
- **Network bypasses** — phone hotspot, VPN, DNS change bypasses network-level blocking
- **Little Snitch config rotation** — if LS writes `configuration7.xpl` after an update, the new file won't be locked

### Important notes

- **Do NOT modify `/Applications/Cold Turkey Blocker.app/Contents/Info.plist`** (e.g. adding `LSUIElement`) — breaks the code signature and CT shows "app needs to be reinstalled" repeatedly
- Run the setup script AFTER configuring all blocks in CT — the WAL checkpoint locks whatever state exists at that moment
- `chflags schg` is only unbypassable with SIP enabled — without SIP, root can remove the flag with `chflags noschg`
- CT's `launchkeep.cold-turkey` is registered at runtime by CT itself (no plist on disk) — it gets re-registered each time CT launches
