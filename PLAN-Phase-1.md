# Phase 1: Server Foundation

**Goal**: Working API with auth and basic CRUD, containerized development environment

## Tasks

### 1.1 Project Setup
- [ ] Create `server/go.mod` with module `github.com/noted/server`
- [ ] Set up folder structure:
  ```
  server/
  ├── cmd/server/main.go
  ├── internal/
  │   ├── api/
  │   ├── models/
  │   ├── store/
  │   └── service/
  ├── migrations/
  └── go.mod
  ```
- [ ] Install dependencies:
  - `github.com/go-chi/chi/v5` - Router
  - `github.com/jackc/pgx/v5` - PostgreSQL driver
  - `github.com/golang-jwt/jwt/v5` - JWT
  - `golang.org/x/crypto` - Password hashing
  - `github.com/rs/zerolog` - Logging

### 1.2 Docker Development Environment
- [ ] Create `docker-compose.yml`:
  ```yaml
  services:
    db:
      image: postgres:16
      environment:
        POSTGRES_USER: noted
        POSTGRES_PASSWORD: noted_dev
        POSTGRES_DB: noted
      ports:
        - "5432:5432"
      volumes:
        - postgres_data:/var/lib/postgresql/data

    server:
      build:
        context: ./server
        dockerfile: Dockerfile.dev
      ports:
        - "8080:8080"
      environment:
        DATABASE_URL: postgres://noted:noted_dev@db:5432/noted?sslmode=disable
        JWT_SECRET: dev-secret-change-in-prod
      volumes:
        - ./server:/app
      depends_on:
        - db
  ```
- [ ] Create `server/Dockerfile.dev` with hot reload (air)
- [ ] Create `server/Dockerfile` for production build
- [ ] Add `.env.example` with required environment variables

### 1.3 Database Migrations
- [ ] Install migrate tool or use golang-migrate
- [ ] Create `migrations/001_initial.up.sql`:
  ```sql
  -- Users table
  CREATE TABLE users (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      email VARCHAR(255) UNIQUE NOT NULL,
      password_hash VARCHAR(255) NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );

  -- Notebooks table
  CREATE TABLE notebooks (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      title VARCHAR(255) NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      deleted_at TIMESTAMPTZ
  );

  -- Notes table
  CREATE TABLE notes (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      notebook_id UUID NOT NULL REFERENCES notebooks(id) ON DELETE CASCADE,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      content JSONB NOT NULL DEFAULT '{}',
      plain_text TEXT NOT NULL DEFAULT '',
      is_todo BOOLEAN NOT NULL DEFAULT FALSE,
      is_done BOOLEAN NOT NULL DEFAULT FALSE,
      reminder_at TIMESTAMPTZ,
      version INTEGER NOT NULL DEFAULT 1,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      deleted_at TIMESTAMPTZ
  );

  -- Indexes
  CREATE INDEX idx_notebooks_user_id ON notebooks(user_id);
  CREATE INDEX idx_notes_notebook_id ON notes(notebook_id);
  CREATE INDEX idx_notes_user_id ON notes(user_id);
  CREATE INDEX idx_notes_updated_at ON notes(updated_at);
  ```
- [ ] Create corresponding `.down.sql` migration
- [ ] Test migrations run successfully

### 1.4 Domain Models
- [ ] Create `internal/models/user.go`:
  ```go
  type User struct {
      ID           uuid.UUID
      Email        string
      PasswordHash string
      CreatedAt    time.Time
      UpdatedAt    time.Time
  }
  ```
- [ ] Create `internal/models/notebook.go`
- [ ] Create `internal/models/note.go`
- [ ] Create request/response DTOs

### 1.5 Database Store Layer
- [ ] Create `internal/store/store.go` interface:
  ```go
  type Store interface {
      UserStore
      NotebookStore
      NoteStore
  }
  ```
- [ ] Implement `internal/store/postgres/user.go`:
  - `CreateUser(ctx, email, passwordHash) (*User, error)`
  - `GetUserByEmail(ctx, email) (*User, error)`
  - `GetUserByID(ctx, id) (*User, error)`
- [ ] Implement `internal/store/postgres/notebook.go`:
  - `CreateNotebook(ctx, userID, title) (*Notebook, error)`
  - `GetNotebooks(ctx, userID) ([]Notebook, error)`
  - `GetNotebook(ctx, id) (*Notebook, error)`
  - `UpdateNotebook(ctx, id, title) (*Notebook, error)`
  - `DeleteNotebook(ctx, id) error`
- [ ] Implement `internal/store/postgres/note.go`:
  - `CreateNote(ctx, notebookID, userID, content) (*Note, error)`
  - `GetNotes(ctx, notebookID, since time.Time) ([]Note, error)`
  - `GetNote(ctx, id) (*Note, error)`
  - `UpdateNote(ctx, id, content, version) (*Note, error)`
  - `DeleteNote(ctx, id) error`

### 1.6 Authentication
- [ ] Create `internal/service/auth.go`:
  - `Register(ctx, email, password) (*User, error)`
  - `Login(ctx, email, password) (token string, error)`
  - `ValidateToken(token) (*Claims, error)`
- [ ] Implement password hashing with bcrypt
- [ ] Implement JWT token generation/validation
- [ ] Create auth middleware for protected routes

### 1.7 API Handlers
- [ ] Create `internal/api/router.go` with route setup
- [ ] Create `internal/api/auth.go`:
  - `POST /api/auth/register`
  - `POST /api/auth/login`
  - `GET /api/auth/me`
- [ ] Create `internal/api/notebooks.go`:
  - `GET /api/notebooks`
  - `POST /api/notebooks`
  - `GET /api/notebooks/:id`
  - `PUT /api/notebooks/:id`
  - `DELETE /api/notebooks/:id`
- [ ] Create `internal/api/notes.go`:
  - `GET /api/notebooks/:id/notes`
  - `POST /api/notebooks/:id/notes`
  - `GET /api/notes/:id`
  - `PUT /api/notes/:id`
  - `DELETE /api/notes/:id`
- [ ] Create `internal/api/middleware.go` for auth, logging, CORS

### 1.8 Testing
- [ ] Set up test infrastructure with testcontainers-go
- [ ] Create `internal/testutil/db.go` for test database setup
- [ ] Write unit tests for auth service
- [ ] Write integration tests for store layer
- [ ] Write API tests for all endpoints using httptest
- [ ] Achieve 80%+ test coverage

## Verification

```bash
# Start development environment
docker compose up -d

# Run migrations
go run cmd/migrate/main.go up

# Run tests
go test ./... -v -cover

# Test API manually
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
# Returns: {"token": "eyJ..."}

curl -X GET http://localhost:8080/api/notebooks \
  -H "Authorization: Bearer eyJ..."
```

## Files to Create

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Dev environment |
| `server/Dockerfile.dev` | Dev container with hot reload |
| `server/Dockerfile` | Production build |
| `server/go.mod` | Go module |
| `server/cmd/server/main.go` | Entry point |
| `server/internal/models/*.go` | Domain types |
| `server/internal/store/store.go` | Store interface |
| `server/internal/store/postgres/*.go` | PostgreSQL implementation |
| `server/internal/service/auth.go` | Auth logic |
| `server/internal/api/*.go` | HTTP handlers |
| `server/migrations/001_initial.*.sql` | Database schema |
| `server/internal/testutil/db.go` | Test helpers |
| `server/*_test.go` | Tests |

## Dependencies

```
github.com/go-chi/chi/v5
github.com/jackc/pgx/v5
github.com/golang-jwt/jwt/v5
github.com/google/uuid
golang.org/x/crypto
github.com/rs/zerolog
github.com/testcontainers/testcontainers-go (test)
github.com/stretchr/testify (test)
```
