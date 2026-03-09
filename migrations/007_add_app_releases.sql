-- +goose Up
CREATE TABLE app_releases (
    platform VARCHAR(50) PRIMARY KEY,
    version VARCHAR(50) NOT NULL,
    build INTEGER NOT NULL DEFAULT 1,
    release_notes TEXT NOT NULL DEFAULT '',
    download_url TEXT NOT NULL DEFAULT '',
    minimum_os_version VARCHAR(20) NOT NULL DEFAULT '14.0',
    ed_signature TEXT NOT NULL DEFAULT '',
    file_length BIGINT NOT NULL DEFAULT 0,
    published_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- +goose Down
DROP TABLE IF EXISTS app_releases;
