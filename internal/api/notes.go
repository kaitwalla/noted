package api

import (
	"errors"
	"log"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/noted/server/internal/models"
	"github.com/noted/server/internal/store"
)

func (s *Server) handleListNotes(w http.ResponseWriter, r *http.Request) {
	userID, ok := GetUserID(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized", "user not found in context")
		return
	}

	notebookID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "invalid notebook ID")
		return
	}

	// Verify notebook ownership
	notebook, err := s.store.GetNotebookByID(r.Context(), notebookID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			respondError(w, http.StatusNotFound, "not_found", "notebook not found")
			return
		}
		respondError(w, http.StatusInternalServerError, "server_error", "failed to get notebook")
		return
	}

	if notebook.UserID != userID {
		respondError(w, http.StatusForbidden, "forbidden", "you don't have access to this notebook")
		return
	}

	if notebook.DeletedAt != nil {
		respondError(w, http.StatusNotFound, "not_found", "notebook not found")
		return
	}

	// Parse optional since parameter for sync
	var since *time.Time
	if sinceStr := r.URL.Query().Get("since"); sinceStr != "" {
		t, err := time.Parse(time.RFC3339, sinceStr)
		if err == nil {
			since = &t
		}
	}

	notes, err := s.store.GetNotesByNotebookID(r.Context(), notebookID, since)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "server_error", "failed to get notes")
		return
	}

	// Load tags for each note
	for i := range notes {
		tags, err := s.store.GetTagsForNote(r.Context(), notes[i].ID)
		if err == nil {
			notes[i].Tags = tags
		}
	}

	if notes == nil {
		notes = []models.Note{}
	}

	respondJSON(w, http.StatusOK, notes)
}

func (s *Server) handleCreateNote(w http.ResponseWriter, r *http.Request) {
	userID, ok := GetUserID(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized", "user not found in context")
		return
	}

	notebookID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "invalid notebook ID")
		return
	}

	// Verify notebook ownership
	notebook, err := s.store.GetNotebookByID(r.Context(), notebookID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			respondError(w, http.StatusNotFound, "not_found", "notebook not found")
			return
		}
		respondError(w, http.StatusInternalServerError, "server_error", "failed to get notebook")
		return
	}

	if notebook.UserID != userID {
		respondError(w, http.StatusForbidden, "forbidden", "you don't have access to this notebook")
		return
	}

	if notebook.DeletedAt != nil {
		respondError(w, http.StatusNotFound, "not_found", "notebook not found")
		return
	}

	var req models.CreateNoteRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "invalid JSON body")
		return
	}

	if req.Content == nil {
		respondError(w, http.StatusBadRequest, "validation_error", "content is required")
		return
	}

	now := time.Now()
	note := &models.Note{
		ID:         uuid.New(),
		NotebookID: notebookID,
		UserID:     userID,
		Content:    req.Content,
		PlainText:  req.PlainText,
		IsTodo:     req.IsTodo,
		IsDone:     false,
		ReminderAt: req.ReminderAt,
		Version:    1,
		CreatedAt:  now,
		UpdatedAt:  now,
	}

	if err := s.store.CreateNote(r.Context(), note); err != nil {
		respondError(w, http.StatusInternalServerError, "server_error", "failed to create note")
		return
	}

	// Set tags if provided
	if len(req.TagIDs) > 0 {
		if err := s.store.SetNoteTags(r.Context(), note.ID, req.TagIDs); err != nil {
			log.Printf("failed to set tags for note %s: %v", note.ID, err)
		}
		tags, err := s.store.GetTagsForNote(r.Context(), note.ID)
		if err != nil {
			log.Printf("failed to get tags for note %s: %v", note.ID, err)
		} else {
			note.Tags = tags
		}
	}

	respondJSON(w, http.StatusCreated, note)
}

func (s *Server) handleGetNote(w http.ResponseWriter, r *http.Request) {
	userID, ok := GetUserID(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized", "user not found in context")
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "invalid note ID")
		return
	}

	note, err := s.store.GetNoteByID(r.Context(), id)
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

	if note.DeletedAt != nil {
		respondError(w, http.StatusNotFound, "not_found", "note not found")
		return
	}

	// Load tags
	tags, err := s.store.GetTagsForNote(r.Context(), note.ID)
	if err == nil {
		note.Tags = tags
	}

	respondJSON(w, http.StatusOK, note)
}

func (s *Server) handleUpdateNote(w http.ResponseWriter, r *http.Request) {
	userID, ok := GetUserID(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized", "user not found in context")
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "invalid note ID")
		return
	}

	note, err := s.store.GetNoteByID(r.Context(), id)
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

	if note.DeletedAt != nil {
		respondError(w, http.StatusNotFound, "not_found", "note not found")
		return
	}

	var req models.UpdateNoteRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "invalid JSON body")
		return
	}

	// Apply updates
	if req.Content != nil {
		note.Content = req.Content
	}
	if req.PlainText != "" {
		note.PlainText = req.PlainText
	}
	if req.IsTodo != nil {
		note.IsTodo = *req.IsTodo
	}
	if req.IsDone != nil {
		note.IsDone = *req.IsDone
	}
	if req.ReminderAt != nil {
		note.ReminderAt = req.ReminderAt
	}

	note.Version++
	note.UpdatedAt = time.Now()

	if err := s.store.UpdateNote(r.Context(), note); err != nil {
		respondError(w, http.StatusInternalServerError, "server_error", "failed to update note")
		return
	}

	// Update tags if provided
	if req.TagIDs != nil {
		if err := s.store.SetNoteTags(r.Context(), note.ID, req.TagIDs); err != nil {
			log.Printf("failed to set tags for note %s: %v", note.ID, err)
		}
	}

	// Load tags
	tags, err := s.store.GetTagsForNote(r.Context(), note.ID)
	if err != nil {
		log.Printf("failed to get tags for note %s: %v", note.ID, err)
	} else {
		note.Tags = tags
	}

	respondJSON(w, http.StatusOK, note)
}

func (s *Server) handleDeleteNote(w http.ResponseWriter, r *http.Request) {
	userID, ok := GetUserID(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized", "user not found in context")
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "invalid note ID")
		return
	}

	note, err := s.store.GetNoteByID(r.Context(), id)
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

	if err := s.store.DeleteNote(r.Context(), id); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			respondError(w, http.StatusNotFound, "not_found", "note not found")
			return
		}
		respondError(w, http.StatusInternalServerError, "server_error", "failed to delete note")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
