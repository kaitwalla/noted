package testutil

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"testing"

	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/noted/server/internal/store"
	"github.com/noted/server/migrations"
	"github.com/pressly/goose/v3"
)

// TestDB returns a configured database connection for testing
func TestDB(t *testing.T) *store.PostgresStore {
	t.Helper()

	dbURL := os.Getenv("TEST_DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://noted_test:noted_test_password@localhost:5433/noted_test?sslmode=disable"
	}

	// Run migrations
	db, err := sql.Open("pgx", dbURL)
	if err != nil {
		t.Fatalf("Failed to open database: %v", err)
	}
	defer db.Close()

	goose.SetBaseFS(migrations.FS)
	if err := goose.SetDialect("postgres"); err != nil {
		t.Fatalf("Failed to set dialect: %v", err)
	}

	// Reset database (ignore errors if tables don't exist on fresh DB)
	if err := goose.DownTo(db, ".", 0); err != nil {
		t.Logf("goose.DownTo warning (may be expected on fresh DB): %v", err)
	}
	if err := goose.Up(db, "."); err != nil {
		t.Fatalf("Failed to run migrations: %v", err)
	}

	// Create store
	ctx := context.Background()
	s, err := store.NewPostgresStore(ctx, dbURL)
	if err != nil {
		t.Fatalf("Failed to create store: %v", err)
	}

	t.Cleanup(func() {
		s.Close()
	})

	return s
}

// CleanTables truncates all tables for test isolation
func CleanTables(t *testing.T, db *store.PostgresStore) {
	t.Helper()
	ctx := context.Background()

	tables := []string{"note_tags", "images", "notes", "tags", "notebooks", "users"}
	for _, table := range tables {
		_, err := db.Pool().Exec(ctx, fmt.Sprintf("TRUNCATE TABLE %s CASCADE", table))
		if err != nil {
			t.Fatalf("Failed to truncate table %s: %v", table, err)
		}
	}
}
