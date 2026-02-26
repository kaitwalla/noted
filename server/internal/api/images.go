package api

import (
	"errors"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/noted/server/internal/models"
	"github.com/noted/server/internal/store"
)

const maxUploadSize = 10 << 20 // 10MB

func (s *Server) handleUploadImage(w http.ResponseWriter, r *http.Request) {
	userID, ok := GetUserID(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized", "user not found in context")
		return
	}

	// Limit request body size
	r.Body = http.MaxBytesReader(w, r.Body, maxUploadSize)

	if err := r.ParseMultipartForm(maxUploadSize); err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "file too large or invalid form")
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "file is required")
		return
	}
	defer file.Close()

	noteIDStr := r.FormValue("note_id")
	if noteIDStr == "" {
		respondError(w, http.StatusBadRequest, "validation_error", "note_id is required")
		return
	}

	noteID, err := uuid.Parse(noteIDStr)
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "invalid note ID")
		return
	}

	// Verify note ownership
	note, err := s.store.GetNoteByID(r.Context(), noteID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			respondError(w, http.StatusNotFound, "not_found", "note not found")
			return
		}
		respondError(w, http.StatusInternalServerError, "server_error", "failed to get note")
		return
	}

	if note.UserID != userID {
		respondError(w, http.StatusForbidden, "forbidden", "you don't have access to this note")
		return
	}

	// Validate content type
	contentType := header.Header.Get("Content-Type")
	if !isAllowedImageType(contentType) {
		respondError(w, http.StatusBadRequest, "validation_error", "invalid file type. allowed: jpeg, png, gif, webp")
		return
	}

	// Create storage directory if it doesn't exist
	if err := os.MkdirAll(s.config.ImageStoragePath, 0755); err != nil {
		respondError(w, http.StatusInternalServerError, "server_error", "failed to create storage directory")
		return
	}

	// Generate storage key
	imageID := uuid.New()
	ext := filepath.Ext(header.Filename)
	if ext == "" {
		ext = getExtensionForMimeType(contentType)
	}
	storageKey := imageID.String() + ext
	filePath := filepath.Join(s.config.ImageStoragePath, storageKey)

	// Save file
	dst, err := os.Create(filePath)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "server_error", "failed to save file")
		return
	}
	defer dst.Close()

	size, err := io.Copy(dst, file)
	if err != nil {
		os.Remove(filePath)
		respondError(w, http.StatusInternalServerError, "server_error", "failed to save file")
		return
	}

	// Create database record
	image := &models.Image{
		ID:         imageID,
		NoteID:     noteID,
		Filename:   header.Filename,
		MimeType:   contentType,
		StorageKey: storageKey,
		Size:       size,
		CreatedAt:  time.Now(),
	}

	if err := s.store.CreateImage(r.Context(), image); err != nil {
		os.Remove(filePath)
		respondError(w, http.StatusInternalServerError, "server_error", "failed to create image record")
		return
	}

	respondJSON(w, http.StatusCreated, image)
}

func (s *Server) handleGetImage(w http.ResponseWriter, r *http.Request) {
	userID, ok := GetUserID(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized", "user not found in context")
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "invalid image ID")
		return
	}

	image, err := s.store.GetImageByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			respondError(w, http.StatusNotFound, "not_found", "image not found")
			return
		}
		respondError(w, http.StatusInternalServerError, "server_error", "failed to get image")
		return
	}

	// Verify note ownership
	note, err := s.store.GetNoteByID(r.Context(), image.NoteID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "server_error", "failed to get note")
		return
	}

	if note.UserID != userID {
		respondError(w, http.StatusForbidden, "forbidden", "you don't have access to this image")
		return
	}

	filePath := filepath.Join(s.config.ImageStoragePath, image.StorageKey)
	file, err := os.Open(filePath)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "server_error", "failed to read image file")
		return
	}
	defer file.Close()

	w.Header().Set("Content-Type", image.MimeType)
	w.Header().Set("Content-Disposition", "inline; filename=\""+image.Filename+"\"")
	io.Copy(w, file)
}

func isAllowedImageType(contentType string) bool {
	allowed := map[string]bool{
		"image/jpeg": true,
		"image/png":  true,
		"image/gif":  true,
		"image/webp": true,
	}
	return allowed[contentType]
}

func getExtensionForMimeType(mimeType string) string {
	switch mimeType {
	case "image/jpeg":
		return ".jpg"
	case "image/png":
		return ".png"
	case "image/gif":
		return ".gif"
	case "image/webp":
		return ".webp"
	default:
		return ""
	}
}
