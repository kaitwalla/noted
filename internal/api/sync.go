package api

import (
	"log"
	"net/http"
	"time"

	"github.com/noted/server/internal/models"
)

func (s *Server) handleSyncGet(w http.ResponseWriter, r *http.Request) {
	userID, ok := GetUserID(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized", "user not found in context")
		return
	}

	// Parse since parameter
	sinceStr := r.URL.Query().Get("since")
	var since time.Time
	if sinceStr != "" {
		var err error
		since, err = time.Parse(time.RFC3339, sinceStr)
		if err != nil {
			respondError(w, http.StatusBadRequest, "invalid_request", "invalid 'since' timestamp format")
			return
		}
	}

	// Get all changes since the timestamp
	notebooks, err := s.store.GetNotebooksSince(r.Context(), userID, since)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "server_error", "failed to get notebooks")
		return
	}

	notes, err := s.store.GetNotesSince(r.Context(), userID, since)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "server_error", "failed to get notes")
		return
	}

	tags, err := s.store.GetTagsSince(r.Context(), userID, since)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "server_error", "failed to get tags")
		return
	}

	// Load tags for each note
	for i := range notes {
		noteTags, err := s.store.GetTagsForNote(r.Context(), notes[i].ID)
		if err != nil {
			log.Printf("sync: failed to get tags for note %s: %v", notes[i].ID, err)
		} else {
			notes[i].Tags = noteTags
		}
	}

	if notebooks == nil {
		notebooks = []models.Notebook{}
	}
	if notes == nil {
		notes = []models.Note{}
	}
	if tags == nil {
		tags = []models.Tag{}
	}

	respondJSON(w, http.StatusOK, models.SyncResponse{
		Notes:      notes,
		Notebooks:  notebooks,
		Tags:       tags,
		ServerTime: time.Now(),
	})
}

func (s *Server) handleSyncPost(w http.ResponseWriter, r *http.Request) {
	userID, ok := GetUserID(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized", "user not found in context")
		return
	}

	var req models.SyncRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "invalid JSON body")
		return
	}

	hasConflict := false

	// Process notebooks
	for _, nb := range req.Notebooks {
		if nb.UserID != userID {
			continue
		}

		existing, err := s.store.GetNotebookByID(r.Context(), nb.ID)
		if err != nil {
			// New notebook, create it
			nb.UserID = userID
			if err := s.store.CreateNotebook(r.Context(), &nb); err != nil {
				log.Printf("sync: failed to create notebook %s: %v", nb.ID, err)
			}
		} else {
			// Check version/timestamps for conflicts
			if existing.UpdatedAt.After(nb.UpdatedAt) {
				hasConflict = true
			} else if nb.DeletedAt != nil {
				if err := s.store.DeleteNotebook(r.Context(), nb.ID); err != nil {
					log.Printf("sync: failed to delete notebook %s: %v", nb.ID, err)
				}
			} else {
				if err := s.store.UpdateNotebook(r.Context(), &nb); err != nil {
					log.Printf("sync: failed to update notebook %s: %v", nb.ID, err)
				}
			}
		}
	}

	// Process notes
	for _, note := range req.Notes {
		if note.UserID != userID {
			continue
		}

		existing, err := s.store.GetNoteByID(r.Context(), note.ID)
		if err != nil {
			// New note, create it
			note.UserID = userID
			if err := s.store.CreateNote(r.Context(), &note); err != nil {
				log.Printf("sync: failed to create note %s: %v", note.ID, err)
			}
		} else {
			// Check version for conflicts (last-write-wins)
			if existing.Version > note.Version {
				hasConflict = true
			} else if note.DeletedAt != nil {
				if err := s.store.DeleteNote(r.Context(), note.ID); err != nil {
					log.Printf("sync: failed to delete note %s: %v", note.ID, err)
				}
			} else {
				note.Version = existing.Version + 1
				if err := s.store.UpdateNote(r.Context(), &note); err != nil {
					log.Printf("sync: failed to update note %s: %v", note.ID, err)
				}
			}
		}
	}

	// Process tags
	for _, tag := range req.Tags {
		if tag.UserID != userID {
			continue
		}

		existing, err := s.store.GetTagByID(r.Context(), tag.ID)
		if err != nil {
			// New tag, create it
			tag.UserID = userID
			if err := s.store.CreateTag(r.Context(), &tag); err != nil {
				log.Printf("sync: failed to create tag %s: %v", tag.ID, err)
			}
		} else {
			if existing.UpdatedAt.After(tag.UpdatedAt) {
				hasConflict = true
			} else if tag.DeletedAt != nil {
				if err := s.store.DeleteTag(r.Context(), tag.ID); err != nil {
					log.Printf("sync: failed to delete tag %s: %v", tag.ID, err)
				}
			} else {
				if err := s.store.UpdateTag(r.Context(), &tag); err != nil {
					log.Printf("sync: failed to update tag %s: %v", tag.ID, err)
				}
			}
		}
	}

	// Return current state
	notebooks, err := s.store.GetNotebooksByUserID(r.Context(), userID)
	if err != nil {
		log.Printf("sync: failed to get notebooks for response: %v", err)
	}
	notes, err := s.store.GetNotesByUserID(r.Context(), userID, nil)
	if err != nil {
		log.Printf("sync: failed to get notes for response: %v", err)
	}
	tags, err := s.store.GetTagsByUserID(r.Context(), userID)
	if err != nil {
		log.Printf("sync: failed to get tags for response: %v", err)
	}

	if notebooks == nil {
		notebooks = []models.Notebook{}
	}
	if notes == nil {
		notes = []models.Note{}
	}
	if tags == nil {
		tags = []models.Tag{}
	}

	respondJSON(w, http.StatusOK, models.SyncResponse{
		Notes:       notes,
		Notebooks:   notebooks,
		Tags:        tags,
		ServerTime:  time.Now(),
		HasConflict: hasConflict,
	})
}
