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

	return &Config{
		Port:             getEnv("PORT", "8080"),
		DatabaseURL:      dbURL,
		JWTSecret:        jwtSecret,
		JWTExpiration:    getDuration("JWT_EXPIRATION", 15*time.Minute),
		RefreshExpiry:    getDuration("REFRESH_EXPIRY", 7*24*time.Hour),
		ImageStoragePath: getEnv("IMAGE_STORAGE_PATH", "./uploads"),
		AllowedOrigins:   allowedOrigins,
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
		if mins, err := strconv.Atoi(val); err == nil {
			return time.Duration(mins) * time.Minute
		}
	}
	return defaultVal
}
