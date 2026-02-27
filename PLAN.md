# Noted - Chat-Style Notes App

A chat-style notes application (like Strflow/BoringNote) with server sync, supporting iOS and web platforms.

## Requirements

| Feature | Decision |
|---------|----------|
| Users | Multi-user with email/password auth |
| Content | Rich text + images |
| Organization | Tags + Notebooks |
| Features | To-dos, reminders, full-text search |
| iOS | Offline-first |
| Sync | Polling-based |
| Database | PostgreSQL |

## Tech Stack

| Component | Technology |
|-----------|------------|
| Server | Go + Chi router + PostgreSQL |
| Web | React + Tiptap (rich text) |
| iOS | SwiftUI + Core Data |
| Auth | JWT tokens |

## Development Environment (Docker)

All services run in Docker containers for consistent development:

```yaml
# docker-compose.yml
services:
  db:        # PostgreSQL 16
  server:    # Go API with hot reload (air)
  web:       # React dev server (Vite)
```

**Quick Start:**
```bash
docker compose up -d      # Start all services
docker compose logs -f    # View logs
docker compose down       # Stop all services
```

| Service | Port | Description |
|---------|------|-------------|
| db | 5432 | PostgreSQL database |
| server | 8080 | Go API server |
| web | 5173 | React dev server |

## Development Phases

### Phase 1: Server Foundation
- [ ] Project scaffolding (go mod, folder structure)
- [ ] Docker Compose for PostgreSQL
- [ ] Database migrations (users, notebooks, notes, tags)
- [ ] User registration & login with JWT
- [ ] Notebooks CRUD endpoints
- [ ] Notes CRUD endpoints
- [ ] Tests for all above

**Details**: [PLAN-Phase-1.md](./PLAN-Phase-1.md)

---

### Phase 2: Server Features
- [ ] Tags CRUD with note associations
- [ ] Full-text search using PostgreSQL tsvector
- [ ] Image upload/storage
- [ ] Sync endpoint implementation
- [ ] Reminders (scheduled_at field)
- [ ] Soft delete support
- [ ] Tests for all above

**Details**: [PLAN-Phase-2.md](./PLAN-Phase-2.md)

---

### Phase 3: Web App MVP
- [ ] Vite + React + TypeScript setup
- [ ] Auth pages (login, register)
- [ ] API client with auth token handling
- [ ] Notebook sidebar
- [ ] Chat-style note timeline view
- [ ] Rich text editor (Tiptap)
- [ ] Note creation (chat input at bottom)
- [ ] Tags display and filtering
- [ ] Component tests

**Details**: [PLAN-Phase-3.md](./PLAN-Phase-3.md)

---

### Phase 4: Web App Polish
- [ ] Full-text search UI
- [ ] To-do checkboxes in notes
- [ ] Reminders UI
- [ ] Image upload in editor
- [ ] Responsive design
- [ ] Error handling & loading states
- [ ] E2E tests with Playwright

**Details**: [PLAN-Phase-4.md](./PLAN-Phase-4.md)

---

### Phase 5: iOS App MVP
- [ ] Xcode project setup (SwiftUI)
- [ ] Core Data model
- [ ] Auth flow (login/register screens)
- [ ] API service layer
- [ ] Notebook list view
- [ ] Chat-style note timeline
- [ ] Note input (keyboard attached)
- [ ] Basic text editing
- [ ] Unit tests

**Details**: [PLAN-Phase-5.md](./PLAN-Phase-5.md)

---

### Phase 6: iOS Offline & Sync
- [ ] Local-only mode when offline
- [ ] Sync service implementation
- [ ] Change tracking (pending/synced status)
- [ ] Background sync task
- [ ] Conflict detection & resolution
- [ ] Sync status indicator in UI
- [ ] Tests for sync logic

**Details**: [PLAN-Phase-6.md](./PLAN-Phase-6.md)

---

### Phase 7: iOS Features & Polish
- [ ] Rich text support (AttributedString)
- [ ] Image capture & upload
- [ ] Tags
- [ ] To-do checkboxes
- [ ] Reminders with local notifications
- [ ] Search
- [ ] UI polish & animations
- [ ] UI tests

**Details**: [PLAN-Phase-7.md](./PLAN-Phase-7.md)

---

## Project Structure

```
noted/
├── server/                     # Go backend
│   ├── cmd/server/main.go
│   ├── internal/
│   │   ├── api/               # HTTP handlers
│   │   ├── models/            # Domain types
│   │   ├── store/             # Database layer
│   │   └── service/           # Business logic
│   ├── migrations/            # SQL migrations
│   └── go.mod
│
├── web/                        # React app
│   ├── src/
│   │   ├── components/
│   │   ├── pages/
│   │   ├── hooks/
│   │   ├── api/
│   │   └── store/
│   └── package.json
│
├── ios/                        # iOS app
│   └── Noted/
│       ├── App/
│       ├── Models/
│       ├── Views/
│       ├── ViewModels/
│       ├── Services/
│       └── CoreData/
│
└── docs/
    ├── ARCHITECTURE.md
    ├── API.md
    ├── SYNC_PROTOCOL.md
    └── TESTING.md
```

## Data Model

```
users (id, email, password_hash, created_at, updated_at)
  └── notebooks (id, user_id, title, created_at, updated_at, deleted_at)
        └── notes (id, notebook_id, user_id, content, plain_text,
                   is_todo, is_done, reminder_at, version,
                   created_at, updated_at, deleted_at)
              └── images (id, note_id, filename, mime_type, storage_key, created_at)

tags (id, user_id, name, color)
note_tags (note_id, tag_id)
```

## Documentation

| Doc | Purpose |
|-----|---------|
| `docs/ARCHITECTURE.md` | System overview |
| `docs/API.md` | Endpoint reference |
| `docs/SYNC_PROTOCOL.md` | Sync algorithm details |
| `docs/TESTING.md` | How to run tests |
