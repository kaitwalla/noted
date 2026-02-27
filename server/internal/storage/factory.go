package storage

import (
	"fmt"
)

// Backend represents a storage backend type
type Backend string

const (
	BackendLocal Backend = "local"
	BackendS3    Backend = "s3"
)

// Config holds configuration for creating a BlobStore
type Config struct {
	Backend Backend

	// Local storage config
	LocalPath     string
	SigningSecret string
	BaseURL       string

	// S3 config (for future use)
	S3Bucket          string
	S3Region          string
	S3Endpoint        string
	S3AccessKeyID     string
	S3SecretAccessKey string
	S3UsePathStyle    bool
	S3PublicURL       string
}

// New creates a new BlobStore based on the configuration
func New(cfg Config) (BlobStore, error) {
	switch cfg.Backend {
	case BackendLocal, "":
		return NewLocalStore(LocalStoreConfig{
			BasePath:      cfg.LocalPath,
			SigningSecret: cfg.SigningSecret,
			BaseURL:       cfg.BaseURL,
		})

	case BackendS3:
		return NewS3Store(S3StoreConfig{
			Bucket:          cfg.S3Bucket,
			Region:          cfg.S3Region,
			Endpoint:        cfg.S3Endpoint,
			AccessKeyID:     cfg.S3AccessKeyID,
			SecretAccessKey: cfg.S3SecretAccessKey,
			UsePathStyle:    cfg.S3UsePathStyle,
			PublicURL:       cfg.S3PublicURL,
		})

	default:
		return nil, fmt.Errorf("unsupported storage backend: %s", cfg.Backend)
	}
}
