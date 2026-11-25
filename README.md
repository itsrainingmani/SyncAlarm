# SyncAlarm

Phone and watch alarm companion apps. Minimum deployment: iOS 17 / watchOS 10.

## Build

Install XcodeGen (`brew install xcodegen`), run `xcodegen generate`, and open
`SyncAlarm.xcodeproj`. Select your signing team and replace the `com.syncalarm.app`
bundle identifiers in `project.yml` with your registered identifiers before device installation.
The project is generated; source membership is declared in `project.yml`.

## Validation

Run `Scripts/test.sh` for storage/sync tests and iOS/watchOS compiler checks.
For a full unsigned build on a Mac with the iOS and watchOS platforms installed:

```
xcodegen generate
xcodebuild -project SyncAlarm.xcodeproj -scheme SyncAlarm -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

`Scripts/ci-workflow.yml.example` can be installed under `.github/workflows/` by
an account with workflow-write permission. The current GitHub OAuth credential
cannot publish workflow files.

## Sync protocol

Both apps must run the new protocol. Each alarm edit or deletion receives a Lamport
revision (counter plus device ID). The atomic record store is also the durable
outbox. Per-alarm merges reject stale revisions; deletion tombstones remain until a
future explicitly designed compaction protocol. Concurrent edits to one alarm use
a deterministic whole-alarm winner; edits to different alarms are preserved.

WatchConnectivity always publishes a background application context and adds a
live message/reply fast path when reachable. Background receipts use queued user
info. Receipts acknowledge only persisted, matching revisions. Activation,
reachability changes, foreground entry, and manual retry can resend safely.
Local-only records are excluded from every envelope. Sync confirmation means the
companion stored the current definition, not that alert scheduling succeeded.

## Local versus synced alarms

The creation form has a sync toggle independent of alert destinations. Local
alarms stay on the creating device; a swipe action can share one later. Once
shared, delete it on both devices and create a new local alarm to stop sharing;
editing an alarm preserves its scope. Existing alarms migrate as shared to
preserve the original app behavior.

Rows show **Only on this device**, **Waiting to sync**, or **Synced with companion**.
The last state requires evidence that the companion stored the current revision;
it does not assert current reachability or successful alert scheduling. Every
edit resets confirmation. Both lists expose retry and errors. The watch lists all
shared definitions, including alarms that alert only on iPhone.

## Alert behavior and remaining device validation

The current backend uses local notifications, with daily wall-clock schedules.
It is not an AlarmKit wake-up alarm and cannot promise audible delivery through
Silent mode or Focus. The watch uses ordinary notification sound; no critical-alert
entitlement is assumed. Scheduling runs through one serial worker after local
changes, remote merges, foreground entry, and authorization changes. Rows show
local scheduling health separately from sync confirmation. Scheduling failure on
the companion is not yet reported back as remote scheduling health.

Snooze schedules one separate nine-minute notification on the device where the
action was tapped. Stop dismisses the current occurrence and cancels that device's
snooze, keeping the daily alarm enabled. Neither action currently propagates to the
other device. Changes, deletion, disabling, or removing a destination cancel its
pending snooze. Requests outside the alarm category are preserved. WatchConnectivity
background tasks wait for pending delivery and scheduling work to finish.

Before release, build and install both apps with your signing configuration, then
validate on paired hardware with the debugger detached:

- Create local alarms on each device; verify they never appear on the companion.
- Create shared alarms targeting phone, watch, and both; verify pending then synced.
- Edit both devices offline, reconnect, and verify deterministic convergence.
- Delete an alarm before delivering an older snapshot; verify it stays deleted.
- Relaunch during sync; verify pending changes resume and confirmations persist.
- Remove a destination, disable, and delete; verify no old regular/snooze alert fires.
- Deny notification/sound permissions; verify synced and blocked are distinct.
- Snooze and stop from delivered notifications with both apps suspended.
- Check timezone changes, DST, reboot, locked phone, and watch out of range.

AlarmKit migration remains pending Xcode 26+ / iOS 26 SDK validation. The current
machine has Xcode 16.4 (iOS 18.5 / watchOS 11.5 SDKs); a full bundle build also reports
that the iOS platform is not installed. Unit tests and both platform compiler
checks pass, but do not substitute for the paired-device scenarios above.
