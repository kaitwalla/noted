# Phase 3: Web App MVP

**Goal**: Functional web app with auth, notebooks, and chat-style note timeline

## Tasks

### 3.1 Project Setup
- [ ] Initialize with Vite + React + TypeScript:
  ```bash
  npm create vite@latest web -- --template react-ts
  ```
- [ ] Add to Docker Compose:
  ```yaml
  web:
    build:
      context: ./web
      dockerfile: Dockerfile.dev
    ports:
      - "5173:5173"
    volumes:
      - ./web:/app
      - /app/node_modules
    environment:
      VITE_API_URL: http://localhost:8080
  ```
- [ ] Create `web/Dockerfile.dev` for development
- [ ] Install dependencies:
  ```bash
  npm install @tanstack/react-query axios zustand
  npm install @tiptap/react @tiptap/starter-kit @tiptap/extension-placeholder
  npm install react-router-dom date-fns
  npm install -D @types/node tailwindcss postcss autoprefixer
  ```
- [ ] Configure Tailwind CSS
- [ ] Set up ESLint + Prettier

### 3.2 Folder Structure
- [ ] Create structure:
  ```
  web/src/
  ├── api/
  │   ├── client.ts        # Axios instance with auth
  │   ├── auth.ts          # Auth API calls
  │   ├── notebooks.ts     # Notebook API calls
  │   └── notes.ts         # Note API calls
  ├── components/
  │   ├── auth/
  │   │   ├── LoginForm.tsx
  │   │   └── RegisterForm.tsx
  │   ├── layout/
  │   │   ├── Sidebar.tsx
  │   │   └── Header.tsx
  │   ├── notebooks/
  │   │   ├── NotebookList.tsx
  │   │   └── NotebookItem.tsx
  │   ├── notes/
  │   │   ├── NoteTimeline.tsx
  │   │   ├── NoteBubble.tsx
  │   │   ├── NoteEditor.tsx
  │   │   └── NoteInput.tsx
  │   └── common/
  │       ├── Button.tsx
  │       └── Input.tsx
  ├── hooks/
  │   ├── useAuth.ts
  │   ├── useNotebooks.ts
  │   └── useNotes.ts
  ├── pages/
  │   ├── LoginPage.tsx
  │   ├── RegisterPage.tsx
  │   ├── NotebooksPage.tsx
  │   └── NotebookPage.tsx
  ├── store/
  │   └── authStore.ts
  ├── types/
  │   └── index.ts
  └── App.tsx
  ```

### 3.3 API Client
- [ ] Create `api/client.ts`:
  - Axios instance with base URL from env
  - Request interceptor to add JWT token
  - Response interceptor for 401 handling (logout)
- [ ] Create `api/auth.ts`:
  - `register(email, password)`
  - `login(email, password)`
  - `getMe()`
- [ ] Create `api/notebooks.ts`:
  - `getNotebooks()`
  - `createNotebook(title)`
  - `updateNotebook(id, title)`
  - `deleteNotebook(id)`
- [ ] Create `api/notes.ts`:
  - `getNotes(notebookId, since?)`
  - `createNote(notebookId, content)`
  - `updateNote(id, content)`
  - `deleteNote(id)`

### 3.4 Auth Store & Flow
- [ ] Create `store/authStore.ts` with Zustand:
  ```typescript
  interface AuthStore {
      token: string | null
      user: User | null
      login: (email: string, password: string) => Promise<void>
      register: (email: string, password: string) => Promise<void>
      logout: () => void
  }
  ```
- [ ] Persist token to localStorage
- [ ] Create `hooks/useAuth.ts` hook
- [ ] Create protected route component

### 3.5 Auth Pages
- [ ] Create `pages/LoginPage.tsx`:
  - Email and password inputs
  - Login button
  - Link to register
  - Error display
- [ ] Create `pages/RegisterPage.tsx`:
  - Email and password inputs
  - Confirm password
  - Register button
  - Link to login
- [ ] Create `components/auth/LoginForm.tsx`
- [ ] Create `components/auth/RegisterForm.tsx`
- [ ] Add form validation

### 3.6 Layout & Routing
- [ ] Set up React Router in `App.tsx`:
  ```typescript
  <Routes>
    <Route path="/login" element={<LoginPage />} />
    <Route path="/register" element={<RegisterPage />} />
    <Route element={<ProtectedRoute />}>
      <Route path="/" element={<NotebooksPage />} />
      <Route path="/notebooks/:id" element={<NotebookPage />} />
    </Route>
  </Routes>
  ```
- [ ] Create `components/layout/Sidebar.tsx`:
  - Notebook list
  - New notebook button
  - User menu with logout
- [ ] Create main layout with sidebar + content area

### 3.7 Notebooks
- [ ] Create `hooks/useNotebooks.ts` with React Query:
  - Query for fetching notebooks
  - Mutations for create/update/delete
- [ ] Create `components/notebooks/NotebookList.tsx`:
  - List of notebooks
  - Active notebook highlight
  - Click to navigate
- [ ] Create `components/notebooks/NotebookItem.tsx`:
  - Notebook title
  - Edit/delete actions (dropdown)
- [ ] Create new notebook modal/form

### 3.8 Chat-Style Note Timeline
- [ ] Create `hooks/useNotes.ts` with React Query:
  - Query for fetching notes
  - Mutations for create/update/delete
  - Optimistic updates
- [ ] Create `components/notes/NoteTimeline.tsx`:
  - Scrollable container
  - Group notes by date
  - Auto-scroll to bottom on new note
- [ ] Create `components/notes/NoteBubble.tsx`:
  - Chat bubble styling (right-aligned like sent messages)
  - Timestamp display
  - Edit/delete on hover
  - Click to edit inline
- [ ] Create `components/notes/NoteInput.tsx`:
  - Fixed at bottom of viewport
  - Text area with send button
  - Submit on Enter (Shift+Enter for newline)

### 3.9 Rich Text Editor
- [ ] Create `components/notes/NoteEditor.tsx` with Tiptap:
  - Bold, italic, underline
  - Bullet/numbered lists
  - Code blocks
  - Links
  - Placeholder text
- [ ] Integrate editor into NoteInput
- [ ] Integrate editor into NoteBubble for inline editing
- [ ] Store content as Tiptap JSON

### 3.10 Tags Display
- [ ] Create `hooks/useTags.ts`
- [ ] Display tags on NoteBubble as colored pills
- [ ] Create tag filter in sidebar
- [ ] Filter notes by selected tag

### 3.11 Testing
- [ ] Set up Vitest + React Testing Library
- [ ] Create test utilities (mock providers, etc.)
- [ ] Write tests for:
  - Auth forms
  - NotebookList component
  - NoteTimeline component
  - NoteBubble component
  - API client
- [ ] Set up MSW for API mocking in tests

## Verification

```bash
# Start full stack
docker compose up -d

# Open web app
open http://localhost:5173

# Test flow:
1. Register new account
2. Login
3. Create notebook
4. Add notes (verify chat-style timeline)
5. Edit a note inline
6. Delete a note
7. Create tags and filter

# Run tests
cd web && npm test
```

## Files to Create

| File | Purpose |
|------|---------|
| `web/Dockerfile.dev` | Dev container |
| `web/src/api/client.ts` | API client |
| `web/src/api/*.ts` | API modules |
| `web/src/store/authStore.ts` | Auth state |
| `web/src/hooks/*.ts` | React hooks |
| `web/src/pages/*.tsx` | Page components |
| `web/src/components/**/*.tsx` | UI components |
| `web/src/types/index.ts` | TypeScript types |
| `web/src/__tests__/*.test.tsx` | Tests |

## UI Reference

Chat-style timeline (like Strflow):
```
┌─────────────────────────────────────┐
│ Sidebar        │ Notebook: Work     │
│ ─────────────  │ ─────────────────  │
│ > Work         │                    │
│   Personal     │        [Note 1   ] │ ← Right-aligned bubbles
│   Ideas        │        [with time] │
│                │                    │
│ + New Notebook │        [Note 2   ] │
│                │        [12:34 PM ] │
│ ─────────────  │                    │
│ Tags:          │        [Note 3   ] │
│ #work #ideas   │        [12:45 PM ] │
│                │ ─────────────────  │
│                │ [Type a note...  ] │ ← Input at bottom
│                │ [         Send ▶] │
└─────────────────────────────────────┘
```
