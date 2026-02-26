-- +goose Up
-- Initial schema for Noted app

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;

-- Notebooks table
CREATE TABLE notebooks (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    title VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_notebooks_user_id ON notebooks(user_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_notebooks_updated_at ON notebooks(user_id, updated_at);

-- Notes table
CREATE TABLE notes (
    id UUID PRIMARY KEY,
    notebook_id UUID NOT NULL REFERENCES notebooks(id),
    user_id UUID NOT NULL REFERENCES users(id),
    content JSONB NOT NULL DEFAULT '{}',
    plain_text TEXT NOT NULL DEFAULT '',
    is_todo BOOLEAN NOT NULL DEFAULT FALSE,
    is_done BOOLEAN NOT NULL DEFAULT FALSE,
    reminder_at TIMESTAMP WITH TIME ZONE,
    version BIGINT NOT NULL DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_notes_notebook_id ON notes(notebook_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_notes_user_id ON notes(user_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_notes_updated_at ON notes(user_id, updated_at);
CREATE INDEX idx_notes_reminder ON notes(reminder_at) WHERE reminder_at IS NOT NULL AND deleted_at IS NULL;

-- Full-text search index on plain_text
CREATE INDEX idx_notes_fts ON notes USING gin(to_tsvector('english', plain_text)) WHERE deleted_at IS NULL;

-- Tags table
CREATE TABLE tags (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    name VARCHAR(100) NOT NULL,
    color VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(user_id, name)
);

CREATE INDEX idx_tags_user_id ON tags(user_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_tags_updated_at ON tags(user_id, updated_at);

-- Note-Tag junction table
CREATE TABLE note_tags (
    note_id UUID NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
    tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (note_id, tag_id)
);

CREATE INDEX idx_note_tags_tag_id ON note_tags(tag_id);

-- Images table
CREATE TABLE images (
    id UUID PRIMARY KEY,
    note_id UUID NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
    filename VARCHAR(255) NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    storage_key VARCHAR(500) NOT NULL,
    size BIGINT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_images_note_id ON images(note_id);

-- +goose Down
DROP TABLE IF EXISTS images;
DROP TABLE IF EXISTS note_tags;
DROP TABLE IF EXISTS tags;
DROP TABLE IF EXISTS notes;
DROP TABLE IF EXISTS notebooks;
DROP TABLE IF EXISTS users;
