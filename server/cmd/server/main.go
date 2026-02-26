package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/noted/server/internal/api"
	"github.com/noted/server/internal/config"
	"github.com/noted/server/internal/store"
	"github.com/noted/server/migrations"
	"github.com/pressly/goose/v3"
)

func main() {
	cfg := config.Load()

	ctx := context.Background()

	// Run migrations first
	if err := runMigrations(cfg.DatabaseURL); err != nil {
		log.Fatalf("Failed to run migrations: %v", err)
	}

	// Connect to database
	pgStore, err := store.NewPostgresStore(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer pgStore.Close()

	// Create server
	srv := api.NewServer(pgStore, cfg)

	// Start HTTP server
	httpServer := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      srv,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Channel to signal shutdown completion
	done := make(chan struct{})

	// Graceful shutdown
	go func() {
		sigChan := make(chan os.Signal, 1)
		signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
		<-sigChan

		log.Println("Shutting down server...")
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()

		if err := httpServer.Shutdown(ctx); err != nil {
			log.Printf("Error during shutdown: %v", err)
		}
		close(done)
	}()

	log.Printf("Server starting on port %s", cfg.Port)
	if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("Server failed: %v", err)
	}

	// Wait for shutdown to complete
	<-done
	log.Println("Server stopped")
}

func runMigrations(databaseURL string) error {
	db, err := sql.Open("pgx", databaseURL)
	if err != nil {
		return fmt.Errorf("failed to open database for migrations: %w", err)
	}
	defer db.Close()

	goose.SetBaseFS(migrations.FS)

	if err := goose.SetDialect("postgres"); err != nil {
		return fmt.Errorf("failed to set dialect: %w", err)
	}

	if err := goose.Up(db, "."); err != nil {
		return fmt.Errorf("failed to run migrations: %w", err)
	}

	return nil
}
