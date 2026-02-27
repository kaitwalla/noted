package api_test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/noted/server/internal/api"
	"github.com/noted/server/internal/config"
	"github.com/noted/server/internal/models"
	"github.com/noted/server/internal/testutil"
)

func setupTestServerWithNotebook(t *testing.T) (*api.Server, string, string) {
	t.Helper()
	db := testutil.TestDB(t)
	testutil.CleanTables(t, db)
	blobStore := testutil.TestBlobStore(t)

	cfg := &config.Config{
		JWTSecret:      "test-secret",
		JWTExpiration:  15 * time.Minute,
		RefreshExpiry:  7 * 24 * time.Hour,
	}
	srv := api.NewServer(db, cfg, blobStore)

	// Register and get token
	regBody, _ := json.Marshal(map[string]string{"email": "test@example.com", "password": "password123"})
	regReq := httptest.NewRequest(http.MethodPost, "/api/auth/register", bytes.NewReader(regBody))
	regReq.Header.Set("Content-Type", "application/json")
	regRec := httptest.NewRecorder()
	srv.ServeHTTP(regRec, regReq)

	var authResp models.AuthResponse
	json.NewDecoder(regRec.Body).Decode(&authResp)
	token := authResp.AccessToken

	// Create a notebook
	nbBody, _ := json.Marshal(map[string]string{"title": "Test Notebook"})
	nbReq := httptest.NewRequest(http.MethodPost, "/api/notebooks", bytes.NewReader(nbBody))
	nbReq.Header.Set("Content-Type", "application/json")
	nbReq.Header.Set("Authorization", "Bearer "+token)
	nbRec := httptest.NewRecorder()
	srv.ServeHTTP(nbRec, nbReq)

	var nb models.Notebook
	json.NewDecoder(nbRec.Body).Decode(&nb)

	return srv, token, nb.ID.String()
}

func TestNotesCRUD(t *testing.T) {
	srv, token, notebookID := setupTestServerWithNotebook(t)

	var noteID string

	// Create note
	t.Run("create note", func(t *testing.T) {
		content := map[string]interface{}{
			"type": "doc",
			"content": []map[string]interface{}{
				{"type": "paragraph", "content": []map[string]interface{}{
					{"type": "text", "text": "Hello World"},
				}},
			},
		}
		body, _ := json.Marshal(map[string]interface{}{
			"content":    content,
			"plain_text": "Hello World",
		})
		req := httptest.NewRequest(http.MethodPost, "/api/notebooks/"+notebookID+"/notes", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+token)
		rec := httptest.NewRecorder()

		srv.ServeHTTP(rec, req)

		if rec.Code != http.StatusCreated {
			t.Errorf("got status %d, want %d. Body: %s", rec.Code, http.StatusCreated, rec.Body.String())
		}

		var note models.Note
		json.NewDecoder(rec.Body).Decode(&note)
		noteID = note.ID.String()

		if note.PlainText != "Hello World" {
			t.Errorf("got plain_text %s, want Hello World", note.PlainText)
		}
		if note.Version != 1 {
			t.Errorf("got version %d, want 1", note.Version)
		}
	})

	// List notes
	t.Run("list notes", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/notebooks/"+notebookID+"/notes", nil)
		req.Header.Set("Authorization", "Bearer "+token)
		rec := httptest.NewRecorder()

		srv.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("got status %d, want %d", rec.Code, http.StatusOK)
		}

		var notes []models.Note
		json.NewDecoder(rec.Body).Decode(&notes)
		if len(notes) != 1 {
			t.Errorf("got %d notes, want 1", len(notes))
		}
	})

	// Get note
	t.Run("get note", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/notes/"+noteID, nil)
		req.Header.Set("Authorization", "Bearer "+token)
		rec := httptest.NewRecorder()

		srv.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("got status %d, want %d", rec.Code, http.StatusOK)
		}
	})

	// Update note
	t.Run("update note", func(t *testing.T) {
		body, _ := json.Marshal(map[string]interface{}{
			"plain_text": "Updated content",
		})
		req := httptest.NewRequest(http.MethodPut, "/api/notes/"+noteID, bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+token)
		rec := httptest.NewRecorder()

		srv.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("got status %d, want %d. Body: %s", rec.Code, http.StatusOK, rec.Body.String())
		}

		var note models.Note
		json.NewDecoder(rec.Body).Decode(&note)
		if note.PlainText != "Updated content" {
			t.Errorf("got plain_text %s, want Updated content", note.PlainText)
		}
		if note.Version != 2 {
			t.Errorf("got version %d, want 2", note.Version)
		}
	})

	// Delete note
	t.Run("delete note", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodDelete, "/api/notes/"+noteID, nil)
		req.Header.Set("Authorization", "Bearer "+token)
		rec := httptest.NewRecorder()

		srv.ServeHTTP(rec, req)

		if rec.Code != http.StatusNoContent {
			t.Errorf("got status %d, want %d", rec.Code, http.StatusNoContent)
		}

		// Verify it's gone
		req = httptest.NewRequest(http.MethodGet, "/api/notes/"+noteID, nil)
		req.Header.Set("Authorization", "Bearer "+token)
		rec = httptest.NewRecorder()
		srv.ServeHTTP(rec, req)

		if rec.Code != http.StatusNotFound {
			t.Errorf("got status %d, want %d after delete", rec.Code, http.StatusNotFound)
		}
	})
}

func TestNoteTodo(t *testing.T) {
	srv, token, notebookID := setupTestServerWithNotebook(t)

	// Create todo note
	body, _ := json.Marshal(map[string]interface{}{
		"content":    map[string]interface{}{"type": "doc"},
		"plain_text": "Buy groceries",
		"is_todo":    true,
	})
	req := httptest.NewRequest(http.MethodPost, "/api/notebooks/"+notebookID+"/notes", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)
	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, req)

	var note models.Note
	json.NewDecoder(rec.Body).Decode(&note)

	if !note.IsTodo {
		t.Error("expected note to be a todo")
	}
	if note.IsDone {
		t.Error("expected new todo to not be done")
	}

	// Mark as done
	isDone := true
	updateBody, _ := json.Marshal(map[string]interface{}{
		"is_done": &isDone,
	})
	req = httptest.NewRequest(http.MethodPut, "/api/notes/"+note.ID.String(), bytes.NewReader(updateBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)
	rec = httptest.NewRecorder()
	srv.ServeHTTP(rec, req)

	json.NewDecoder(rec.Body).Decode(&note)
	if !note.IsDone {
		t.Error("expected todo to be done after update")
	}
}

func TestNoteSearch(t *testing.T) {
	srv, token, notebookID := setupTestServerWithNotebook(t)

	// Create some notes
	notes := []string{"Meeting with team", "Grocery list", "Team standup notes"}
	for _, text := range notes {
		body, _ := json.Marshal(map[string]interface{}{
			"content":    map[string]interface{}{"type": "doc"},
			"plain_text": text,
		})
		req := httptest.NewRequest(http.MethodPost, "/api/notebooks/"+notebookID+"/notes", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+token)
		rec := httptest.NewRecorder()
		srv.ServeHTTP(rec, req)
	}

	// Search for "team"
	req := httptest.NewRequest(http.MethodGet, "/api/search?q=team", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("got status %d, want %d", rec.Code, http.StatusOK)
	}

	var results []models.Note
	json.NewDecoder(rec.Body).Decode(&results)

	if len(results) < 2 {
		t.Errorf("expected at least 2 results for 'team', got %d", len(results))
	}
}
