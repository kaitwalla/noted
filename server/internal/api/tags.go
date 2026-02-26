package api

import (
	"errors"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/noted/server/internal/models"
	"github.com/noted/server/internal/store"
)

func (s *Server) handleListTags(w http.ResponseWriter, r *http.Request) {
	userID, ok := GetUserID(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized", "user not found in context")
		return
	}

	tags, err := s.store.GetTagsByUserID(r.Context(), userID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "server_error", "failed to get tags")
		return
	}

	if tags == nil {
		tags = []models.Tag{}
	}

	respondJSON(w, http.StatusOK, tags)
}

func (s *Server) handleCreateTag(w http.ResponseWriter, r *http.Request) {
	userID, ok := GetUserID(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized", "user not found in context")
		return
	}

	var req struct {
		Name  string `json:"name"`
		Color string `json:"color,omitempty"`
	}
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "invalid JSON body")
		return
	}

	if req.Name == "" {
		respondError(w, http.StatusBadRequest, "validation_error", "name is required")
		return
	}

	now := time.Now()
	tag := &models.Tag{
		ID:        uuid.New(),
		UserID:    userID,
		Name:      req.Name,
		Color:     req.Color,
		CreatedAt: now,
		UpdatedAt: now,
	}

	if err := s.store.CreateTag(r.Context(), tag); err != nil {
		respondError(w, http.StatusInternalServerError, "server_error", "failed to create tag")
		return
	}

	respondJSON(w, http.StatusCreated, tag)
}

func (s *Server) handleGetTag(w http.ResponseWriter, r *http.Request) {
	userID, ok := GetUserID(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized", "user not found in context")
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "invalid tag ID")
		return
	}

	tag, err := s.store.GetTagByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			respondError(w, http.StatusNotFound, "not_found", "tag not found")
			return
		}
		respondError(w, http.StatusInternalServerError, "server_error", "failed to get tag")
		return
	}

	// Check ownership and soft-delete (return 404 for both to prevent enumeration)
	if tag.UserID != userID || tag.DeletedAt != nil {
		respondError(w, http.StatusNotFound, "not_found", "tag not found")
		return
	}

	respondJSON(w, http.StatusOK, tag)
}

func (s *Server) handleUpdateTag(w http.ResponseWriter, r *http.Request) {
	userID, ok := GetUserID(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized", "user not found in context")
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "invalid tag ID")
		return
	}

	tag, err := s.store.GetTagByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			respondError(w, http.StatusNotFound, "not_found", "tag not found")
			return
		}
		respondError(w, http.StatusInternalServerError, "server_error", "failed to get tag")
		return
	}

	// Check ownership and soft-delete (return 404 for both to prevent enumeration)
	if tag.UserID != userID || tag.DeletedAt != nil {
		respondError(w, http.StatusNotFound, "not_found", "tag not found")
		return
	}

	var req struct {
		Name  string `json:"name"`
		Color string `json:"color,omitempty"`
	}
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "invalid JSON body")
		return
	}

	if req.Name != "" {
		tag.Name = req.Name
	}
	if req.Color != "" {
		tag.Color = req.Color
	}
	tag.UpdatedAt = time.Now()

	if err := s.store.UpdateTag(r.Context(), tag); err != nil {
		respondError(w, http.StatusInternalServerError, "server_error", "failed to update tag")
		return
	}

	respondJSON(w, http.StatusOK, tag)
}

func (s *Server) handleDeleteTag(w http.ResponseWriter, r *http.Request) {
	userID, ok := GetUserID(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized", "user not found in context")
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "invalid tag ID")
		return
	}

	tag, err := s.store.GetTagByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			respondError(w, http.StatusNotFound, "not_found", "tag not found")
			return
		}
		respondError(w, http.StatusInternalServerError, "server_error", "failed to get tag")
		return
	}

	// Check ownership and soft-delete (return 404 for both to prevent enumeration)
	if tag.UserID != userID || tag.DeletedAt != nil {
		respondError(w, http.StatusNotFound, "not_found", "tag not found")
		return
	}

	if err := s.store.DeleteTag(r.Context(), id); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			respondError(w, http.StatusNotFound, "not_found", "tag not found")
			return
		}
		respondError(w, http.StatusInternalServerError, "server_error", "failed to delete tag")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
