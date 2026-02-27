package api

import (
	"bytes"
	"errors"
	"io"
	"log"
	"mime"
	"net/http"
	"path/filepath"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/noted/server/internal/models"
	"github.com/noted/server/internal/storage"
	"github.com/noted/server/internal/store"
)

const maxUploadSize = 10 << 20 // 10MB

// ImageResponse extends the Image model with a signed URL
type ImageResponse struct {
	ID         uuid.UUID `json:"id"`
	NoteID     uuid.UUID `json:"note_id"`
	Filename   string    `json:"filename"`
	MimeType   string    `json:"mime_type"`
	StorageKey string    `json:"storage_key"`
	Size       int64     `json:"size"`
	CreatedAt  time.Time `json:"created_at"`
	URL        string    `json:"url"`
}

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

	// Read first 512 bytes to detect content type from magic bytes
	headerBytes := make([]byte, 512)
	n, err := file.Read(headerBytes)
	if err != nil && err != io.EOF {
		respondError(w, http.StatusBadRequest, "invalid_request", "failed to read file")
		return
	}
	headerBytes = headerBytes[:n]

	// Detect actual content type from file contents
	detectedType := http.DetectContentType(headerBytes)

	// Validate detected content type
	if !isAllowedImageType(detectedType) {
		respondError(w, http.StatusBadRequest, "validation_error", "invalid file type. allowed: jpeg, png, gif, webp")
		return
	}

	// Reset file position for reading
	if _, err := file.Seek(0, io.SeekStart); err != nil {
		respondError(w, http.StatusInternalServerError, "server_error", "failed to process file")
		return
	}

	// Use detected content type (more reliable than header)
	contentType := detectedType

	// Generate storage key with validated extension
	imageID := uuid.New()
	ext := getExtensionForMimeType(contentType)
	if ext == "" {
		// Fallback to original extension only if it matches allowed types
		origExt := strings.ToLower(filepath.Ext(header.Filename))
		if isAllowedExtension(origExt) {
			ext = origExt
		} else {
			ext = ".bin"
		}
	}
	storageKey := imageID.String() + ext

	// Upload to blob store
	if err := s.blobStore.Put(r.Context(), storageKey, file, contentType, header.Size); err != nil {
		respondError(w, http.StatusInternalServerError, "server_error", "failed to save file")
		return
	}

	// Sanitize filename for storage (remove path components)
	safeFilename := filepath.Base(header.Filename)
	if safeFilename == "." || safeFilename == "/" {
		safeFilename = "image" + ext
	}

	// Create database record
	image := &models.Image{
		ID:         imageID,
		NoteID:     noteID,
		Filename:   safeFilename,
		MimeType:   contentType,
		StorageKey: storageKey,
		Size:       header.Size,
		CreatedAt:  time.Now(),
	}

	if err := s.store.CreateImage(r.Context(), image); err != nil {
		// Attempt to clean up the uploaded file and log if cleanup fails
		if cleanupErr := s.blobStore.Delete(r.Context(), storageKey); cleanupErr != nil {
			log.Printf("WARNING: failed to cleanup blob after database error: %v", cleanupErr)
		}
		respondError(w, http.StatusInternalServerError, "server_error", "failed to create image record")
		return
	}

	// Generate signed URL for the response (use image ID, not storage key)
	signedURL, err := s.blobStore.GetSignedURL(r.Context(), imageID.String(), s.config.StorageURLExpiry)
	if err != nil {
		// Log error but don't fail the request - image was uploaded successfully
		log.Printf("WARNING: failed to generate signed URL: %v", err)
		signedURL = ""
	}

	response := ImageResponse{
		ID:         image.ID,
		NoteID:     image.NoteID,
		Filename:   image.Filename,
		MimeType:   image.MimeType,
		StorageKey: image.StorageKey,
		Size:       image.Size,
		CreatedAt:  image.CreatedAt,
		URL:        signedURL,
	}

	respondJSON(w, http.StatusCreated, response)
}

func (s *Server) handleGetImage(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "invalid image ID")
		return
	}

	// Get image record
	image, err := s.store.GetImageByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			respondError(w, http.StatusNotFound, "not_found", "image not found")
			return
		}
		respondError(w, http.StatusInternalServerError, "server_error", "failed to get image")
		return
	}

	// Check for signed URL parameters
	expiresStr := r.URL.Query().Get("expires")
	sig := r.URL.Query().Get("sig")

	// Try signed URL authentication first
	if expiresStr != "" && sig != "" {
		params, err := storage.ParseSignedURLParams(expiresStr, sig, id.String())
		if err != nil {
			respondError(w, http.StatusBadRequest, "invalid_request", "invalid signature parameters")
			return
		}

		// Verify signature using SignedURLVerifier interface if available
		if verifier, ok := s.blobStore.(storage.SignedURLVerifier); ok {
			if err := verifier.VerifySignedURL(params.Key, params.Expires, params.Sig); err != nil {
				if errors.Is(err, storage.ErrExpired) {
					respondError(w, http.StatusForbidden, "forbidden", "url expired")
					return
				}
				respondError(w, http.StatusForbidden, "forbidden", "invalid signature")
				return
			}
			// Signature valid - serve the image
			s.serveImage(w, r, image)
			return
		}
		// If blob store doesn't support verification, fall through to JWT auth
	}

	// Fall back to JWT authentication
	userID, ok := GetUserID(r.Context())
	if !ok {
		// Try to authenticate via JWT
		userID, ok = s.tryAuthFromRequest(r)
		if !ok {
			respondError(w, http.StatusUnauthorized, "unauthorized", "authentication required")
			return
		}
	}

	// Verify note ownership
	note, err := s.store.GetNoteByID(r.Context(), image.NoteID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			respondError(w, http.StatusNotFound, "not_found", "associated note not found")
			return
		}
		respondError(w, http.StatusInternalServerError, "server_error", "failed to get note")
		return
	}

	if note.UserID != userID {
		respondError(w, http.StatusForbidden, "forbidden", "you don't have access to this image")
		return
	}

	s.serveImage(w, r, image)
}

func (s *Server) serveImage(w http.ResponseWriter, r *http.Request, image *models.Image) {
	reader, err := s.blobStore.Get(r.Context(), image.StorageKey)
	if err != nil {
		if errors.Is(err, storage.ErrNotFound) {
			respondError(w, http.StatusNotFound, "not_found", "image file not found")
			return
		}
		respondError(w, http.StatusInternalServerError, "server_error", "failed to read image file")
		return
	}
	defer reader.Close()

	w.Header().Set("Content-Type", image.MimeType)

	// Use mime.FormatMediaType to safely format Content-Disposition header
	// This prevents header injection attacks via malicious filenames
	disposition := mime.FormatMediaType("inline", map[string]string{
		"filename": image.Filename,
	})
	w.Header().Set("Content-Disposition", disposition)
	w.Header().Set("Cache-Control", "private, max-age=3600")

	// Copy the image data and log any errors
	if _, err := io.Copy(w, reader); err != nil {
		// Can't send error response after headers are written, just log
		log.Printf("ERROR: failed to serve image %s: %v", image.ID, err)
	}
}

func (s *Server) handleListNoteImages(w http.ResponseWriter, r *http.Request) {
	userID, ok := GetUserID(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized", "user not found in context")
		return
	}

	noteID, err := uuid.Parse(chi.URLParam(r, "noteId"))
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

	images, err := s.store.GetImagesByNoteID(r.Context(), noteID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "server_error", "failed to get images")
		return
	}

	// Generate signed URLs for each image (use image ID, not storage key)
	response := make([]ImageResponse, len(images))
	for i, img := range images {
		signedURL, _ := s.blobStore.GetSignedURL(r.Context(), img.ID.String(), s.config.StorageURLExpiry)
		response[i] = ImageResponse{
			ID:         img.ID,
			NoteID:     img.NoteID,
			Filename:   img.Filename,
			MimeType:   img.MimeType,
			StorageKey: img.StorageKey,
			Size:       img.Size,
			CreatedAt:  img.CreatedAt,
			URL:        signedURL,
		}
	}

	respondJSON(w, http.StatusOK, response)
}

func (s *Server) handleGetImageURL(w http.ResponseWriter, r *http.Request) {
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
		if errors.Is(err, store.ErrNotFound) {
			respondError(w, http.StatusNotFound, "not_found", "associated note not found")
			return
		}
		respondError(w, http.StatusInternalServerError, "server_error", "failed to get note")
		return
	}

	if note.UserID != userID {
		respondError(w, http.StatusForbidden, "forbidden", "you don't have access to this image")
		return
	}

	// Generate signed URL
	signedURL, err := s.blobStore.GetSignedURL(r.Context(), id.String(), s.config.StorageURLExpiry)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "server_error", "failed to generate signed URL")
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{
		"url": signedURL,
	})
}

// tryAuthFromRequest attempts to extract and validate JWT from request
func (s *Server) tryAuthFromRequest(r *http.Request) (uuid.UUID, bool) {
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" {
		return uuid.Nil, false
	}

	if len(authHeader) < 7 || authHeader[:7] != "Bearer " {
		return uuid.Nil, false
	}

	tokenStr := authHeader[7:]
	userID, err := s.validateToken(tokenStr)
	if err != nil {
		return uuid.Nil, false
	}

	return userID, true
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

func isAllowedExtension(ext string) bool {
	allowed := map[string]bool{
		".jpg":  true,
		".jpeg": true,
		".png":  true,
		".gif":  true,
		".webp": true,
	}
	return allowed[ext]
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

// detectContentType reads the first 512 bytes from a reader to detect content type
// and returns the detected type along with a new reader that includes those bytes
func detectContentType(r io.Reader) (string, io.Reader, error) {
	buf := make([]byte, 512)
	n, err := r.Read(buf)
	if err != nil && err != io.EOF {
		return "", nil, err
	}
	buf = buf[:n]

	contentType := http.DetectContentType(buf)
	return contentType, io.MultiReader(bytes.NewReader(buf), r), nil
}
