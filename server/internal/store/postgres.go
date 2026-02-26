package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/noted/server/internal/models"
)

var (
	ErrNotFound      = errors.New("not found")
	ErrAlreadyExists = errors.New("already exists")
)

// PostgresStore implements Store using PostgreSQL
type PostgresStore struct {
	pool *pgxpool.Pool
}

// NewPostgresStore creates a new PostgreSQL store
func NewPostgresStore(ctx context.Context, databaseURL string) (*PostgresStore, error) {
	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		return nil, fmt.Errorf("failed to create pool: %w", err)
	}

	if err := pool.Ping(ctx); err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	return &PostgresStore{pool: pool}, nil
}

// Close closes the database connection pool
func (s *PostgresStore) Close() error {
	s.pool.Close()
	return nil
}

// Pool returns the underlying connection pool for migrations
func (s *PostgresStore) Pool() *pgxpool.Pool {
	return s.pool
}

// --- User Operations ---

func (s *PostgresStore) CreateUser(ctx context.Context, user *models.User) error {
	query := `
		INSERT INTO users (id, email, password_hash, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5)
	`
	_, err := s.pool.Exec(ctx, query,
		user.ID, user.Email, user.PasswordHash, user.CreatedAt, user.UpdatedAt)
	if err != nil {
		if isDuplicateKeyError(err) {
			return ErrAlreadyExists
		}
		return fmt.Errorf("failed to create user: %w", err)
	}
	return nil
}

func (s *PostgresStore) GetUserByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	query := `
		SELECT id, email, password_hash, created_at, updated_at
		FROM users
		WHERE id = $1 AND deleted_at IS NULL
	`
	var user models.User
	err := s.pool.QueryRow(ctx, query, id).Scan(
		&user.ID, &user.Email, &user.PasswordHash, &user.CreatedAt, &user.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("failed to get user: %w", err)
	}
	return &user, nil
}

func (s *PostgresStore) GetUserByEmail(ctx context.Context, email string) (*models.User, error) {
	query := `
		SELECT id, email, password_hash, created_at, updated_at
		FROM users
		WHERE email = $1 AND deleted_at IS NULL
	`
	var user models.User
	err := s.pool.QueryRow(ctx, query, email).Scan(
		&user.ID, &user.Email, &user.PasswordHash, &user.CreatedAt, &user.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("failed to get user by email: %w", err)
	}
	return &user, nil
}

func (s *PostgresStore) UpdateUser(ctx context.Context, user *models.User) error {
	query := `
		UPDATE users
		SET email = $2, password_hash = $3, updated_at = $4
		WHERE id = $1 AND deleted_at IS NULL
	`
	result, err := s.pool.Exec(ctx, query,
		user.ID, user.Email, user.PasswordHash, user.UpdatedAt)
	if err != nil {
		return fmt.Errorf("failed to update user: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// --- Notebook Operations ---

func (s *PostgresStore) CreateNotebook(ctx context.Context, notebook *models.Notebook) error {
	query := `
		INSERT INTO notebooks (id, user_id, title, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5)
	`
	_, err := s.pool.Exec(ctx, query,
		notebook.ID, notebook.UserID, notebook.Title, notebook.CreatedAt, notebook.UpdatedAt)
	if err != nil {
		return fmt.Errorf("failed to create notebook: %w", err)
	}
	return nil
}

func (s *PostgresStore) GetNotebookByID(ctx context.Context, id uuid.UUID) (*models.Notebook, error) {
	query := `
		SELECT id, user_id, title, created_at, updated_at, deleted_at
		FROM notebooks
		WHERE id = $1
	`
	var notebook models.Notebook
	err := s.pool.QueryRow(ctx, query, id).Scan(
		&notebook.ID, &notebook.UserID, &notebook.Title,
		&notebook.CreatedAt, &notebook.UpdatedAt, &notebook.DeletedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("failed to get notebook: %w", err)
	}
	return &notebook, nil
}

func (s *PostgresStore) GetNotebooksByUserID(ctx context.Context, userID uuid.UUID) ([]models.Notebook, error) {
	query := `
		SELECT id, user_id, title, created_at, updated_at, deleted_at
		FROM notebooks
		WHERE user_id = $1 AND deleted_at IS NULL
		ORDER BY created_at DESC
	`
	rows, err := s.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get notebooks: %w", err)
	}
	defer rows.Close()

	var notebooks []models.Notebook
	for rows.Next() {
		var nb models.Notebook
		if err := rows.Scan(&nb.ID, &nb.UserID, &nb.Title, &nb.CreatedAt, &nb.UpdatedAt, &nb.DeletedAt); err != nil {
			return nil, fmt.Errorf("failed to scan notebook: %w", err)
		}
		notebooks = append(notebooks, nb)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating notebooks: %w", err)
	}
	return notebooks, nil
}

func (s *PostgresStore) UpdateNotebook(ctx context.Context, notebook *models.Notebook) error {
	query := `
		UPDATE notebooks
		SET title = $2, updated_at = $3
		WHERE id = $1 AND deleted_at IS NULL
	`
	result, err := s.pool.Exec(ctx, query, notebook.ID, notebook.Title, notebook.UpdatedAt)
	if err != nil {
		return fmt.Errorf("failed to update notebook: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *PostgresStore) DeleteNotebook(ctx context.Context, id uuid.UUID) error {
	query := `UPDATE notebooks SET deleted_at = $2 WHERE id = $1 AND deleted_at IS NULL`
	result, err := s.pool.Exec(ctx, query, id, time.Now())
	if err != nil {
		return fmt.Errorf("failed to delete notebook: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *PostgresStore) GetNotebooksSince(ctx context.Context, userID uuid.UUID, since time.Time) ([]models.Notebook, error) {
	query := `
		SELECT id, user_id, title, created_at, updated_at, deleted_at
		FROM notebooks
		WHERE user_id = $1 AND updated_at > $2
		ORDER BY updated_at ASC
	`
	rows, err := s.pool.Query(ctx, query, userID, since)
	if err != nil {
		return nil, fmt.Errorf("failed to get notebooks since: %w", err)
	}
	defer rows.Close()

	var notebooks []models.Notebook
	for rows.Next() {
		var nb models.Notebook
		if err := rows.Scan(&nb.ID, &nb.UserID, &nb.Title, &nb.CreatedAt, &nb.UpdatedAt, &nb.DeletedAt); err != nil {
			return nil, fmt.Errorf("failed to scan notebook: %w", err)
		}
		notebooks = append(notebooks, nb)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating notebooks: %w", err)
	}
	return notebooks, nil
}

// --- Note Operations ---

func (s *PostgresStore) CreateNote(ctx context.Context, note *models.Note) error {
	query := `
		INSERT INTO notes (id, notebook_id, user_id, content, plain_text, is_todo, is_done, reminder_at, version, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
	`
	_, err := s.pool.Exec(ctx, query,
		note.ID, note.NotebookID, note.UserID, note.Content, note.PlainText,
		note.IsTodo, note.IsDone, note.ReminderAt, note.Version,
		note.CreatedAt, note.UpdatedAt)
	if err != nil {
		return fmt.Errorf("failed to create note: %w", err)
	}
	return nil
}

func (s *PostgresStore) GetNoteByID(ctx context.Context, id uuid.UUID) (*models.Note, error) {
	query := `
		SELECT id, notebook_id, user_id, content, plain_text, is_todo, is_done, reminder_at, version, created_at, updated_at, deleted_at
		FROM notes
		WHERE id = $1
	`
	var note models.Note
	var content []byte
	err := s.pool.QueryRow(ctx, query, id).Scan(
		&note.ID, &note.NotebookID, &note.UserID, &content, &note.PlainText,
		&note.IsTodo, &note.IsDone, &note.ReminderAt, &note.Version,
		&note.CreatedAt, &note.UpdatedAt, &note.DeletedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("failed to get note: %w", err)
	}
	note.Content = json.RawMessage(content)
	return &note, nil
}

func (s *PostgresStore) GetNotesByNotebookID(ctx context.Context, notebookID uuid.UUID, since *time.Time) ([]models.Note, error) {
	var query string
	var args []interface{}

	if since != nil {
		query = `
			SELECT id, notebook_id, user_id, content, plain_text, is_todo, is_done, reminder_at, version, created_at, updated_at, deleted_at
			FROM notes
			WHERE notebook_id = $1 AND updated_at > $2
			ORDER BY created_at ASC
		`
		args = []interface{}{notebookID, *since}
	} else {
		query = `
			SELECT id, notebook_id, user_id, content, plain_text, is_todo, is_done, reminder_at, version, created_at, updated_at, deleted_at
			FROM notes
			WHERE notebook_id = $1 AND deleted_at IS NULL
			ORDER BY created_at ASC
		`
		args = []interface{}{notebookID}
	}

	rows, err := s.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get notes: %w", err)
	}
	defer rows.Close()

	return scanNotes(rows)
}

func (s *PostgresStore) GetNotesByUserID(ctx context.Context, userID uuid.UUID, since *time.Time) ([]models.Note, error) {
	var query string
	var args []interface{}

	if since != nil {
		query = `
			SELECT id, notebook_id, user_id, content, plain_text, is_todo, is_done, reminder_at, version, created_at, updated_at, deleted_at
			FROM notes
			WHERE user_id = $1 AND updated_at > $2
			ORDER BY created_at ASC
		`
		args = []interface{}{userID, *since}
	} else {
		query = `
			SELECT id, notebook_id, user_id, content, plain_text, is_todo, is_done, reminder_at, version, created_at, updated_at, deleted_at
			FROM notes
			WHERE user_id = $1 AND deleted_at IS NULL
			ORDER BY created_at ASC
		`
		args = []interface{}{userID}
	}

	rows, err := s.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get notes: %w", err)
	}
	defer rows.Close()

	return scanNotes(rows)
}

func (s *PostgresStore) UpdateNote(ctx context.Context, note *models.Note) error {
	query := `
		UPDATE notes
		SET content = $2, plain_text = $3, is_todo = $4, is_done = $5, reminder_at = $6, version = $7, updated_at = $8
		WHERE id = $1 AND deleted_at IS NULL
	`
	result, err := s.pool.Exec(ctx, query,
		note.ID, note.Content, note.PlainText, note.IsTodo, note.IsDone,
		note.ReminderAt, note.Version, note.UpdatedAt)
	if err != nil {
		return fmt.Errorf("failed to update note: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *PostgresStore) DeleteNote(ctx context.Context, id uuid.UUID) error {
	query := `UPDATE notes SET deleted_at = $2, updated_at = $2 WHERE id = $1 AND deleted_at IS NULL`
	now := time.Now()
	result, err := s.pool.Exec(ctx, query, id, now)
	if err != nil {
		return fmt.Errorf("failed to delete note: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *PostgresStore) SearchNotes(ctx context.Context, userID uuid.UUID, query string) ([]models.Note, error) {
	sqlQuery := `
		SELECT id, notebook_id, user_id, content, plain_text, is_todo, is_done, reminder_at, version, created_at, updated_at, deleted_at
		FROM notes
		WHERE user_id = $1 AND deleted_at IS NULL
		  AND to_tsvector('english', plain_text) @@ plainto_tsquery('english', $2)
		ORDER BY ts_rank(to_tsvector('english', plain_text), plainto_tsquery('english', $2)) DESC
	`
	rows, err := s.pool.Query(ctx, sqlQuery, userID, query)
	if err != nil {
		return nil, fmt.Errorf("failed to search notes: %w", err)
	}
	defer rows.Close()

	return scanNotes(rows)
}

func (s *PostgresStore) GetNotesSince(ctx context.Context, userID uuid.UUID, since time.Time) ([]models.Note, error) {
	return s.GetNotesByUserID(ctx, userID, &since)
}

// --- Tag Operations ---

func (s *PostgresStore) CreateTag(ctx context.Context, tag *models.Tag) error {
	query := `
		INSERT INTO tags (id, user_id, name, color, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`
	_, err := s.pool.Exec(ctx, query,
		tag.ID, tag.UserID, tag.Name, tag.Color, tag.CreatedAt, tag.UpdatedAt)
	if err != nil {
		return fmt.Errorf("failed to create tag: %w", err)
	}
	return nil
}

func (s *PostgresStore) GetTagByID(ctx context.Context, id uuid.UUID) (*models.Tag, error) {
	query := `
		SELECT id, user_id, name, color, created_at, updated_at, deleted_at
		FROM tags
		WHERE id = $1
	`
	var tag models.Tag
	var color sql.NullString
	err := s.pool.QueryRow(ctx, query, id).Scan(
		&tag.ID, &tag.UserID, &tag.Name, &color, &tag.CreatedAt, &tag.UpdatedAt, &tag.DeletedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("failed to get tag: %w", err)
	}
	if color.Valid {
		tag.Color = color.String
	}
	return &tag, nil
}

func (s *PostgresStore) GetTagsByUserID(ctx context.Context, userID uuid.UUID) ([]models.Tag, error) {
	query := `
		SELECT id, user_id, name, color, created_at, updated_at, deleted_at
		FROM tags
		WHERE user_id = $1 AND deleted_at IS NULL
		ORDER BY name ASC
	`
	rows, err := s.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get tags: %w", err)
	}
	defer rows.Close()

	var tags []models.Tag
	for rows.Next() {
		var tag models.Tag
		var color sql.NullString
		if err := rows.Scan(&tag.ID, &tag.UserID, &tag.Name, &color, &tag.CreatedAt, &tag.UpdatedAt, &tag.DeletedAt); err != nil {
			return nil, fmt.Errorf("failed to scan tag: %w", err)
		}
		if color.Valid {
			tag.Color = color.String
		}
		tags = append(tags, tag)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating tags: %w", err)
	}
	return tags, nil
}

func (s *PostgresStore) UpdateTag(ctx context.Context, tag *models.Tag) error {
	query := `
		UPDATE tags
		SET name = $2, color = $3, updated_at = $4
		WHERE id = $1 AND deleted_at IS NULL
	`
	result, err := s.pool.Exec(ctx, query, tag.ID, tag.Name, tag.Color, tag.UpdatedAt)
	if err != nil {
		return fmt.Errorf("failed to update tag: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *PostgresStore) DeleteTag(ctx context.Context, id uuid.UUID) error {
	query := `UPDATE tags SET deleted_at = $2 WHERE id = $1 AND deleted_at IS NULL`
	result, err := s.pool.Exec(ctx, query, id, time.Now())
	if err != nil {
		return fmt.Errorf("failed to delete tag: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *PostgresStore) AddTagToNote(ctx context.Context, noteID, tagID uuid.UUID) error {
	query := `INSERT INTO note_tags (note_id, tag_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`
	_, err := s.pool.Exec(ctx, query, noteID, tagID)
	if err != nil {
		return fmt.Errorf("failed to add tag to note: %w", err)
	}
	return nil
}

func (s *PostgresStore) RemoveTagFromNote(ctx context.Context, noteID, tagID uuid.UUID) error {
	query := `DELETE FROM note_tags WHERE note_id = $1 AND tag_id = $2`
	_, err := s.pool.Exec(ctx, query, noteID, tagID)
	if err != nil {
		return fmt.Errorf("failed to remove tag from note: %w", err)
	}
	return nil
}

func (s *PostgresStore) GetTagsForNote(ctx context.Context, noteID uuid.UUID) ([]models.Tag, error) {
	query := `
		SELECT t.id, t.user_id, t.name, t.color, t.created_at, t.updated_at, t.deleted_at
		FROM tags t
		JOIN note_tags nt ON t.id = nt.tag_id
		WHERE nt.note_id = $1 AND t.deleted_at IS NULL
		ORDER BY t.name ASC
	`
	rows, err := s.pool.Query(ctx, query, noteID)
	if err != nil {
		return nil, fmt.Errorf("failed to get tags for note: %w", err)
	}
	defer rows.Close()

	var tags []models.Tag
	for rows.Next() {
		var tag models.Tag
		var color sql.NullString
		if err := rows.Scan(&tag.ID, &tag.UserID, &tag.Name, &color, &tag.CreatedAt, &tag.UpdatedAt, &tag.DeletedAt); err != nil {
			return nil, fmt.Errorf("failed to scan tag: %w", err)
		}
		if color.Valid {
			tag.Color = color.String
		}
		tags = append(tags, tag)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating tags: %w", err)
	}
	return tags, nil
}

func (s *PostgresStore) SetNoteTags(ctx context.Context, noteID uuid.UUID, tagIDs []uuid.UUID) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	// Remove all existing tags
	_, err = tx.Exec(ctx, `DELETE FROM note_tags WHERE note_id = $1`, noteID)
	if err != nil {
		return fmt.Errorf("failed to clear note tags: %w", err)
	}

	// Add new tags
	for _, tagID := range tagIDs {
		_, err = tx.Exec(ctx, `INSERT INTO note_tags (note_id, tag_id) VALUES ($1, $2)`, noteID, tagID)
		if err != nil {
			return fmt.Errorf("failed to add tag: %w", err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("failed to commit: %w", err)
	}
	return nil
}

func (s *PostgresStore) GetTagsSince(ctx context.Context, userID uuid.UUID, since time.Time) ([]models.Tag, error) {
	query := `
		SELECT id, user_id, name, color, created_at, updated_at, deleted_at
		FROM tags
		WHERE user_id = $1 AND updated_at > $2
		ORDER BY updated_at ASC
	`
	rows, err := s.pool.Query(ctx, query, userID, since)
	if err != nil {
		return nil, fmt.Errorf("failed to get tags since: %w", err)
	}
	defer rows.Close()

	var tags []models.Tag
	for rows.Next() {
		var tag models.Tag
		var color sql.NullString
		if err := rows.Scan(&tag.ID, &tag.UserID, &tag.Name, &color, &tag.CreatedAt, &tag.UpdatedAt, &tag.DeletedAt); err != nil {
			return nil, fmt.Errorf("failed to scan tag: %w", err)
		}
		if color.Valid {
			tag.Color = color.String
		}
		tags = append(tags, tag)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating tags: %w", err)
	}
	return tags, nil
}

// --- Image Operations ---

func (s *PostgresStore) CreateImage(ctx context.Context, image *models.Image) error {
	query := `
		INSERT INTO images (id, note_id, filename, mime_type, storage_key, size, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`
	_, err := s.pool.Exec(ctx, query,
		image.ID, image.NoteID, image.Filename, image.MimeType, image.StorageKey, image.Size, image.CreatedAt)
	if err != nil {
		return fmt.Errorf("failed to create image: %w", err)
	}
	return nil
}

func (s *PostgresStore) GetImageByID(ctx context.Context, id uuid.UUID) (*models.Image, error) {
	query := `
		SELECT id, note_id, filename, mime_type, storage_key, size, created_at
		FROM images
		WHERE id = $1
	`
	var image models.Image
	err := s.pool.QueryRow(ctx, query, id).Scan(
		&image.ID, &image.NoteID, &image.Filename, &image.MimeType, &image.StorageKey, &image.Size, &image.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("failed to get image: %w", err)
	}
	return &image, nil
}

func (s *PostgresStore) GetImagesByNoteID(ctx context.Context, noteID uuid.UUID) ([]models.Image, error) {
	query := `
		SELECT id, note_id, filename, mime_type, storage_key, size, created_at
		FROM images
		WHERE note_id = $1
		ORDER BY created_at ASC
	`
	rows, err := s.pool.Query(ctx, query, noteID)
	if err != nil {
		return nil, fmt.Errorf("failed to get images: %w", err)
	}
	defer rows.Close()

	var images []models.Image
	for rows.Next() {
		var img models.Image
		if err := rows.Scan(&img.ID, &img.NoteID, &img.Filename, &img.MimeType, &img.StorageKey, &img.Size, &img.CreatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan image: %w", err)
		}
		images = append(images, img)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating images: %w", err)
	}
	return images, nil
}

func (s *PostgresStore) DeleteImage(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM images WHERE id = $1`
	result, err := s.pool.Exec(ctx, query, id)
	if err != nil {
		return fmt.Errorf("failed to delete image: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// Helper functions

func scanNotes(rows pgx.Rows) ([]models.Note, error) {
	var notes []models.Note
	for rows.Next() {
		var note models.Note
		var content []byte
		if err := rows.Scan(
			&note.ID, &note.NotebookID, &note.UserID, &content, &note.PlainText,
			&note.IsTodo, &note.IsDone, &note.ReminderAt, &note.Version,
			&note.CreatedAt, &note.UpdatedAt, &note.DeletedAt); err != nil {
			return nil, fmt.Errorf("failed to scan note: %w", err)
		}
		note.Content = json.RawMessage(content)
		notes = append(notes, note)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating notes: %w", err)
	}
	return notes, nil
}

func isDuplicateKeyError(err error) bool {
	return err != nil && (contains(err.Error(), "duplicate key") || contains(err.Error(), "unique constraint"))
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > 0 && containsAt(s, substr, 0))
}

func containsAt(s, substr string, start int) bool {
	for i := start; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
