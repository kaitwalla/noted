-- +goose Up
CREATE TABLE link_previews (
    id UUID PRIMARY KEY,
    url TEXT NOT NULL UNIQUE,
    title TEXT,
    description TEXT,
    image_url TEXT,
    favicon_url TEXT,
    site_name TEXT,
    fetched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE note_link_previews (
    note_id UUID REFERENCES notes(id) ON DELETE CASCADE,
    link_preview_id UUID REFERENCES link_previews(id) ON DELETE CASCADE,
    position INT NOT NULL DEFAULT 0,
    PRIMARY KEY (note_id, link_preview_id)
);

CREATE INDEX idx_link_previews_url ON link_previews(url);
CREATE INDEX idx_note_link_previews_note_id ON note_link_previews(note_id);

-- +goose Down
DROP TABLE IF EXISTS note_link_previews;
DROP TABLE IF EXISTS link_previews;
