# Phase 7: iOS Features & Polish

**Goal**: Feature parity with web - rich text, images, tags, todos, reminders, search, polish

## Tasks

### 7.1 Rich Text Support
- [ ] Create `Views/Notes/RichTextView.swift`:
  - Display AttributedString content
  - Support bold, italic, underline
  - Support bullet/numbered lists
  - Support code blocks
  - Support links (tappable)
- [ ] Create `Views/Notes/RichTextEditor.swift`:
  - TextEditor with formatting toolbar
  - Formatting buttons (B, I, U, list, code)
  - Convert between AttributedString and JSON
- [ ] Update content storage format:
  ```json
  {
    "type": "doc",
    "content": [
      {"type": "paragraph", "content": [{"type": "text", "text": "Hello"}]},
      {"type": "paragraph", "content": [{"type": "text", "marks": [{"type": "bold"}], "text": "Bold"}]}
    ]
  }
  ```
- [ ] Parse Tiptap-compatible JSON format
- [ ] Ensure compatibility with web editor

### 7.2 Image Support
- [ ] Create `Services/ImageService.swift`:
  - `uploadImage(_ image: UIImage) async throws -> ImageRef`
  - `downloadImage(_ id: UUID) async throws -> UIImage`
  - Local image caching
- [ ] Create `Views/Notes/ImagePicker.swift`:
  - Camera capture
  - Photo library selection
  - Use PhotosPicker (iOS 16+)
- [ ] Add image button to note input
- [ ] Display images in NoteBubble:
  - Thumbnail in bubble
  - Tap for full-screen view
- [ ] Create `Views/Common/ImageViewer.swift`:
  - Full-screen image view
  - Pinch to zoom
  - Swipe to dismiss
- [ ] Handle image upload progress
- [ ] Cache images locally for offline access

### 7.3 Tags
- [ ] Create `ViewModels/TagsViewModel.swift`:
  - `fetchTags() async`
  - `createTag(name:color:) async`
  - `deleteTag(_ id:) async`
- [ ] Create `Views/Tags/TagsView.swift`:
  - List of user's tags
  - Create new tag
  - Edit/delete tags
- [ ] Create `Views/Tags/TagPicker.swift`:
  - Select tags for a note
  - Create new tag inline
- [ ] Create `Views/Tags/TagChip.swift`:
  - Colored tag pill component
- [ ] Display tags on NoteBubble
- [ ] Add tag filter to notebook view:
  - Filter button in toolbar
  - Multi-select tags
  - Show filtered notes

### 7.4 To-Do Checkboxes
- [ ] Update NoteBubble to show checkboxes:
  - Parse `is_todo` and `is_done` fields
  - Tappable checkbox
  - Strikethrough when done
- [ ] Add "Make todo" option in note context menu
- [ ] Create `Views/Todos/TodosView.swift`:
  - Tab for all todos
  - Group by notebook
  - Filter: all/pending/completed
  - Check off inline
- [ ] Update rich text editor for task lists

### 7.5 Reminders
- [ ] Request notification permissions on first use
- [ ] Create `Views/Notes/ReminderPicker.swift`:
  - Date picker
  - Time picker
  - Quick options (Later Today, Tomorrow, Next Week)
- [ ] Create `Services/NotificationService.swift`:
  - Schedule local notifications
  - Handle notification taps (deep link to note)
- [ ] Show reminder indicator on NoteBubble
- [ ] Create `Views/Reminders/RemindersView.swift`:
  - Tab for notes with reminders
  - Group by date (Today, Tomorrow, This Week, Later)
  - Edit/remove reminders
- [ ] Sync reminders - schedule notifications after sync

### 7.6 Search
- [ ] Create `Views/Search/SearchView.swift`:
  - Search bar
  - Live results as you type
  - Highlight matching text
  - Tap to navigate to note
- [ ] Create `ViewModels/SearchViewModel.swift`:
  - Local search (Core Data)
  - Server search (for online mode)
  - Debounced input
- [ ] Add search tab or button in navigation
- [ ] Search across all notebooks

### 7.7 Settings & Preferences
- [ ] Expand `Views/Settings/SettingsView.swift`:
  - Account section (email, logout)
  - Sync section (last sync, manual sync button)
  - Appearance section (theme if supporting dark mode)
  - Notifications section (enable/disable)
  - About section (version, licenses)
- [ ] Add sync status details
- [ ] Add data export option

### 7.8 UI Polish & Animations
- [ ] Add animations:
  - Note bubble appear animation
  - Swipe delete animation
  - Tab transitions
  - Pull-to-refresh
- [ ] Haptic feedback:
  - On note send
  - On checkbox toggle
  - On delete
- [ ] Loading states:
  - Skeleton loaders
  - Progress indicators
- [ ] Empty states:
  - No notebooks illustration
  - No notes illustration
  - No search results
- [ ] Error states with retry buttons
- [ ] Keyboard avoidance improvements
- [ ] Safe area handling

### 7.9 iPad Support
- [ ] Adaptive layout for larger screens
- [ ] Split view (sidebar + detail)
- [ ] Keyboard shortcuts
- [ ] Pointer/trackpad support

### 7.10 UI Tests
- [ ] Create UI test target
- [ ] Write UI tests using XCUITest:
  - `AuthUITests.swift` - Login/register flow
  - `NotebooksUITests.swift` - CRUD notebooks
  - `NotesUITests.swift` - CRUD notes, timeline scroll
  - `SearchUITests.swift` - Search flow
  - `OfflineUITests.swift` - Offline indicators
- [ ] Test on multiple device sizes
- [ ] Add to CI pipeline

### 7.11 Accessibility
- [ ] VoiceOver support:
  - Meaningful labels
  - Custom actions
  - Proper traits
- [ ] Dynamic Type support
- [ ] Reduce Motion support
- [ ] Color contrast compliance

### 7.12 Performance
- [ ] Profile with Instruments
- [ ] Optimize Core Data fetches (batch, pagination)
- [ ] Lazy loading for images
- [ ] Memory management for large note lists

## Verification

```bash
# Full feature test:
1. Create notebooks and notes
2. Add rich text formatting
3. Upload images
4. Add tags, filter by tag
5. Create todos, check them off
6. Set reminders, verify notifications
7. Search for notes
8. Test offline mode
9. Test on iPad

# Run UI tests
xcodebuild test -scheme NotedUITests -destination 'platform=iOS Simulator,name=iPhone 15'

# Test accessibility
# Enable VoiceOver in simulator
# Navigate entire app with VoiceOver
```

## Files to Create/Modify

| File | Purpose |
|------|---------|
| `ios/Noted/Views/Notes/RichTextView.swift` | Rich text display |
| `ios/Noted/Views/Notes/RichTextEditor.swift` | Rich text editing |
| `ios/Noted/Services/ImageService.swift` | Image upload/cache |
| `ios/Noted/Views/Notes/ImagePicker.swift` | Image selection |
| `ios/Noted/Views/Common/ImageViewer.swift` | Full-screen image |
| `ios/Noted/ViewModels/TagsViewModel.swift` | Tags logic |
| `ios/Noted/Views/Tags/*.swift` | Tags UI |
| `ios/Noted/Views/Todos/TodosView.swift` | Todos list |
| `ios/Noted/Views/Reminders/RemindersView.swift` | Reminders list |
| `ios/Noted/Views/Notes/ReminderPicker.swift` | Reminder picker |
| `ios/Noted/Services/NotificationService.swift` | Local notifications |
| `ios/Noted/Views/Search/SearchView.swift` | Search UI |
| `ios/Noted/ViewModels/SearchViewModel.swift` | Search logic |
| `ios/NotedUITests/*.swift` | UI tests |

## Final App Structure

```
┌─────────────────────────────────────────┐
│              Tab Bar                    │
├──────────┬──────────┬──────────┬───────┤
│ Notebooks│  Todos   │Reminders │Settings│
│    📒    │    ✓     │    🔔    │   ⚙️   │
└──────────┴──────────┴──────────┴───────┘

Notebooks Tab:
┌─────────────────────────────────────────┐
│ Notebooks              🔍  +            │
├─────────────────────────────────────────┤
│ ┌─────────────────────────────────────┐ │
│ │ Work                          12 ▶ │ │
│ ├─────────────────────────────────────┤ │
│ │ Personal                       8 ▶ │ │
│ ├─────────────────────────────────────┤ │
│ │ Ideas                          3 ▶ │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘

Note Timeline:
┌─────────────────────────────────────────┐
│ < Work                    🏷️  🔍       │
├─────────────────────────────────────────┤
│                    ┌──────────────────┐ │
│                    │ Meeting notes    │ │
│                    │ [x] Action item  │ │
│                    │ #work            │ │
│                    │         12:34 PM │ │
│                    └──────────────────┘ │
│                    ┌──────────────────┐ │
│                    │ [Image preview]  │ │
│                    │ Screenshot       │ │
│                    │         12:45 PM │ │
│                    └──────────────────┘ │
├─────────────────────────────────────────┤
│ [Type a note...    📷  🏷️  🔔  ]  ▶  │ │
└─────────────────────────────────────────┘
```
