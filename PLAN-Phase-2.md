# Phase 2: Server Features

**Goal**: Complete server functionality - tags, search, images, sync, reminders

## Tasks

### 2.1 Tags System
- [ ] Add tags migration `002_tags.up.sql`:
  ```sql
  CREATE TABLE tags (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      name VARCHAR(100) NOT NULL,
      color VARCHAR(7), -- hex color like #FF5733
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE(user_id, name)
  );

  CREATE TABLE note_tags (
      note_id UUID NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
      tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
      PRIMARY KEY (note_id, tag_id)
  );

  CREATE INDEX idx_tags_user_id ON tags(user_id);
  CREATE INDEX idx_note_tags_note_id ON note_tags(note_id);
  CREATE INDEX idx_note_tags_tag_id ON note_tags(tag_id);
  ```
- [ ] Create `internal/models/tag.go`
- [ ] Implement `internal/store/postgres/tag.go`:
  - `CreateTag(ctx, userID, name, color) (*Tag, error)`
  - `GetTags(ctx, userID) ([]Tag, error)`
  - `UpdateTag(ctx, id, name, color) (*Tag, error)`
  - `DeleteTag(ctx, id) error`
  - `AddTagToNote(ctx, noteID, tagID) error`
  - `RemoveTagFromNote(ctx, noteID, tagID) error`
  - `GetNoteTags(ctx, noteID) ([]Tag, error)`
- [ ] Create `internal/api/tags.go`:
  - `GET /api/tags`
  - `POST /api/tags`
  - `PUT /api/tags/:id`
  - `DELETE /api/tags/:id`
- [ ] Update notes API to include/manage tags
- [ ] Write tests for tags

### 2.2 Full-Text Search
- [ ] Add search migration `003_search.up.sql`:
  ```sql
  -- Add full-text search column
  ALTER TABLE notes ADD COLUMN search_vector tsvector
      GENERATED ALWAYS AS (to_tsvector('english', plain_text)) STORED;

  CREATE INDEX idx_notes_search ON notes USING GIN(search_vector);
  ```
- [ ] Implement `internal/store/postgres/search.go`:
  - `SearchNotes(ctx, userID, query string, limit int) ([]Note, error)`
- [ ] Create `internal/api/search.go`:
  - `GET /api/search?q=term&limit=20`
- [ ] Write tests for search

### 2.3 Image Upload
- [ ] Add images migration `004_images.up.sql`:
  ```sql
  CREATE TABLE images (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      note_id UUID REFERENCES notes(id) ON DELETE SET NULL,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      filename VARCHAR(255) NOT NULL,
      mime_type VARCHAR(100) NOT NULL,
      size_bytes INTEGER NOT NULL,
      storage_key VARCHAR(500) NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );

  CREATE INDEX idx_images_note_id ON images(note_id);
  CREATE INDEX idx_images_user_id ON images(user_id);
  ```
- [ ] Create `internal/service/storage.go` interface:
  ```go
  type StorageService interface {
      Upload(ctx, reader io.Reader, filename string) (key string, error)
      Download(ctx, key string) (io.ReadCloser, error)
      Delete(ctx, key string) error
      GetURL(key string) string
  }
  ```
- [ ] Implement local filesystem storage (dev)
- [ ] Implement S3-compatible storage (optional, for prod)
- [ ] Create `internal/store/postgres/image.go`:
  - `CreateImage(ctx, noteID, userID, filename, mimeType, size, storageKey) (*Image, error)`
  - `GetImage(ctx, id) (*Image, error)`
  - `GetNoteImages(ctx, noteID) ([]Image, error)`
  - `DeleteImage(ctx, id) error`
- [ ] Create `internal/api/images.go`:
  - `POST /api/images` (multipart upload)
  - `GET /api/images/:id`
  - `DELETE /api/images/:id`
- [ ] Add image serving endpoint or signed URL generation
- [ ] Write tests for image upload/download

### 2.4 Sync Endpoint
- [ ] Create `internal/models/sync.go`:
  ```go
  type SyncRequest struct {
      Since     time.Time
      Notebooks []NotebookChange
      Notes     []NoteChange
      Tags      []TagChange
  }

  type SyncResponse struct {
      Notebooks []Notebook
      Notes     []Note
      Tags      []Tag
      Conflicts []Conflict
      SyncedAt  time.Time
  }
  ```
- [ ] Implement `internal/service/sync.go`:
  - `GetChanges(ctx, userID, since time.Time) (*SyncResponse, error)`
  - `PushChanges(ctx, userID, changes *SyncRequest) (*SyncResponse, error)`
  - Conflict detection using version numbers
- [ ] Create `internal/api/sync.go`:
  - `GET /api/sync?since=2024-01-01T00:00:00Z`
  - `POST /api/sync` (push changes)
- [ ] Handle soft-deleted items in sync response
- [ ] Write tests for sync logic

### 2.5 Reminders
- [ ] Update note model to track reminder status
- [ ] Create `internal/service/reminder.go`:
  - `GetDueReminders(ctx, userID) ([]Note, error)`
  - Logic to surface notes when `reminder_at` <= now
- [ ] Add reminder filtering to notes API:
  - `GET /api/notes/reminders` - get notes with upcoming reminders
- [ ] Write tests for reminders

### 2.6 Soft Delete Support
- [ ] Ensure all DELETE endpoints set `deleted_at` instead of hard delete
- [ ] Add `deleted_at` filter to all GET queries (exclude deleted by default)
- [ ] Add `?include_deleted=true` query param for sync
- [ ] Create cleanup job for permanently deleting old soft-deleted items
- [ ] Write tests for soft delete behavior

### 2.7 API Documentation
- [ ] Add OpenAPI/Swagger spec generation
- [ ] Create `docs/API.md` with endpoint documentation
- [ ] Add example requests/responses

## Verification

```bash
# Run all tests
go test ./... -v -cover

# Test search
curl "http://localhost:8080/api/search?q=meeting" \
  -H "Authorization: Bearer $TOKEN"

# Test image upload
curl -X POST http://localhost:8080/api/images \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@test.jpg"

# Test sync
curl "http://localhost:8080/api/sync?since=2024-01-01T00:00:00Z" \
  -H "Authorization: Bearer $TOKEN"

# Test tags
curl -X POST http://localhost:8080/api/tags \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"work","color":"#FF5733"}'
```

## Files to Create/Modify

| File | Purpose |
|------|---------|
| `server/migrations/002_tags.*.sql` | Tags schema |
| `server/migrations/003_search.*.sql` | FTS setup |
| `server/migrations/004_images.*.sql` | Images schema |
| `server/internal/models/tag.go` | Tag model |
| `server/internal/models/image.go` | Image model |
| `server/internal/models/sync.go` | Sync DTOs |
| `server/internal/store/postgres/tag.go` | Tag store |
| `server/internal/store/postgres/image.go` | Image store |
| `server/internal/store/postgres/search.go` | Search queries |
| `server/internal/service/storage.go` | File storage |
| `server/internal/service/sync.go` | Sync logic |
| `server/internal/service/reminder.go` | Reminder logic |
| `server/internal/api/tags.go` | Tag handlers |
| `server/internal/api/images.go` | Image handlers |
| `server/internal/api/search.go` | Search handler |
| `server/internal/api/sync.go` | Sync handlers |
| `docs/API.md` | API documentation |
