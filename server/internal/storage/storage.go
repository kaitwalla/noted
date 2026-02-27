package storage

import (
	"context"
	"errors"
	"io"
	"time"
)

var (
	// ErrNotFound is returned when a blob does not exist
	ErrNotFound = errors.New("blob not found")
	// ErrInvalidSignature is returned when URL signature is invalid
	ErrInvalidSignature = errors.New("invalid signature")
	// ErrExpired is returned when signed URL has expired
	ErrExpired = errors.New("url expired")
	// ErrPathTraversal is returned when a key contains path traversal
	ErrPathTraversal = errors.New("invalid key: path traversal detected")
)

// BlobStore defines the interface for blob storage backends
type BlobStore interface {
	// Put stores a blob with the given key
	Put(ctx context.Context, key string, reader io.Reader, contentType string, size int64) error

	// Get retrieves a blob by key
	Get(ctx context.Context, key string) (io.ReadCloser, error)

	// Delete removes a blob by key
	Delete(ctx context.Context, key string) error

	// Exists checks if a blob exists
	Exists(ctx context.Context, key string) (bool, error)

	// GetSignedURL returns a time-limited URL for accessing the blob
	GetSignedURL(ctx context.Context, key string, expiry time.Duration) (string, error)

	// Close releases any resources held by the store
	Close() error
}

// SignedURLVerifier is an optional interface for blob stores that support
// server-side signed URL verification (e.g., local storage with HMAC)
type SignedURLVerifier interface {
	// VerifySignedURL verifies a signed URL's signature and expiration
	VerifySignedURL(key string, expires int64, sig string) error
}

// SignedURLParams contains parameters extracted from a signed URL
type SignedURLParams struct {
	Key     string
	Expires int64
	Sig     string
}
