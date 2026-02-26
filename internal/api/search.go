package api

import (
	"log"
	"net/http"
)

func (s *Server) handleSearch(w http.ResponseWriter, r *http.Request) {
	userID, ok := GetUserID(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized", "user not found in context")
		return
	}

	query := r.URL.Query().Get("q")
	if query == "" {
		respondError(w, http.StatusBadRequest, "validation_error", "query parameter 'q' is required")
		return
	}

	notes, err := s.store.SearchNotes(r.Context(), userID, query)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "server_error", "failed to search notes")
		return
	}

	// Load tags for each note
	for i := range notes {
		tags, err := s.store.GetTagsForNote(r.Context(), notes[i].ID)
		if err != nil {
			log.Printf("failed to get tags for note %s: %v", notes[i].ID, err)
			continue
		}
		notes[i].Tags = tags
	}

	respondJSON(w, http.StatusOK, notes)
}
