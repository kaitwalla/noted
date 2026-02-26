package store

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/noted/server/internal/models"
)

// Store defines the interface for data persistence
type Store interface {
	UserStore
	NotebookStore
	NoteStore
	TagStore
	ImageStore
	Close() error
}

// UserStore handles user data operations
type UserStore interface {
	CreateUser(ctx context.Context, user *models.User) error
	GetUserByID(ctx context.Context, id uuid.UUID) (*models.User, error)
	GetUserByEmail(ctx context.Context, email string) (*models.User, error)
	UpdateUser(ctx context.Context, user *models.User) error
}

// NotebookStore handles notebook data operations
type NotebookStore interface {
	CreateNotebook(ctx context.Context, notebook *models.Notebook) error
	GetNotebookByID(ctx context.Context, id uuid.UUID) (*models.Notebook, error)
	GetNotebooksByUserID(ctx context.Context, userID uuid.UUID) ([]models.Notebook, error)
	UpdateNotebook(ctx context.Context, notebook *models.Notebook) error
	DeleteNotebook(ctx context.Context, id uuid.UUID) error
	GetNotebooksSince(ctx context.Context, userID uuid.UUID, since time.Time) ([]models.Notebook, error)
}

// NoteStore handles note data operations
type NoteStore interface {
	CreateNote(ctx context.Context, note *models.Note) error
	GetNoteByID(ctx context.Context, id uuid.UUID) (*models.Note, error)
	GetNotesByNotebookID(ctx context.Context, notebookID uuid.UUID, since *time.Time) ([]models.Note, error)
	GetNotesByUserID(ctx context.Context, userID uuid.UUID, since *time.Time) ([]models.Note, error)
	UpdateNote(ctx context.Context, note *models.Note) error
	DeleteNote(ctx context.Context, id uuid.UUID) error
	SearchNotes(ctx context.Context, userID uuid.UUID, query string) ([]models.Note, error)
	GetNotesSince(ctx context.Context, userID uuid.UUID, since time.Time) ([]models.Note, error)
}

// TagStore handles tag data operations
type TagStore interface {
	CreateTag(ctx context.Context, tag *models.Tag) error
	GetTagByID(ctx context.Context, id uuid.UUID) (*models.Tag, error)
	GetTagsByUserID(ctx context.Context, userID uuid.UUID) ([]models.Tag, error)
	UpdateTag(ctx context.Context, tag *models.Tag) error
	DeleteTag(ctx context.Context, id uuid.UUID) error
	AddTagToNote(ctx context.Context, noteID, tagID uuid.UUID) error
	RemoveTagFromNote(ctx context.Context, noteID, tagID uuid.UUID) error
	GetTagsForNote(ctx context.Context, noteID uuid.UUID) ([]models.Tag, error)
	SetNoteTags(ctx context.Context, noteID uuid.UUID, tagIDs []uuid.UUID) error
	GetTagsSince(ctx context.Context, userID uuid.UUID, since time.Time) ([]models.Tag, error)
}

// ImageStore handles image data operations
type ImageStore interface {
	CreateImage(ctx context.Context, image *models.Image) error
	GetImageByID(ctx context.Context, id uuid.UUID) (*models.Image, error)
	GetImagesByNoteID(ctx context.Context, noteID uuid.UUID) ([]models.Image, error)
	DeleteImage(ctx context.Context, id uuid.UUID) error
}
