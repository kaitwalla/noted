# Phase 5: iOS App MVP

**Goal**: Basic iOS app with auth, notebooks, and chat-style timeline (online mode)

## Tasks

### 5.1 Xcode Project Setup
- [ ] Create new Xcode project:
  - Product Name: Noted
  - Interface: SwiftUI
  - Language: Swift
  - Use Core Data: Yes
  - Include Tests: Yes
- [ ] Set deployment target: iOS 17.0
- [ ] Add package dependencies:
  - None initially (use URLSession, native frameworks)
- [ ] Create folder structure:
  ```
  ios/Noted/
  ├── App/
  │   ├── NotedApp.swift
  │   └── ContentView.swift
  ├── Models/
  │   ├── User.swift
  │   ├── Notebook.swift
  │   └── Note.swift
  ├── Views/
  │   ├── Auth/
  │   │   ├── LoginView.swift
  │   │   └── RegisterView.swift
  │   ├── Notebooks/
  │   │   ├── NotebookListView.swift
  │   │   └── NotebookRow.swift
  │   └── Notes/
  │       ├── NoteTimelineView.swift
  │       ├── NoteBubble.swift
  │       └── NoteInputView.swift
  ├── ViewModels/
  │   ├── AuthViewModel.swift
  │   ├── NotebooksViewModel.swift
  │   └── NotesViewModel.swift
  ├── Services/
  │   ├── APIService.swift
  │   ├── AuthService.swift
  │   └── KeychainService.swift
  └── CoreData/
      └── Noted.xcdatamodeld
  ```

### 5.2 Core Data Model
- [ ] Create Core Data entities:
  ```
  UserEntity
  - id: UUID
  - email: String
  - createdAt: Date

  NotebookEntity
  - id: UUID
  - title: String
  - createdAt: Date
  - updatedAt: Date
  - deletedAt: Date?
  - user: UserEntity

  NoteEntity
  - id: UUID
  - content: Binary (JSON data)
  - plainText: String
  - isTodo: Bool
  - isDone: Bool
  - reminderAt: Date?
  - version: Int64
  - createdAt: Date
  - updatedAt: Date
  - deletedAt: Date?
  - notebook: NotebookEntity

  TagEntity
  - id: UUID
  - name: String
  - color: String?
  - user: UserEntity

  NoteTagEntity
  - note: NoteEntity
  - tag: TagEntity
  ```
- [ ] Generate NSManagedObject subclasses
- [ ] Create `CoreDataStack.swift` for container management

### 5.3 API Service Layer
- [ ] Create `Services/APIService.swift`:
  ```swift
  class APIService {
      static let shared = APIService()
      let baseURL = URL(string: "http://localhost:8080/api")!
      var authToken: String?

      func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
  }
  ```
- [ ] Create `Services/AuthService.swift`:
  - `register(email:password:) async throws -> User`
  - `login(email:password:) async throws -> String` (returns token)
  - `getMe() async throws -> User`
- [ ] Create `Services/KeychainService.swift`:
  - Store/retrieve auth token securely
- [ ] Create Endpoint enum for type-safe API calls
- [ ] Handle API errors with custom error types

### 5.4 Auth ViewModel & Views
- [ ] Create `ViewModels/AuthViewModel.swift`:
  ```swift
  @Observable class AuthViewModel {
      var isAuthenticated = false
      var isLoading = false
      var errorMessage: String?

      func login(email: String, password: String) async
      func register(email: String, password: String) async
      func logout()
  }
  ```
- [ ] Create `Views/Auth/LoginView.swift`:
  - Email TextField
  - Password SecureField
  - Login Button
  - Link to Register
  - Error display
- [ ] Create `Views/Auth/RegisterView.swift`:
  - Email TextField
  - Password SecureField
  - Confirm Password
  - Register Button
- [ ] Add form validation
- [ ] Store token in Keychain on successful login

### 5.5 Notebooks ViewModel & Views
- [ ] Create `ViewModels/NotebooksViewModel.swift`:
  ```swift
  @Observable class NotebooksViewModel {
      var notebooks: [Notebook] = []
      var isLoading = false

      func fetchNotebooks() async
      func createNotebook(title: String) async
      func updateNotebook(_ id: UUID, title: String) async
      func deleteNotebook(_ id: UUID) async
  }
  ```
- [ ] Create `Views/Notebooks/NotebookListView.swift`:
  - List of notebooks
  - Pull to refresh
  - Swipe to delete
  - Add button in toolbar
- [ ] Create `Views/Notebooks/NotebookRow.swift`:
  - Notebook title
  - Note count (optional)
  - Navigation link to notes

### 5.6 Chat-Style Note Timeline
- [ ] Create `ViewModels/NotesViewModel.swift`:
  ```swift
  @Observable class NotesViewModel {
      var notes: [Note] = []
      var isLoading = false
      var notebookId: UUID

      func fetchNotes() async
      func createNote(content: String) async
      func updateNote(_ id: UUID, content: String) async
      func deleteNote(_ id: UUID) async
  }
  ```
- [ ] Create `Views/Notes/NoteTimelineView.swift`:
  - ScrollView with notes
  - Grouped by date
  - ScrollViewReader for auto-scroll to bottom
  - Pull to refresh
- [ ] Create `Views/Notes/NoteBubble.swift`:
  - Chat bubble appearance (right-aligned)
  - Timestamp below
  - Context menu for edit/delete
- [ ] Create `Views/Notes/NoteInputView.swift`:
  - TextField at bottom of screen
  - Send button
  - Keyboard avoidance

### 5.7 Basic Text Editing
- [ ] For MVP, use plain text (AttributedString in Phase 7)
- [ ] TextEditor for multi-line input
- [ ] Store as JSON with simple structure:
  ```json
  {"type": "text", "content": "Note text here"}
  ```
- [ ] Display formatted in NoteBubble

### 5.8 Navigation & App Structure
- [ ] Create `App/ContentView.swift`:
  ```swift
  struct ContentView: View {
      @State private var authVM = AuthViewModel()

      var body: some View {
          if authVM.isAuthenticated {
              MainTabView()
          } else {
              LoginView(viewModel: authVM)
          }
      }
  }
  ```
- [ ] Create tab-based navigation:
  - Notebooks tab
  - (Future: Todos, Reminders, Search)
  - Settings tab
- [ ] NavigationStack for notebook -> notes drill-down

### 5.9 Settings & Logout
- [ ] Create `Views/Settings/SettingsView.swift`:
  - User email display
  - Logout button
  - App version
- [ ] Implement logout (clear token, reset state)

### 5.10 Unit Tests
- [ ] Create test targets in Xcode
- [ ] Write tests for:
  - `AuthService` (mock URLSession)
  - `APIService` (mock responses)
  - `AuthViewModel` (mock service)
  - `NotebooksViewModel` (mock service)
  - `NotesViewModel` (mock service)
- [ ] Create mock protocols for dependency injection
- [ ] Achieve good coverage of business logic

## Verification

```bash
# Start server
docker compose up -d

# Build and run on simulator
# Xcode: Product > Run (Cmd+R)

# Or via command line
xcodebuild -scheme Noted -destination 'platform=iOS Simulator,name=iPhone 15' build

# Test flow:
1. Launch app
2. Register new account
3. Login
4. Create notebook
5. Add notes (verify chat-style timeline)
6. Edit a note
7. Delete a note
8. Logout

# Run tests
xcodebuild test -scheme Noted -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Files to Create

| File | Purpose |
|------|---------|
| `ios/Noted/App/NotedApp.swift` | App entry point |
| `ios/Noted/App/ContentView.swift` | Root view |
| `ios/Noted/CoreData/Noted.xcdatamodeld` | Core Data model |
| `ios/Noted/CoreData/CoreDataStack.swift` | CD container |
| `ios/Noted/Models/*.swift` | Domain models |
| `ios/Noted/Services/APIService.swift` | HTTP client |
| `ios/Noted/Services/AuthService.swift` | Auth logic |
| `ios/Noted/Services/KeychainService.swift` | Token storage |
| `ios/Noted/ViewModels/*.swift` | View models |
| `ios/Noted/Views/**/*.swift` | SwiftUI views |
| `ios/NotedTests/*.swift` | Unit tests |

## iOS Design Reference

```
┌─────────────────────────────┐
│ < Notebooks    Work    ... │  ← Navigation bar
├─────────────────────────────┤
│                             │
│              ┌────────────┐ │
│              │ First note │ │  ← Right-aligned bubble
│              │   12:34 PM │ │
│              └────────────┘ │
│                             │
│              ┌────────────┐ │
│              │Second note │ │
│              │   12:45 PM │ │
│              └────────────┘ │
│                             │
├─────────────────────────────┤
│ [Type a note...      ] [▶] │  ← Input bar (keyboard)
└─────────────────────────────┘
```
