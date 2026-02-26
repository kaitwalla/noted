package models

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

// User represents a user account
type User struct {
	ID           uuid.UUID  `json:"id"`
	Email        string     `json:"email"`
	PasswordHash string     `json:"-"`
	CreatedAt    time.Time  `json:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at"`
	DeletedAt    *time.Time `json:"-"`
}

// Notebook represents a collection of notes
type Notebook struct {
	ID        uuid.UUID  `json:"id"`
	UserID    uuid.UUID  `json:"user_id"`
	Title     string     `json:"title"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
	DeletedAt *time.Time `json:"deleted_at,omitempty"`
}

// Note represents a single note entry
type Note struct {
	ID         uuid.UUID       `json:"id"`
	NotebookID uuid.UUID       `json:"notebook_id"`
	UserID     uuid.UUID       `json:"user_id"`
	Content    json.RawMessage `json:"content"`
	PlainText  string          `json:"plain_text,omitempty"`
	IsTodo     bool            `json:"is_todo"`
	IsDone     bool            `json:"is_done"`
	ReminderAt *time.Time      `json:"reminder_at,omitempty"`
	Version    int64           `json:"version"`
	CreatedAt  time.Time       `json:"created_at"`
	UpdatedAt  time.Time       `json:"updated_at"`
	DeletedAt  *time.Time      `json:"deleted_at,omitempty"`
	Tags       []Tag           `json:"tags,omitempty"`
}

// Tag represents a label for notes
type Tag struct {
	ID        uuid.UUID  `json:"id"`
	UserID    uuid.UUID  `json:"user_id"`
	Name      string     `json:"name"`
	Color     string     `json:"color,omitempty"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
	DeletedAt *time.Time `json:"deleted_at,omitempty"`
}

// NoteTag represents a many-to-many relationship between notes and tags
type NoteTag struct {
	NoteID uuid.UUID `json:"note_id"`
	TagID  uuid.UUID `json:"tag_id"`
}

// Image represents an uploaded image attachment
type Image struct {
	ID         uuid.UUID `json:"id"`
	NoteID     uuid.UUID `json:"note_id"`
	Filename   string    `json:"filename"`
	MimeType   string    `json:"mime_type"`
	StorageKey string    `json:"-"`
	Size       int64     `json:"size"`
	CreatedAt  time.Time `json:"created_at"`
}

// CreateUserRequest represents a registration request
type CreateUserRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// LoginRequest represents a login request
type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// AuthResponse represents authentication response with tokens
type AuthResponse struct {
	User         *User  `json:"user"`
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
}

// CreateNotebookRequest represents a request to create a notebook
type CreateNotebookRequest struct {
	Title string `json:"title"`
}

// UpdateNotebookRequest represents a request to update a notebook
type UpdateNotebookRequest struct {
	Title string `json:"title"`
}

// CreateNoteRequest represents a request to create a note
type CreateNoteRequest struct {
	Content    json.RawMessage `json:"content"`
	PlainText  string          `json:"plain_text,omitempty"`
	IsTodo     bool            `json:"is_todo"`
	ReminderAt *time.Time      `json:"reminder_at,omitempty"`
	TagIDs     []uuid.UUID     `json:"tag_ids,omitempty"`
}

// UpdateNoteRequest represents a request to update a note
type UpdateNoteRequest struct {
	Content    json.RawMessage `json:"content,omitempty"`
	PlainText  string          `json:"plain_text,omitempty"`
	IsTodo     *bool           `json:"is_todo,omitempty"`
	IsDone     *bool           `json:"is_done,omitempty"`
	ReminderAt *time.Time      `json:"reminder_at,omitempty"`
	TagIDs     []uuid.UUID     `json:"tag_ids,omitempty"`
}

// SyncRequest represents a request to sync changes
type SyncRequest struct {
	Notes     []Note     `json:"notes,omitempty"`
	Notebooks []Notebook `json:"notebooks,omitempty"`
	Tags      []Tag      `json:"tags,omitempty"`
}

// SyncResponse represents the response with changes since a timestamp
type SyncResponse struct {
	Notes       []Note     `json:"notes"`
	Notebooks   []Notebook `json:"notebooks"`
	Tags        []Tag      `json:"tags"`
	ServerTime  time.Time  `json:"server_time"`
	HasConflict bool       `json:"has_conflict"`
}
