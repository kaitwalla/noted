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

func TestAuthRegister(t *testing.T) {
	db := testutil.TestDB(t)
	testutil.CleanTables(t, db)
	blobStore := testutil.TestBlobStore(t)

	cfg := &config.Config{
		JWTSecret:      "test-secret",
		JWTExpiration:  15 * time.Minute,
		RefreshExpiry:  7 * 24 * time.Hour,
	}
	srv := api.NewServer(db, cfg, blobStore)

	tests := []struct {
		name       string
		body       map[string]string
		wantStatus int
	}{
		{
			name:       "valid registration",
			body:       map[string]string{"email": "test@example.com", "password": "password123"},
			wantStatus: http.StatusCreated,
		},
		{
			name:       "duplicate email",
			body:       map[string]string{"email": "test@example.com", "password": "password456"},
			wantStatus: http.StatusConflict,
		},
		{
			name:       "missing email",
			body:       map[string]string{"password": "password123"},
			wantStatus: http.StatusBadRequest,
		},
		{
			name:       "short password",
			body:       map[string]string{"email": "test2@example.com", "password": "short"},
			wantStatus: http.StatusBadRequest,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			body, _ := json.Marshal(tt.body)
			req := httptest.NewRequest(http.MethodPost, "/api/auth/register", bytes.NewReader(body))
			req.Header.Set("Content-Type", "application/json")
			rec := httptest.NewRecorder()

			srv.ServeHTTP(rec, req)

			if rec.Code != tt.wantStatus {
				t.Errorf("got status %d, want %d. Body: %s", rec.Code, tt.wantStatus, rec.Body.String())
			}

			if tt.wantStatus == http.StatusCreated {
				var resp models.AuthResponse
				if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
					t.Fatalf("failed to decode response: %v", err)
				}
				if resp.AccessToken == "" {
					t.Error("expected access token")
				}
				if resp.RefreshToken == "" {
					t.Error("expected refresh token")
				}
				if resp.User == nil || resp.User.Email != tt.body["email"] {
					t.Error("expected user in response")
				}
			}
		})
	}
}

func TestAuthLogin(t *testing.T) {
	db := testutil.TestDB(t)
	testutil.CleanTables(t, db)
	blobStore := testutil.TestBlobStore(t)

	cfg := &config.Config{
		JWTSecret:      "test-secret",
		JWTExpiration:  15 * time.Minute,
		RefreshExpiry:  7 * 24 * time.Hour,
	}
	srv := api.NewServer(db, cfg, blobStore)

	// Register a user first
	regBody, _ := json.Marshal(map[string]string{"email": "login@example.com", "password": "password123"})
	regReq := httptest.NewRequest(http.MethodPost, "/api/auth/register", bytes.NewReader(regBody))
	regReq.Header.Set("Content-Type", "application/json")
	regRec := httptest.NewRecorder()
	srv.ServeHTTP(regRec, regReq)

	if regRec.Code != http.StatusCreated {
		t.Fatalf("failed to register user: %s", regRec.Body.String())
	}

	tests := []struct {
		name       string
		body       map[string]string
		wantStatus int
	}{
		{
			name:       "valid login",
			body:       map[string]string{"email": "login@example.com", "password": "password123"},
			wantStatus: http.StatusOK,
		},
		{
			name:       "wrong password",
			body:       map[string]string{"email": "login@example.com", "password": "wrongpassword"},
			wantStatus: http.StatusUnauthorized,
		},
		{
			name:       "unknown email",
			body:       map[string]string{"email": "unknown@example.com", "password": "password123"},
			wantStatus: http.StatusUnauthorized,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			body, _ := json.Marshal(tt.body)
			req := httptest.NewRequest(http.MethodPost, "/api/auth/login", bytes.NewReader(body))
			req.Header.Set("Content-Type", "application/json")
			rec := httptest.NewRecorder()

			srv.ServeHTTP(rec, req)

			if rec.Code != tt.wantStatus {
				t.Errorf("got status %d, want %d. Body: %s", rec.Code, tt.wantStatus, rec.Body.String())
			}
		})
	}
}

func TestAuthRefresh(t *testing.T) {
	db := testutil.TestDB(t)
	testutil.CleanTables(t, db)
	blobStore := testutil.TestBlobStore(t)

	cfg := &config.Config{
		JWTSecret:      "test-secret",
		JWTExpiration:  15 * time.Minute,
		RefreshExpiry:  7 * 24 * time.Hour,
	}
	srv := api.NewServer(db, cfg, blobStore)

	// Register a user
	regBody, _ := json.Marshal(map[string]string{"email": "refresh@example.com", "password": "password123"})
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

	// Test refresh
	refreshBody, _ := json.Marshal(map[string]string{"refresh_token": authResp.RefreshToken})
	req := httptest.NewRequest(http.MethodPost, "/api/auth/refresh", bytes.NewReader(refreshBody))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	srv.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("got status %d, want %d. Body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var newResp models.AuthResponse
	if err := json.NewDecoder(rec.Body).Decode(&newResp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if newResp.AccessToken == "" {
		t.Error("expected new access token")
	}
}

func TestAuthMe(t *testing.T) {
	db := testutil.TestDB(t)
	testutil.CleanTables(t, db)
	blobStore := testutil.TestBlobStore(t)

	cfg := &config.Config{
		JWTSecret:      "test-secret",
		JWTExpiration:  15 * time.Minute,
		RefreshExpiry:  7 * 24 * time.Hour,
	}
	srv := api.NewServer(db, cfg, blobStore)

	// Register a user
	regBody, _ := json.Marshal(map[string]string{"email": "me@example.com", "password": "password123"})
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

	// Test /me endpoint
	req := httptest.NewRequest(http.MethodGet, "/api/auth/me", nil)
	req.Header.Set("Authorization", "Bearer "+authResp.AccessToken)
	rec := httptest.NewRecorder()

	srv.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("got status %d, want %d. Body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var user models.User
	if err := json.NewDecoder(rec.Body).Decode(&user); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if user.Email != "me@example.com" {
		t.Errorf("got email %s, want me@example.com", user.Email)
	}
}

func TestAuthMiddleware(t *testing.T) {
	db := testutil.TestDB(t)
	testutil.CleanTables(t, db)
	blobStore := testutil.TestBlobStore(t)

	cfg := &config.Config{
		JWTSecret:      "test-secret",
		JWTExpiration:  15 * time.Minute,
		RefreshExpiry:  7 * 24 * time.Hour,
	}
	srv := api.NewServer(db, cfg, blobStore)

	tests := []struct {
		name       string
		authHeader string
		wantStatus int
	}{
		{
			name:       "missing header",
			authHeader: "",
			wantStatus: http.StatusUnauthorized,
		},
		{
			name:       "invalid format",
			authHeader: "InvalidToken",
			wantStatus: http.StatusUnauthorized,
		},
		{
			name:       "invalid token",
			authHeader: "Bearer invalid.token.here",
			wantStatus: http.StatusUnauthorized,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/api/notebooks", nil)
			if tt.authHeader != "" {
				req.Header.Set("Authorization", tt.authHeader)
			}
			rec := httptest.NewRecorder()

			srv.ServeHTTP(rec, req)

			if rec.Code != tt.wantStatus {
				t.Errorf("got status %d, want %d", rec.Code, tt.wantStatus)
			}
		})
	}
}
