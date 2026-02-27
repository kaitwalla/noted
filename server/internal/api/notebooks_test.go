package api_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/noted/server/internal/api"
	"github.com/noted/server/internal/config"
	"github.com/noted/server/internal/models"
	"github.com/noted/server/internal/testutil"
)

func setupTestServer(t *testing.T) (*api.Server, string) {
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

	if regRec.Code != http.StatusCreated {
		t.Fatalf("failed to register user: %s", regRec.Body.String())
	}

	var authResp models.AuthResponse
	if err := json.NewDecoder(regRec.Body).Decode(&authResp); err != nil {
		t.Fatalf("failed to decode registration response: %v", err)
	}

	return srv, authResp.AccessToken
}

func TestNotebooksCRUD(t *testing.T) {
	srv, token := setupTestServer(t)

	// Create notebook
	t.Run("create notebook", func(t *testing.T) {
		body, _ := json.Marshal(map[string]string{"title": "My Notebook"})
		req := httptest.NewRequest(http.MethodPost, "/api/notebooks", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+token)
		rec := httptest.NewRecorder()

		srv.ServeHTTP(rec, req)

		if rec.Code != http.StatusCreated {
			t.Errorf("got status %d, want %d. Body: %s", rec.Code, http.StatusCreated, rec.Body.String())
		}

		var nb models.Notebook
		json.NewDecoder(rec.Body).Decode(&nb)
		if nb.Title != "My Notebook" {
			t.Errorf("got title %s, want My Notebook", nb.Title)
		}
	})

	// List notebooks (includes default "Main" notebook created on registration)
	t.Run("list notebooks", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/notebooks", nil)
		req.Header.Set("Authorization", "Bearer "+token)
		rec := httptest.NewRecorder()

		srv.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("got status %d, want %d", rec.Code, http.StatusOK)
		}

		var notebooks []models.Notebook
		json.NewDecoder(rec.Body).Decode(&notebooks)
		// Expect 2 notebooks: default "Main" + "My Notebook"
		if len(notebooks) != 2 {
			t.Errorf("got %d notebooks, want 2", len(notebooks))
		}
	})

	// Get notebook
	var notebookID string
	t.Run("get notebook", func(t *testing.T) {
		// First get the list to find the ID
		req := httptest.NewRequest(http.MethodGet, "/api/notebooks", nil)
		req.Header.Set("Authorization", "Bearer "+token)
		rec := httptest.NewRecorder()
		srv.ServeHTTP(rec, req)

		var notebooks []models.Notebook
		if err := json.NewDecoder(rec.Body).Decode(&notebooks); err != nil {
			t.Fatalf("failed to decode notebooks: %v", err)
		}
		if len(notebooks) == 0 {
			t.Fatal("expected at least one notebook, got empty list")
		}
		notebookID = notebooks[0].ID.String()

		req = httptest.NewRequest(http.MethodGet, "/api/notebooks/"+notebookID, nil)
		req.Header.Set("Authorization", "Bearer "+token)
		rec = httptest.NewRecorder()

		srv.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("got status %d, want %d", rec.Code, http.StatusOK)
		}
	})

	// Update notebook
	t.Run("update notebook", func(t *testing.T) {
		body, _ := json.Marshal(map[string]string{"title": "Updated Notebook"})
		req := httptest.NewRequest(http.MethodPut, "/api/notebooks/"+notebookID, bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+token)
		rec := httptest.NewRecorder()

		srv.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("got status %d, want %d", rec.Code, http.StatusOK)
		}

		var nb models.Notebook
		json.NewDecoder(rec.Body).Decode(&nb)
		if nb.Title != "Updated Notebook" {
			t.Errorf("got title %s, want Updated Notebook", nb.Title)
		}
	})

	// Delete notebook
	t.Run("delete notebook", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodDelete, "/api/notebooks/"+notebookID, nil)
		req.Header.Set("Authorization", "Bearer "+token)
		rec := httptest.NewRecorder()

		srv.ServeHTTP(rec, req)

		if rec.Code != http.StatusNoContent {
			t.Errorf("got status %d, want %d", rec.Code, http.StatusNoContent)
		}

		// Verify it's gone
		req = httptest.NewRequest(http.MethodGet, "/api/notebooks/"+notebookID, nil)
		req.Header.Set("Authorization", "Bearer "+token)
		rec = httptest.NewRecorder()
		srv.ServeHTTP(rec, req)

		if rec.Code != http.StatusNotFound {
			t.Errorf("got status %d, want %d after delete", rec.Code, http.StatusNotFound)
		}
	})
}

func TestNotebookValidation(t *testing.T) {
	srv, token := setupTestServer(t)

	t.Run("empty title", func(t *testing.T) {
		body, _ := json.Marshal(map[string]string{"title": ""})
		req := httptest.NewRequest(http.MethodPost, "/api/notebooks", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+token)
		rec := httptest.NewRecorder()

		srv.ServeHTTP(rec, req)

		if rec.Code != http.StatusBadRequest {
			t.Errorf("got status %d, want %d", rec.Code, http.StatusBadRequest)
		}
	})
}

func TestNotebookAuthorization(t *testing.T) {
	srv, token1 := setupTestServer(t)

	// Create a notebook with user 1
	body, _ := json.Marshal(map[string]string{"title": "User 1 Notebook"})
	req := httptest.NewRequest(http.MethodPost, "/api/notebooks", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token1)
	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("failed to create notebook: %s", rec.Body.String())
	}

	var nb models.Notebook
	if err := json.NewDecoder(rec.Body).Decode(&nb); err != nil {
		t.Fatalf("failed to decode notebook: %v", err)
	}

	// Register second user
	regBody, _ := json.Marshal(map[string]string{"email": "user2@example.com", "password": "password123"})
	regReq := httptest.NewRequest(http.MethodPost, "/api/auth/register", bytes.NewReader(regBody))
	regReq.Header.Set("Content-Type", "application/json")
	regRec := httptest.NewRecorder()
	srv.ServeHTTP(regRec, regReq)

	if regRec.Code != http.StatusCreated {
		t.Fatalf("failed to register user 2: %s", regRec.Body.String())
	}

	var authResp models.AuthResponse
	if err := json.NewDecoder(regRec.Body).Decode(&authResp); err != nil {
		t.Fatalf("failed to decode registration response: %v", err)
	}
	token2 := authResp.AccessToken

	// Try to access notebook with user 2
	t.Run("cannot access other user notebook", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, fmt.Sprintf("/api/notebooks/%s", nb.ID), nil)
		req.Header.Set("Authorization", "Bearer "+token2)
		rec := httptest.NewRecorder()

		srv.ServeHTTP(rec, req)

		// Should return 404 to prevent resource enumeration (not 403)
		if rec.Code != http.StatusNotFound {
			t.Errorf("got status %d, want %d", rec.Code, http.StatusNotFound)
		}
	})

	// Verify user 2 only has default notebook (not user 1's notebooks)
	t.Run("user2 has only default notebook", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/notebooks", nil)
		req.Header.Set("Authorization", "Bearer "+token2)
		rec := httptest.NewRecorder()

		srv.ServeHTTP(rec, req)

		var notebooks []models.Notebook
		json.NewDecoder(rec.Body).Decode(&notebooks)
		// User 2 should only have the default "Main" notebook created on registration
		if len(notebooks) != 1 {
			t.Errorf("got %d notebooks, want 1", len(notebooks))
		}
		if len(notebooks) > 0 && notebooks[0].Title != "Main" {
			t.Errorf("got title %s, want Main", notebooks[0].Title)
		}
	})
}
