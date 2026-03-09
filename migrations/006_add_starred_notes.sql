-- +goose Up
-- Migration: Add starred/pinned notes support
ALTER TABLE notes ADD COLUMN is_starred BOOLEAN DEFAULT FALSE NOT NULL;

-- +goose Down
ALTER TABLE notes DROP COLUMN is_starred;
