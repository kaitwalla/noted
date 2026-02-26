-- +goose Up
-- Fix UNIQUE constraints to work with soft-delete pattern
-- Table-level UNIQUE constraints prevent reusing values after soft-delete

-- Users: Replace table-level UNIQUE on email with partial unique index
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_email_key;
DROP INDEX IF EXISTS idx_users_email;
CREATE UNIQUE INDEX idx_users_email_unique ON users(email) WHERE deleted_at IS NULL;

-- Tags: Replace table-level UNIQUE(user_id, name) with partial unique index
ALTER TABLE tags DROP CONSTRAINT IF EXISTS tags_user_id_name_key;
CREATE UNIQUE INDEX idx_tags_user_name_unique ON tags(user_id, name) WHERE deleted_at IS NULL;

-- +goose Down
-- Restore original constraints (note: this may fail if duplicate soft-deleted values exist)
DROP INDEX IF EXISTS idx_users_email_unique;
CREATE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;
ALTER TABLE users ADD CONSTRAINT users_email_key UNIQUE(email);

DROP INDEX IF EXISTS idx_tags_user_name_unique;
ALTER TABLE tags ADD CONSTRAINT tags_user_id_name_key UNIQUE(user_id, name);
