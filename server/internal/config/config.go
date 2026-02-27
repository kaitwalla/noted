package config

import (
	"log"
	"os"
	"strconv"
	"strings"
	"time"
)

// Config holds application configuration
type Config struct {
	Port             string
	DatabaseURL      string
	JWTSecret        string
	JWTExpiration    time.Duration
	RefreshExpiry    time.Duration
	ImageStoragePath string
	AllowedOrigins   []string

	// Storage backend configuration
	StorageBackend       string        // "local" or "s3"
	StorageSigningSecret string        // HMAC secret for signing local URLs
	StorageURLExpiry     time.Duration // How long signed URLs are valid
	StorageBaseURL       string        // Base URL for image access (e.g., "http://localhost:8080/api/images")

	// S3-compatible storage configuration
	S3Bucket          string
	S3Region          string
	S3Endpoint        string // Custom endpoint for R2/DO Spaces/MinIO
	S3AccessKeyID     string
	S3SecretAccessKey string
	S3UsePathStyle    bool   // true for MinIO
	S3PublicURL       string // Optional CDN URL
}

// Load returns configuration from environment variables with defaults
func Load() *Config {
	dbURL := getEnv("DATABASE_URL", "postgres://noted:noted_dev_password@localhost:5432/noted?sslmode=disable")
	jwtSecret := getEnv("JWT_SECRET", "dev-secret-change-in-production")

	// Warn about insecure defaults in non-development environments
	if os.Getenv("GO_ENV") == "production" {
		if dbURL == "postgres://noted:noted_dev_password@localhost:5432/noted?sslmode=disable" {
			log.Fatal("DATABASE_URL must be set in production")
		}
		if jwtSecret == "dev-secret-change-in-production" {
			log.Fatal("JWT_SECRET must be set to a secure random value in production")
		}
	} else {
		if jwtSecret == "dev-secret-change-in-production" {
			log.Println("WARNING: Using default JWT_SECRET - do not use in production!")
		}
	}

	// Parse allowed origins from comma-separated list
	originsStr := getEnv("ALLOWED_ORIGINS", "http://localhost:5173,http://localhost:3000")
	allowedOrigins := strings.Split(originsStr, ",")
	for i := range allowedOrigins {
		allowedOrigins[i] = strings.TrimSpace(allowedOrigins[i])
	}

	// Storage configuration
	storageBackend := getEnv("STORAGE_BACKEND", "local")
	storageSigningSecret := getEnv("STORAGE_SIGNING_SECRET", "dev-signing-secret-change-in-production")

	// Production validation for storage signing secret
	if os.Getenv("GO_ENV") == "production" {
		if storageSigningSecret == "dev-signing-secret-change-in-production" {
			log.Fatal("STORAGE_SIGNING_SECRET must be set to a secure random value in production")
		}
	} else {
		if storageSigningSecret == "dev-signing-secret-change-in-production" {
			log.Println("WARNING: Using default STORAGE_SIGNING_SECRET - do not use in production!")
		}
	}

	return &Config{
		Port:             getEnv("PORT", "8080"),
		DatabaseURL:      dbURL,
		JWTSecret:        jwtSecret,
		JWTExpiration:    getDuration("JWT_EXPIRATION", 15*time.Minute),
		RefreshExpiry:    getDuration("REFRESH_EXPIRY", 7*24*time.Hour),
		ImageStoragePath: getEnv("IMAGE_STORAGE_PATH", "./uploads"),
		AllowedOrigins:   allowedOrigins,

		// Storage settings
		StorageBackend:       storageBackend,
		StorageSigningSecret: storageSigningSecret,
		StorageURLExpiry:     getDuration("STORAGE_URL_EXPIRY", 1*time.Hour),
		StorageBaseURL:       getEnv("STORAGE_BASE_URL", "/api/images"),

		// S3 settings
		S3Bucket:          getEnv("S3_BUCKET", ""),
		S3Region:          getEnv("S3_REGION", "us-east-1"),
		S3Endpoint:        getEnv("S3_ENDPOINT", ""),
		S3AccessKeyID:     getEnv("S3_ACCESS_KEY_ID", ""),
		S3SecretAccessKey: getEnv("S3_SECRET_ACCESS_KEY", ""),
		S3UsePathStyle:    getBool("S3_USE_PATH_STYLE", false),
		S3PublicURL:       getEnv("S3_PUBLIC_URL", ""),
	}
}

func getEnv(key, defaultVal string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultVal
}

func getDuration(key string, defaultVal time.Duration) time.Duration {
	if val := os.Getenv(key); val != "" {
		// Try parsing as duration string first (e.g., "1h", "30m")
		if d, err := time.ParseDuration(val); err == nil {
			return d
		}
		// Fall back to parsing as minutes
		if mins, err := strconv.Atoi(val); err == nil {
			return time.Duration(mins) * time.Minute
		}
	}
	return defaultVal
}

func getBool(key string, defaultVal bool) bool {
	if val := os.Getenv(key); val != "" {
		if b, err := strconv.ParseBool(val); err == nil {
			return b
		}
	}
	return defaultVal
}
