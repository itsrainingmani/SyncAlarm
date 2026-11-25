# SyncAlarm

Phone and watch alarm companion apps. Minimum deployment: iOS 17 / watchOS 10.

## Build

Install XcodeGen (`brew install xcodegen`), run `xcodegen generate`, and open
`SyncAlarm.xcodeproj`. Select your signing team and replace the `com.syncalarm.app`
bundle identifiers in `project.yml` with your registered identifiers before device installation.
The project is generated; source membership is declared in `project.yml`.

## Validation

Run `Scripts/test.sh` for storage, sync, status, and scheduling tests plus
iOS/watchOS app and AlarmKit Live Activity compiler checks. No GitHub CI is configured;
validation is local before opening and merging each PR.
For a full unsigned build on a Mac with the iOS and watchOS platforms installed:

```
xcodegen generate
xcodebuild -project SyncAlarm.xcodeproj -target SyncAlarm -configuration Debug CODE_SIGNING_ALLOWED=NO build
```


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

Rows show **Settings only on this device**, **Waiting to sync**, or **Synced with companion**.
The last state requires evidence that the companion stored the current revision;
it does not assert current reachability or successful alert scheduling. Every
edit resets confirmation. Both lists expose retry and errors. The watch lists all
shared definitions, including alarms that alert only on iPhone.

## Alert behavior and remaining device validation

On iOS 26+, iPhone alarms use AlarmKit daily wall-clock schedules. Users must
grant **alarm permission**, separate from notification permission, using Enable
system alarms (or Settings if previously denied). Permission denial is shown as
blocked; the app does not silently switch to local notifications. Older iOS
versions and independent watch alerts continue using local notifications.

AlarmKit can present an iPhone alarm on a paired watch, independently of the app's
sync toggle and Watch destination. The Watch destination adds an independently
scheduled watch notification; selecting both can produce two alerts. Local-only
means the app does not sync the definition, not that the system cannot mirror an
alert. A phone-targeted alarm created on the watch still needs to reach the phone
and have AlarmKit authorization before it can be scheduled there.

AlarmKit includes a nine-minute snooze countdown and a Live Activity extension
for Lock Screen/Dynamic Island presentation, with a stop action. Unchanged system
alarms are left in place, preserving active snoozes across foreground entry and
repeated sync. Time/title edits cancel and recreate the same system ID; disabling, deleting,
or removing the phone destination cancels it. OS alarm and authorization updates
refresh local health separately from sync confirmation. Legacy phone notification
requests are removed after replacement succeeds, or when alarm permission is
not granted. A failed replacement remains visible and can be retried. A system-alarm edit
can leave the new schedule unarmed if creation fails after cancellation; the UI
reports this instead of claiming it is scheduled.

On the local-notification backend, snooze creates a separate nine-minute request.
Stop dismisses the occurrence and preserves daily recurrence. Watch notification
actions do not stop or snooze the separate phone system alarm. Companion scheduling
health is not yet sent back to the originating device. Paired system presentations
and independent watch notifications must be validated on hardware.

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

Implementation is compiled with Xcode 26.3 (17C529), iOS/watchOS 26.2 SDKs.
The local device inventory currently has only iOS 17/18 simulator runtimes, so
AlarmKit daemon authorization, ringing, snooze, and paired-watch presentation have
not been exercised at runtime. Unit tests use an injected fake system-alarm client
to cover scheduling, cancellation, failure recovery, and idempotence.
