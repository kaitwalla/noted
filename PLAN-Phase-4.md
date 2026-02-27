# Phase 4: Web App Polish

**Goal**: Complete web features - search, to-dos, reminders, images, responsive design, E2E tests

## Tasks

### 4.1 Full-Text Search UI
- [ ] Create `components/search/SearchBar.tsx`:
  - Search input in header
  - Keyboard shortcut (Cmd/Ctrl+K)
  - Debounced search
- [ ] Create `components/search/SearchResults.tsx`:
  - Modal/dropdown with results
  - Highlight matching text
  - Click to navigate to note
- [ ] Create `hooks/useSearch.ts`:
  - Search query with React Query
  - Debounce input
- [ ] Add `api/search.ts`:
  - `searchNotes(query, limit)`

### 4.2 To-Do Checkboxes
- [ ] Add Tiptap TaskList extension
- [ ] Create checkbox styling in NoteEditor
- [ ] Update NoteBubble to render checkboxes
- [ ] Add "Mark as todo" button in editor toolbar
- [ ] Create `pages/TodosPage.tsx`:
  - List all incomplete todos across notebooks
  - Check off items inline
  - Click to navigate to source note

### 4.3 Reminders UI
- [ ] Add date picker for reminder_at field
- [ ] Create `components/notes/ReminderPicker.tsx`:
  - Date/time selection
  - Quick options (Tomorrow, Next Week)
- [ ] Show reminder indicator on NoteBubble
- [ ] Create `pages/RemindersPage.tsx`:
  - List notes with upcoming reminders
  - Group by date
- [ ] Add browser notifications (with permission request)
- [ ] Poll for due reminders and show notification

### 4.4 Image Upload
- [ ] Add Tiptap Image extension
- [ ] Create `components/notes/ImageUpload.tsx`:
  - Drag and drop support
  - Paste from clipboard
  - Progress indicator
- [ ] Add `api/images.ts`:
  - `uploadImage(file)`
  - `getImageUrl(id)`
- [ ] Display images in NoteBubble
- [ ] Image lightbox for full-size view

### 4.5 Responsive Design
- [ ] Mobile-first CSS with Tailwind breakpoints
- [ ] Collapsible sidebar on mobile
- [ ] Bottom navigation on mobile
- [ ] Touch-friendly interactions
- [ ] Test on various screen sizes:
  - Mobile (375px)
  - Tablet (768px)
  - Desktop (1024px+)

### 4.6 Error Handling & Loading States
- [ ] Create `components/common/ErrorBoundary.tsx`
- [ ] Create `components/common/LoadingSpinner.tsx`
- [ ] Create `components/common/Toast.tsx` for notifications
- [ ] Add loading skeletons for:
  - Notebook list
  - Note timeline
  - Search results
- [ ] Handle API errors gracefully:
  - Network errors (offline state)
  - 401 (redirect to login)
  - 500 (show error message)
- [ ] Add retry logic for failed requests

### 4.7 UX Improvements
- [ ] Keyboard shortcuts:
  - `n` - New note
  - `Cmd+Enter` - Submit note
  - `Escape` - Cancel editing
  - `Cmd+K` - Search
- [ ] Optimistic updates for note creation
- [ ] Confirmation dialogs for destructive actions
- [ ] Empty states (no notebooks, no notes)
- [ ] Onboarding for new users

### 4.8 E2E Tests with Playwright
- [ ] Install Playwright:
  ```bash
  npm install -D @playwright/test
  npx playwright install
  ```
- [ ] Create `e2e/` folder structure
- [ ] Write E2E tests:
  - `auth.spec.ts` - Register, login, logout
  - `notebooks.spec.ts` - CRUD notebooks
  - `notes.spec.ts` - Create, edit, delete notes
  - `search.spec.ts` - Search functionality
  - `todos.spec.ts` - Checkbox functionality
- [ ] Set up test database seeding
- [ ] Add to CI pipeline

### 4.9 Performance Optimization
- [ ] Implement virtual scrolling for long note lists
- [ ] Lazy load images
- [ ] Code split by route
- [ ] Memoize expensive components
- [ ] Add React DevTools profiling

### 4.10 Accessibility
- [ ] Proper heading hierarchy
- [ ] ARIA labels on interactive elements
- [ ] Keyboard navigation
- [ ] Focus management
- [ ] Color contrast compliance
- [ ] Screen reader testing

## Verification

```bash
# Run dev server
docker compose up -d

# Run component tests
cd web && npm test

# Run E2E tests
cd web && npx playwright test

# Test responsive design
# Open Chrome DevTools, test mobile/tablet/desktop viewports

# Test accessibility
# Run axe browser extension
# Test with VoiceOver/NVDA
```

## Files to Create/Modify

| File | Purpose |
|------|---------|
| `web/src/components/search/*.tsx` | Search UI |
| `web/src/components/notes/ReminderPicker.tsx` | Reminder picker |
| `web/src/components/notes/ImageUpload.tsx` | Image upload |
| `web/src/pages/TodosPage.tsx` | Todos view |
| `web/src/pages/RemindersPage.tsx` | Reminders view |
| `web/src/components/common/ErrorBoundary.tsx` | Error handling |
| `web/src/components/common/Toast.tsx` | Notifications |
| `web/e2e/*.spec.ts` | E2E tests |
| `web/playwright.config.ts` | Playwright config |

## Mobile Design Reference

```
┌─────────────────┐
│ ☰  Noted  🔍   │  ← Hamburger menu, search
│ ─────────────── │
│                 │
│    [Note 1    ] │  ← Full width bubbles
│    [12:34 PM  ] │
│                 │
│    [Note 2    ] │
│    [12:45 PM  ] │
│                 │
│ ─────────────── │
│ [Type here... ] │  ← Sticky input
│ ─────────────── │
│ 📒  ✓  🔔  👤  │  ← Bottom nav
└─────────────────┘
```
