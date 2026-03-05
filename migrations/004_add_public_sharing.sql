-- +goose Up
-- Migration: Add public sharing support for notes
-- Add is_public column to notes table
ALTER TABLE notes ADD COLUMN is_public BOOLEAN DEFAULT FALSE NOT NULL;

-- Create partial index for efficient public note lookups
CREATE INDEX idx_notes_public ON notes (id) WHERE is_public = TRUE AND deleted_at IS NULL;

-- +goose Down
DROP INDEX IF EXISTS idx_notes_public;
ALTER TABLE notes DROP COLUMN is_public;
