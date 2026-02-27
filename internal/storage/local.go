package storage

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// LocalStore implements BlobStore using the local filesystem
type LocalStore struct {
	basePath      string
	signingSecret []byte
	baseURL       string
}

// LocalStoreConfig holds configuration for LocalStore
type LocalStoreConfig struct {
	BasePath      string
	SigningSecret string
	BaseURL       string // e.g., "/api/images"
}

// NewLocalStore creates a new local filesystem blob store
func NewLocalStore(cfg LocalStoreConfig) (*LocalStore, error) {
	// Create base directory if it doesn't exist
	if err := os.MkdirAll(cfg.BasePath, 0755); err != nil {
		return nil, fmt.Errorf("failed to create storage directory: %w", err)
	}

	// Validate or generate signing secret
	signingSecret := []byte(cfg.SigningSecret)
	if len(signingSecret) < 32 {
		if len(signingSecret) > 0 {
			log.Println("WARNING: SigningSecret is less than 32 bytes, generating a secure random secret")
		}
		signingSecret = make([]byte, 32)
		if _, err := rand.Read(signingSecret); err != nil {
			return nil, fmt.Errorf("failed to generate signing secret: %w", err)
		}
		log.Println("WARNING: Using auto-generated signing secret - URLs will be invalid after restart")
	}

	// Get absolute path for basePath to ensure consistent path comparisons
	absBasePath, err := filepath.Abs(cfg.BasePath)
	if err != nil {
		return nil, fmt.Errorf("failed to get absolute path: %w", err)
	}

	return &LocalStore{
		basePath:      absBasePath,
		signingSecret: signingSecret,
		baseURL:       cfg.BaseURL,
	}, nil
}

// sanitizePath validates and returns a safe file path within basePath
func (s *LocalStore) sanitizePath(key string) (string, error) {
	// Clean the key to remove any . or .. components
	cleanKey := filepath.Clean(key)

	// Ensure key doesn't start with / or contain ..
	if strings.HasPrefix(cleanKey, "/") || strings.HasPrefix(cleanKey, "..") || strings.Contains(cleanKey, "..") {
		return "", fmt.Errorf("invalid key: path traversal detected")
	}

	// Join with base path
	filePath := filepath.Join(s.basePath, cleanKey)

	// Verify the result is still within basePath
	if !strings.HasPrefix(filePath, s.basePath+string(os.PathSeparator)) && filePath != s.basePath {
		return "", fmt.Errorf("invalid key: path traversal detected")
	}

	return filePath, nil
}

// Put stores a blob in the local filesystem
func (s *LocalStore) Put(ctx context.Context, key string, reader io.Reader, contentType string, size int64) error {
	filePath, err := s.sanitizePath(key)
	if err != nil {
		return err
	}

	// Create file
	f, err := os.Create(filePath)
	if err != nil {
		return fmt.Errorf("failed to create file: %w", err)
	}
	defer f.Close()

	// Copy data
	if _, err := io.Copy(f, reader); err != nil {
		os.Remove(filePath)
		return fmt.Errorf("failed to write file: %w", err)
	}

	return nil
}

// Get retrieves a blob from the local filesystem
func (s *LocalStore) Get(ctx context.Context, key string) (io.ReadCloser, error) {
	filePath, err := s.sanitizePath(key)
	if err != nil {
		return nil, err
	}

	f, err := os.Open(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("failed to open file: %w", err)
	}

	return f, nil
}

// Delete removes a blob from the local filesystem
func (s *LocalStore) Delete(ctx context.Context, key string) error {
	filePath, err := s.sanitizePath(key)
	if err != nil {
		return err
	}

	if err := os.Remove(filePath); err != nil {
		if os.IsNotExist(err) {
			return ErrNotFound
		}
		return fmt.Errorf("failed to delete file: %w", err)
	}

	return nil
}

// Exists checks if a blob exists in the local filesystem
func (s *LocalStore) Exists(ctx context.Context, key string) (bool, error) {
	filePath, err := s.sanitizePath(key)
	if err != nil {
		return false, err
	}

	_, err = os.Stat(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			return false, nil
		}
		return false, fmt.Errorf("failed to stat file: %w", err)
	}

	return true, nil
}

// GetSignedURL generates an HMAC-signed URL for accessing the blob
func (s *LocalStore) GetSignedURL(ctx context.Context, key string, expiry time.Duration) (string, error) {
	expires := time.Now().Add(expiry).Unix()
	sig := s.generateSignature(key, expires)

	// Format: /api/images/{key}?expires={timestamp}&sig={signature}
	return fmt.Sprintf("%s/%s?expires=%d&sig=%s", s.baseURL, key, expires, sig), nil
}

// VerifySignedURL verifies an HMAC signature for a signed URL
func (s *LocalStore) VerifySignedURL(key string, expires int64, sig string) error {
	// Check expiration
	if time.Now().Unix() > expires {
		return ErrExpired
	}

	// Verify signature
	expectedSig := s.generateSignature(key, expires)
	if !hmac.Equal([]byte(sig), []byte(expectedSig)) {
		return ErrInvalidSignature
	}

	return nil
}

// generateSignature creates an HMAC-SHA256 signature
func (s *LocalStore) generateSignature(key string, expires int64) string {
	message := fmt.Sprintf("%s:%d", key, expires)
	h := hmac.New(sha256.New, s.signingSecret)
	h.Write([]byte(message))
	return hex.EncodeToString(h.Sum(nil))
}

// ParseSignedURLParams extracts signature parameters from query strings
func ParseSignedURLParams(expiresStr, sig, key string) (*SignedURLParams, error) {
	if expiresStr == "" || sig == "" {
		return nil, nil // No signed URL params present
	}

	expires, err := strconv.ParseInt(expiresStr, 10, 64)
	if err != nil {
		return nil, fmt.Errorf("invalid expires value: %w", err)
	}

	return &SignedURLParams{
		Key:     key,
		Expires: expires,
		Sig:     sig,
	}, nil
}

// Close is a no-op for local storage
func (s *LocalStore) Close() error {
	return nil
}
