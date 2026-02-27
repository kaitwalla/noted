package storage

import (
	"context"
	"errors"
	"fmt"
	"io"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
)

// S3Store implements BlobStore using S3-compatible storage
type S3Store struct {
	client        *s3.Client
	presignClient *s3.PresignClient
	bucket        string
	publicURL     string
}

// S3StoreConfig holds configuration for S3Store
type S3StoreConfig struct {
	Bucket          string
	Region          string
	Endpoint        string // Custom endpoint for R2/DO/MinIO
	AccessKeyID     string
	SecretAccessKey string
	UsePathStyle    bool   // true for MinIO
	PublicURL       string // Optional CDN URL - WARNING: bypasses signed URL expiry
}

// NewS3Store creates a new S3-compatible blob store.
// Pass a context for configuration loading; use context.Background() if no cancellation is needed.
func NewS3Store(cfg S3StoreConfig) (*S3Store, error) {
	return NewS3StoreWithContext(context.Background(), cfg)
}

// NewS3StoreWithContext creates a new S3-compatible blob store with context support
func NewS3StoreWithContext(ctx context.Context, cfg S3StoreConfig) (*S3Store, error) {
	if cfg.Bucket == "" {
		return nil, fmt.Errorf("S3 bucket name is required")
	}

	// Build AWS config options
	var opts []func(*config.LoadOptions) error

	if cfg.Region != "" {
		opts = append(opts, config.WithRegion(cfg.Region))
	}

	if cfg.AccessKeyID != "" && cfg.SecretAccessKey != "" {
		opts = append(opts, config.WithCredentialsProvider(
			credentials.NewStaticCredentialsProvider(cfg.AccessKeyID, cfg.SecretAccessKey, ""),
		))
	}

	awsCfg, err := config.LoadDefaultConfig(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to load AWS config: %w", err)
	}

	// Build S3 client options
	var s3Opts []func(*s3.Options)

	if cfg.Endpoint != "" {
		s3Opts = append(s3Opts, func(o *s3.Options) {
			o.BaseEndpoint = aws.String(cfg.Endpoint)
		})
	}

	if cfg.UsePathStyle {
		s3Opts = append(s3Opts, func(o *s3.Options) {
			o.UsePathStyle = true
		})
	}

	client := s3.NewFromConfig(awsCfg, s3Opts...)
	presignClient := s3.NewPresignClient(client)

	return &S3Store{
		client:        client,
		presignClient: presignClient,
		bucket:        cfg.Bucket,
		publicURL:     cfg.PublicURL,
	}, nil
}

// Put stores a blob in S3
func (s *S3Store) Put(ctx context.Context, key string, reader io.Reader, contentType string, size int64) error {
	_, err := s.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:        aws.String(s.bucket),
		Key:           aws.String(key),
		Body:          reader,
		ContentType:   aws.String(contentType),
		ContentLength: aws.Int64(size),
	})
	if err != nil {
		return fmt.Errorf("failed to upload to S3: %w", err)
	}
	return nil
}

// Get retrieves a blob from S3
func (s *S3Store) Get(ctx context.Context, key string) (io.ReadCloser, error) {
	result, err := s.client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		// Check for not found error
		var noSuchKey *types.NoSuchKey
		if errors.As(err, &noSuchKey) {
			return nil, ErrNotFound
		}
		// Also check for generic "not found" in error message for compatibility
		var notFound *types.NotFound
		if errors.As(err, &notFound) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("failed to get object from S3: %w", err)
	}
	return result.Body, nil
}

// Delete removes a blob from S3
func (s *S3Store) Delete(ctx context.Context, key string) error {
	_, err := s.client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		var noSuchKey *types.NoSuchKey
		if errors.As(err, &noSuchKey) {
			return ErrNotFound
		}
		return fmt.Errorf("failed to delete from S3: %w", err)
	}
	return nil
}

// Exists checks if a blob exists in S3
func (s *S3Store) Exists(ctx context.Context, key string) (bool, error) {
	_, err := s.client.HeadObject(ctx, &s3.HeadObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		// Check for not found errors
		var noSuchKey *types.NoSuchKey
		if errors.As(err, &noSuchKey) {
			return false, nil
		}
		var notFound *types.NotFound
		if errors.As(err, &notFound) {
			return false, nil
		}
		// For HeadObject, AWS returns a generic error for not found
		// Check if error message indicates not found
		if isS3NotFoundError(err) {
			return false, nil
		}
		return false, fmt.Errorf("failed to check existence in S3: %w", err)
	}
	return true, nil
}

// isS3NotFoundError checks if an error indicates a not found condition
func isS3NotFoundError(err error) bool {
	if err == nil {
		return false
	}
	errStr := err.Error()
	return contains(errStr, "NotFound") || contains(errStr, "404") || contains(errStr, "NoSuchKey")
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > 0 && containsAt(s, substr))
}

func containsAt(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}

// GetSignedURL returns a presigned URL for accessing the blob.
//
// WARNING: If PublicURL is configured, this returns a permanent URL without
// signature or expiry. Only use PublicURL for public/CDN content where
// time-limited access is not required.
func (s *S3Store) GetSignedURL(ctx context.Context, key string, expiry time.Duration) (string, error) {
	// If we have a public URL configured, use that with the key
	// Note: This bypasses expiry - URLs are permanent
	if s.publicURL != "" {
		return fmt.Sprintf("%s/%s", s.publicURL, key), nil
	}

	// Generate presigned URL with expiry
	presignedReq, err := s.presignClient.PresignGetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(key),
	}, s3.WithPresignExpires(expiry))
	if err != nil {
		return "", fmt.Errorf("failed to create presigned URL: %w", err)
	}

	return presignedReq.URL, nil
}

// Close is a no-op for S3 storage
func (s *S3Store) Close() error {
	return nil
}
