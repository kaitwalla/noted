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

func (s *Server) handleListNotebooks(w http.ResponseWriter, r *http.Request) {
	userID, ok := GetUserID(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized", "user not found in context")
		return
	}

	notebooks, err := s.store.GetNotebooksByUserID(r.Context(), userID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "server_error", "failed to get notebooks")
		return
	}

	if notebooks == nil {
		notebooks = []models.Notebook{}
	}

	respondJSON(w, http.StatusOK, notebooks)
}

func (s *Server) handleCreateNotebook(w http.ResponseWriter, r *http.Request) {
	userID, ok := GetUserID(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized", "user not found in context")
		return
	}

	var req models.CreateNotebookRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "invalid JSON body")
		return
	}

	if req.Title == "" {
		respondError(w, http.StatusBadRequest, "validation_error", "title is required")
		return
	}

	// Get the next sort order for the user's notebooks
	sortOrder, err := s.store.GetNextNotebookSortOrder(r.Context(), userID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "server_error", "failed to get sort order")
		return
	}

	now := time.Now()
	notebook := &models.Notebook{
		ID:        uuid.New(),
		UserID:    userID,
		Title:     req.Title,
		SortOrder: sortOrder,
		CreatedAt: now,
		UpdatedAt: now,
	}

	if err := s.store.CreateNotebook(r.Context(), notebook); err != nil {
		respondError(w, http.StatusInternalServerError, "server_error", "failed to create notebook")
		return
	}

	respondJSON(w, http.StatusCreated, notebook)
}

func (s *Server) handleGetNotebook(w http.ResponseWriter, r *http.Request) {
	userID, ok := GetUserID(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized", "user not found in context")
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "invalid notebook ID")
		return
	}

	notebook, err := s.store.GetNotebookByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			respondError(w, http.StatusNotFound, "not_found", "notebook not found")
			return
		}
		respondError(w, http.StatusInternalServerError, "server_error", "failed to get notebook")
		return
	}

	// Check ownership and soft-delete (return 404 for both to prevent enumeration)
	if notebook.UserID != userID || notebook.DeletedAt != nil {
		respondError(w, http.StatusNotFound, "not_found", "notebook not found")
		return
	}

	respondJSON(w, http.StatusOK, notebook)
}

func (s *Server) handleUpdateNotebook(w http.ResponseWriter, r *http.Request) {
	userID, ok := GetUserID(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized", "user not found in context")
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "invalid notebook ID")
		return
	}

	var req models.UpdateNotebookRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "invalid JSON body")
		return
	}

	if req.Title == "" {
		respondError(w, http.StatusBadRequest, "validation_error", "title is required")
		return
	}

	// Get existing notebook to verify ownership
	notebook, err := s.store.GetNotebookByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			respondError(w, http.StatusNotFound, "not_found", "notebook not found")
			return
		}
		respondError(w, http.StatusInternalServerError, "server_error", "failed to get notebook")
		return
	}

	// Check ownership and soft-delete (return 404 for both to prevent enumeration)
	if notebook.UserID != userID || notebook.DeletedAt != nil {
		respondError(w, http.StatusNotFound, "not_found", "notebook not found")
		return
	}

	notebook.Title = req.Title
	if req.SortOrder != nil {
		notebook.SortOrder = *req.SortOrder
	}
	notebook.UpdatedAt = time.Now()

	if err := s.store.UpdateNotebook(r.Context(), notebook); err != nil {
		respondError(w, http.StatusInternalServerError, "server_error", "failed to update notebook")
		return
	}

	respondJSON(w, http.StatusOK, notebook)
}

func (s *Server) handleDeleteNotebook(w http.ResponseWriter, r *http.Request) {
	userID, ok := GetUserID(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized", "user not found in context")
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "invalid notebook ID")
		return
	}

	// Get existing notebook to verify ownership
	notebook, err := s.store.GetNotebookByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			respondError(w, http.StatusNotFound, "not_found", "notebook not found")
			return
		}
		respondError(w, http.StatusInternalServerError, "server_error", "failed to get notebook")
		return
	}

	// Check ownership and soft-delete (return 404 for both to prevent enumeration)
	if notebook.UserID != userID || notebook.DeletedAt != nil {
		respondError(w, http.StatusNotFound, "not_found", "notebook not found")
		return
	}

	if err := s.store.DeleteNotebook(r.Context(), id); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			respondError(w, http.StatusNotFound, "not_found", "notebook not found")
			return
		}
		respondError(w, http.StatusInternalServerError, "server_error", "failed to delete notebook")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
