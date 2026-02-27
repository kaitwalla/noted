# Phase 6: iOS Offline & Sync

**Goal**: Full offline-first functionality with background sync

## Tasks

### 6.1 Offline Data Layer
- [ ] Update Core Data model with sync fields:
  ```
  All entities add:
  - syncStatus: Int16 (0=synced, 1=pending, 2=conflict)
  - locallyModifiedAt: Date?
  - serverVersion: Int64
  ```
- [ ] Create `Services/LocalDataService.swift`:
  - CRUD operations on Core Data
  - Mark items as pending sync
  - Query pending changes
- [ ] Modify ViewModels to use LocalDataService:
  - Write to Core Data first (optimistic)
  - Trigger sync in background

### 6.2 Sync Service
- [ ] Create `Services/SyncService.swift`:
  ```swift
  class SyncService {
      func sync() async throws {
          // 1. Pull remote changes since lastSyncTime
          // 2. Merge into local Core Data
          // 3. Push pending local changes
          // 4. Handle conflicts
          // 5. Update lastSyncTime
      }

      func pullChanges(since: Date) async throws -> SyncResponse
      func pushChanges(_ changes: SyncRequest) async throws -> SyncResponse
      func mergeRemoteChanges(_ response: SyncResponse)
  }
  ```
- [ ] Store `lastSyncTime` in UserDefaults
- [ ] Create `Models/SyncModels.swift`:
  - `SyncRequest`, `SyncResponse`, `Conflict`

### 6.3 Change Tracking
- [ ] Implement change tracking in LocalDataService:
  ```swift
  func createNote(_ note: Note) {
      let entity = NoteEntity(context: context)
      entity.syncStatus = .pending
      entity.locallyModifiedAt = Date()
      // ... set other fields
      save()
  }

  func getPendingChanges() -> PendingChanges {
      // Query all entities where syncStatus == .pending
  }
  ```
- [ ] Track creates, updates, and deletes separately
- [ ] Handle soft deletes (mark deleted, sync, then remove)

### 6.4 Conflict Resolution
- [ ] Implement last-write-wins strategy:
  ```swift
  func resolveConflict(_ local: NoteEntity, _ remote: Note) -> Note {
      // Compare versions and timestamps
      if remote.version > local.serverVersion {
          // Remote wins - update local
          return remote
      } else {
          // Local wins - will be pushed in next sync
          return local.toNote()
      }
  }
  ```
- [ ] Store conflicts for user review (optional):
  - Show conflict indicator
  - Let user choose which version to keep
- [ ] Log conflicts for debugging

### 6.5 Network Reachability
- [ ] Create `Services/NetworkMonitor.swift`:
  ```swift
  @Observable class NetworkMonitor {
      var isConnected: Bool = true

      init() {
          let monitor = NWPathMonitor()
          monitor.pathUpdateHandler = { path in
              self.isConnected = path.status == .satisfied
          }
          monitor.start(queue: .main)
      }
  }
  ```
- [ ] Show offline indicator in UI
- [ ] Queue operations when offline
- [ ] Sync automatically when coming back online

### 6.6 Background Sync
- [ ] Register background task in `NotedApp.swift`:
  ```swift
  .backgroundTask(.appRefresh("sync")) {
      await SyncService.shared.sync()
  }
  ```
- [ ] Schedule periodic background refresh:
  ```swift
  func scheduleBackgroundSync() {
      let request = BGAppRefreshTaskRequest(identifier: "sync")
      request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
      try? BGTaskScheduler.shared.submit(request)
  }
  ```
- [ ] Handle background fetch events
- [ ] Respect battery and data constraints

### 6.7 Sync Status UI
- [ ] Create sync status indicator:
  - Syncing spinner
  - Last synced time
  - Offline indicator
  - Error indicator
- [ ] Add to navigation bar or settings
- [ ] Show pending count badge
- [ ] Manual sync button

### 6.8 Pull-to-Refresh Sync
- [ ] Add `.refreshable` to list views
- [ ] Trigger full sync on pull
- [ ] Show sync progress

### 6.9 Error Handling
- [ ] Handle sync errors gracefully:
  - Network timeout
  - Server errors (5xx)
  - Auth expired (401)
  - Conflict errors
- [ ] Retry logic with exponential backoff
- [ ] Store failed operations for retry
- [ ] Show user-friendly error messages

### 6.10 Sync Tests
- [ ] Create mock server responses
- [ ] Test scenarios:
  - Fresh sync (no local data)
  - Incremental sync (pull new items)
  - Push local changes
  - Conflict resolution
  - Offline -> online transition
  - Background sync
- [ ] Test Core Data operations
- [ ] Test change tracking

## Verification

```bash
# Test offline mode:
1. Add notes while online
2. Turn on airplane mode
3. Add more notes (should work)
4. Turn off airplane mode
5. Verify notes sync to server

# Test conflict:
1. Add note on iOS
2. Edit same note on web before sync
3. Sync iOS
4. Verify conflict resolution

# Test background sync:
1. Add notes
2. Background the app
3. Wait 15+ minutes
4. Check server for synced notes

# Run tests
xcodebuild test -scheme Noted -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Files to Create/Modify

| File | Purpose |
|------|---------|
| `ios/Noted/Services/SyncService.swift` | Sync logic |
| `ios/Noted/Services/LocalDataService.swift` | Core Data operations |
| `ios/Noted/Services/NetworkMonitor.swift` | Connectivity |
| `ios/Noted/Models/SyncModels.swift` | Sync DTOs |
| `ios/Noted/Views/Common/SyncStatusView.swift` | Sync indicator |
| `ios/Noted/CoreData/Noted.xcdatamodeld` | Add sync fields |
| `ios/NotedTests/SyncServiceTests.swift` | Sync tests |

## Sync Flow Diagram

```
┌─────────────────────────────────────────────────────┐
│                    iOS App                          │
│  ┌─────────┐    ┌──────────┐    ┌───────────────┐  │
│  │ UI      │───▶│ ViewModel│───▶│LocalDataService│  │
│  │(SwiftUI)│    │          │    │  (Core Data)   │  │
│  └─────────┘    └──────────┘    └───────────────┘  │
│                       │                  │          │
│                       │                  │          │
│                       ▼                  ▼          │
│                 ┌───────────┐    ┌─────────────┐   │
│                 │SyncService│◀──▶│ Change      │   │
│                 │           │    │ Tracker     │   │
│                 └───────────┘    └─────────────┘   │
│                       │                             │
└───────────────────────│─────────────────────────────┘
                        │
                        ▼
                 ┌─────────────┐
                 │   Server    │
                 │ GET/POST    │
                 │ /api/sync   │
                 └─────────────┘
```

## Sync Algorithm

```
SYNC():
  1. Get lastSyncTime from storage
  2. GET /api/sync?since=lastSyncTime
  3. For each remote change:
     - If not in local DB: INSERT
     - If in local DB and not pending: UPDATE
     - If in local DB and pending: RESOLVE CONFLICT
  4. Get all pending local changes
  5. POST /api/sync with pending changes
  6. For each successful push: mark as synced
  7. Update lastSyncTime to response.syncedAt
```
