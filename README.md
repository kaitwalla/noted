# Noted

A chat-style notes application with server sync, supporting web and iOS platforms.

## Features

- Multi-user authentication with JWT tokens
- Rich text notes with Tiptap editor
- Image attachments with S3-compatible storage
- To-do items with completion tracking
- Tags and notebooks for organization
- Full-text search
- Reminders and scheduled notes
- Offline-first iOS app with background sync

## Tech Stack

| Component | Technology |
|-----------|------------|
| Server | Go 1.23 + Chi router |
| Database | PostgreSQL 16 |
| Web Frontend | React 19 + TypeScript + Vite + Tiptap |
| State Management | Zustand |
| iOS | SwiftUI + Core Data |
| Image Storage | Local filesystem or S3-compatible (R2, DO Spaces, MinIO) |

## Getting Started

### Prerequisites

- Docker & Docker Compose
- Go 1.22+ (for manual setup)
- Node.js 20+ (for manual setup)
- Xcode 15+ (for iOS)

### Quick Start (Docker)

Start the full stack with one command:

```bash
docker compose up -d
```

| Service | URL |
|---------|-----|
| Web App | http://localhost:5175 |
| API | http://localhost:8081 |
| PostgreSQL | localhost:5434 |

View logs: `docker compose logs -f`
Stop: `docker compose down`

### Manual Setup

1. **Start the database:**
   ```bash
   docker compose up -d postgres
   ```

2. **Run the server:**
   ```bash
   cd server
   DATABASE_URL=postgres://noted:noted_dev_password@localhost:5434/noted?sslmode=disable go run ./cmd/server
   ```

3. **Run the web app:**
   ```bash
   cd web
   npm install
   npm run dev
   ```

### iOS Setup

1. Open `ios/Noted.xcodeproj` in Xcode 15+
2. Update the API URL in `Services/APIService.swift` if needed
3. Build and run on simulator or device

### Running Tests

```bash
# Start test database
docker compose up -d postgres-test

# Run server tests
cd server
go test ./... -v

# Run web tests
cd web
npm test
```

## Project Structure

```
noted/
├── server/                 # Go backend
│   ├── cmd/server/        # Entry point
│   ├── internal/
│   │   ├── api/           # HTTP handlers
│   │   ├── config/        # Configuration
│   │   ├── models/        # Domain types
│   │   ├── store/         # Database layer
│   │   └── testutil/      # Test helpers
│   └── migrations/        # SQL migrations
│
├── web/                    # React frontend
│   └── src/
│       ├── api/           # API client
│       ├── components/    # UI components
│       ├── store/         # State management
│       └── types/         # TypeScript types
│
├── ios/                    # iOS app
│   └── Noted/
│       ├── App/            # App entry point
│       ├── Views/          # SwiftUI screens
│       ├── ViewModels/     # MVVM logic
│       ├── Models/         # Data models
│       ├── Services/       # API client
│       └── CoreData/       # Local persistence
│
└── docker-compose.yml      # Local development services
```

## API Endpoints

### Authentication
- `POST /api/auth/register` - Create account
- `POST /api/auth/login` - Get JWT token
- `POST /api/auth/refresh` - Refresh token
- `GET /api/auth/me` - Current user info

### Notebooks
- `GET /api/notebooks` - List notebooks
- `POST /api/notebooks` - Create notebook
- `GET /api/notebooks/:id` - Get notebook
- `PUT /api/notebooks/:id` - Update notebook
- `DELETE /api/notebooks/:id` - Delete notebook

### Notes
- `GET /api/notebooks/:id/notes` - List notes in notebook
- `POST /api/notebooks/:id/notes` - Create note
- `GET /api/notes/:id` - Get note
- `PUT /api/notes/:id` - Update note
- `DELETE /api/notes/:id` - Delete note

### Tags
- `GET /api/tags` - List tags
- `POST /api/tags` - Create tag
- `PUT /api/tags/:id` - Update tag
- `DELETE /api/tags/:id` - Delete tag

### Search & Sync
- `GET /api/search?q=term` - Full-text search
- `GET /api/sync?since=timestamp` - Get changes since timestamp
- `POST /api/sync` - Push changes

## Environment Variables

See `.env.example` for all available options.

### Server
| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | 8080 | Server port |
| `DATABASE_URL` | (local) | PostgreSQL connection string |
| `JWT_SECRET` | dev-secret | JWT signing secret |
| `ALLOWED_ORIGINS` | localhost:5173,5175 | CORS allowed origins |

### Image Storage

Images can be stored locally or on S3-compatible services.

**Local storage (default):**
| Variable | Default | Description |
|----------|---------|-------------|
| `IMAGE_STORAGE_TYPE` | local | Storage backend |
| `IMAGE_STORAGE_PATH` | ./uploads | Local directory |

**S3-compatible storage:**
| Variable | Description |
|----------|-------------|
| `IMAGE_STORAGE_TYPE` | Set to `s3` |
| `S3_BUCKET` | Bucket name |
| `S3_REGION` | AWS region |
| `S3_ENDPOINT` | Custom endpoint (for R2, DO Spaces, MinIO) |
| `AWS_ACCESS_KEY_ID` | Access key |
| `AWS_SECRET_ACCESS_KEY` | Secret key |

### Web
| Variable | Default | Description |
|----------|---------|-------------|
| `VITE_API_URL` | http://localhost:8081/api | API base URL |

## License

MIT
