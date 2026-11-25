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
