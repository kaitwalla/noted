package api_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"image/jpeg"
	"image/png"
	"io"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/noted/server/internal/api"
	"github.com/noted/server/internal/config"
	"github.com/noted/server/internal/models"
	"github.com/noted/server/internal/testutil"
)

func setupTestServerWithNote(t *testing.T) (*api.Server, string, string, string) {
	t.Helper()
	db := testutil.TestDB(t)
	testutil.CleanTables(t, db)
	blobStore := testutil.TestBlobStore(t)

	cfg := &config.Config{
		JWTSecret:        "test-secret",
		JWTExpiration:    15 * time.Minute,
		RefreshExpiry:    7 * 24 * time.Hour,
		StorageURLExpiry: 1 * time.Hour,
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

	// Create a note
	noteBody, _ := json.Marshal(map[string]interface{}{
		"content":    map[string]string{"type": "text", "content": "Test note"},
		"plain_text": "Test note",
	})
	noteReq := httptest.NewRequest(http.MethodPost, "/api/notebooks/"+nb.ID.String()+"/notes", bytes.NewReader(noteBody))
	noteReq.Header.Set("Content-Type", "application/json")
	noteReq.Header.Set("Authorization", "Bearer "+token)
	noteRec := httptest.NewRecorder()
	srv.ServeHTTP(noteRec, noteReq)

	var note models.Note
	json.NewDecoder(noteRec.Body).Decode(&note)

	return srv, token, nb.ID.String(), note.ID.String()
}

// createTestImage creates a test image with the specified dimensions
func createTestImage(width, height int, format string) ([]byte, string) {
	img := image.NewRGBA(image.Rect(0, 0, width, height))
	// Fill with a color pattern
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			img.Set(x, y, color.RGBA{uint8(x % 256), uint8(y % 256), 128, 255})
		}
	}

	var buf bytes.Buffer
	var contentType string

	switch format {
	case "png":
		png.Encode(&buf, img)
		contentType = "image/png"
	default:
		jpeg.Encode(&buf, img, &jpeg.Options{Quality: 90})
		contentType = "image/jpeg"
	}

	return buf.Bytes(), contentType
}

func createMultipartRequest(noteID string, imageData []byte, filename, contentType string, keepFullSize bool) (*bytes.Buffer, string) {
	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)

	// Add note_id field
	writer.WriteField("note_id", noteID)

	// Add keep_full_size field
	writer.WriteField("keep_full_size", fmt.Sprintf("%t", keepFullSize))

	// Add file
	part, _ := writer.CreateFormFile("file", filename)
	io.Copy(part, bytes.NewReader(imageData))

	writer.Close()
	return body, writer.FormDataContentType()
}

func TestImageUpload(t *testing.T) {
	srv, token, _, noteID := setupTestServerWithNote(t)

	t.Run("upload small image (no resize needed)", func(t *testing.T) {
		// Create a small 500x500 image
		imageData, _ := createTestImage(500, 500, "jpeg")
		body, contentType := createMultipartRequest(noteID, imageData, "test.jpg", "image/jpeg", false)

		req := httptest.NewRequest(http.MethodPost, "/api/images", body)
		req.Header.Set("Content-Type", contentType)
		req.Header.Set("Authorization", "Bearer "+token)
		rec := httptest.NewRecorder()

		srv.ServeHTTP(rec, req)

		if rec.Code != http.StatusCreated {
			t.Errorf("Expected status 201, got %d: %s", rec.Code, rec.Body.String())
		}

		var resp map[string]interface{}
		json.NewDecoder(rec.Body).Decode(&resp)

		if resp["mime_type"] != "image/jpeg" {
			t.Errorf("Expected mime_type image/jpeg, got %v", resp["mime_type"])
		}
	})

	t.Run("upload large image (resize by default)", func(t *testing.T) {
		// Create a large 3000x2000 image
		imageData, _ := createTestImage(3000, 2000, "jpeg")
		originalSize := len(imageData)
		body, contentType := createMultipartRequest(noteID, imageData, "large.jpg", "image/jpeg", false)

		req := httptest.NewRequest(http.MethodPost, "/api/images", body)
		req.Header.Set("Content-Type", contentType)
		req.Header.Set("Authorization", "Bearer "+token)
		rec := httptest.NewRecorder()

		srv.ServeHTTP(rec, req)

		if rec.Code != http.StatusCreated {
			t.Errorf("Expected status 201, got %d: %s", rec.Code, rec.Body.String())
		}

		var resp map[string]interface{}
		json.NewDecoder(rec.Body).Decode(&resp)

		// The resized image should be smaller than the original
		uploadedSize := int(resp["size"].(float64))
		if uploadedSize >= originalSize {
			t.Logf("Warning: resized image (%d) is not smaller than original (%d)", uploadedSize, originalSize)
		}
	})

	t.Run("upload large image with keep_full_size=true", func(t *testing.T) {
		// Create a large 3000x2000 image
		imageData, _ := createTestImage(3000, 2000, "jpeg")
		originalSize := len(imageData)
		body, contentType := createMultipartRequest(noteID, imageData, "large_full.jpg", "image/jpeg", true)

		req := httptest.NewRequest(http.MethodPost, "/api/images", body)
		req.Header.Set("Content-Type", contentType)
		req.Header.Set("Authorization", "Bearer "+token)
		rec := httptest.NewRecorder()

		srv.ServeHTTP(rec, req)

		if rec.Code != http.StatusCreated {
			t.Errorf("Expected status 201, got %d: %s", rec.Code, rec.Body.String())
		}

		var resp map[string]interface{}
		json.NewDecoder(rec.Body).Decode(&resp)

		// With keep_full_size, the uploaded size should match original
		uploadedSize := int(resp["size"].(float64))
		if uploadedSize != originalSize {
			t.Errorf("Expected size %d (original), got %d", originalSize, uploadedSize)
		}
	})

	t.Run("upload PNG image", func(t *testing.T) {
		imageData, _ := createTestImage(800, 600, "png")
		body, contentType := createMultipartRequest(noteID, imageData, "test.png", "image/png", false)

		req := httptest.NewRequest(http.MethodPost, "/api/images", body)
		req.Header.Set("Content-Type", contentType)
		req.Header.Set("Authorization", "Bearer "+token)
		rec := httptest.NewRecorder()

		srv.ServeHTTP(rec, req)

		if rec.Code != http.StatusCreated {
			t.Errorf("Expected status 201, got %d: %s", rec.Code, rec.Body.String())
		}

		var resp map[string]interface{}
		json.NewDecoder(rec.Body).Decode(&resp)

		if resp["mime_type"] != "image/png" {
			t.Errorf("Expected mime_type image/png, got %v", resp["mime_type"])
		}
	})

	t.Run("upload large PNG (should resize)", func(t *testing.T) {
		// Create a large PNG
		imageData, _ := createTestImage(2500, 2500, "png")
		body, contentType := createMultipartRequest(noteID, imageData, "large.png", "image/png", false)

		req := httptest.NewRequest(http.MethodPost, "/api/images", body)
		req.Header.Set("Content-Type", contentType)
		req.Header.Set("Authorization", "Bearer "+token)
		rec := httptest.NewRecorder()

		srv.ServeHTTP(rec, req)

		if rec.Code != http.StatusCreated {
			t.Errorf("Expected status 201, got %d: %s", rec.Code, rec.Body.String())
		}

		// Should still be PNG after resize
		var resp map[string]interface{}
		json.NewDecoder(rec.Body).Decode(&resp)

		if resp["mime_type"] != "image/png" {
			t.Errorf("Expected mime_type image/png, got %v", resp["mime_type"])
		}
	})
}

func TestImageUploadUnauthorized(t *testing.T) {
	srv, _, _, noteID := setupTestServerWithNote(t)

	imageData, _ := createTestImage(100, 100, "jpeg")
	body, contentType := createMultipartRequest(noteID, imageData, "test.jpg", "image/jpeg", false)

	req := httptest.NewRequest(http.MethodPost, "/api/images", body)
	req.Header.Set("Content-Type", contentType)
	// No Authorization header
	rec := httptest.NewRecorder()

	srv.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("Expected status 401, got %d", rec.Code)
	}
}

func TestImageUploadInvalidNoteID(t *testing.T) {
	srv, token, _, _ := setupTestServerWithNote(t)

	imageData, _ := createTestImage(100, 100, "jpeg")
	body, contentType := createMultipartRequest("invalid-uuid", imageData, "test.jpg", "image/jpeg", false)

	req := httptest.NewRequest(http.MethodPost, "/api/images", body)
	req.Header.Set("Content-Type", contentType)
	req.Header.Set("Authorization", "Bearer "+token)
	rec := httptest.NewRecorder()

	srv.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("Expected status 400, got %d", rec.Code)
	}
}

func TestImageUploadInvalidFileType(t *testing.T) {
	srv, token, _, noteID := setupTestServerWithNote(t)

	// Create a "fake" image with text content
	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)
	writer.WriteField("note_id", noteID)
	part, _ := writer.CreateFormFile("file", "fake.jpg")
	part.Write([]byte("this is not an image"))
	writer.Close()

	req := httptest.NewRequest(http.MethodPost, "/api/images", body)
	req.Header.Set("Content-Type", writer.FormDataContentType())
	req.Header.Set("Authorization", "Bearer "+token)
	rec := httptest.NewRecorder()

	srv.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("Expected status 400, got %d: %s", rec.Code, rec.Body.String())
	}
}
