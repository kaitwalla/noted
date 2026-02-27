-- +goose Up
-- Add sort_order column to notebooks for custom ordering

ALTER TABLE notebooks ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0;

-- Set initial sort_order based on created_at (older notebooks get lower sort_order)
WITH ordered AS (
    SELECT id, ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at ASC) as rn
    FROM notebooks
)
UPDATE notebooks SET sort_order = ordered.rn
FROM ordered
WHERE notebooks.id = ordered.id;

CREATE INDEX idx_notebooks_sort_order ON notebooks(user_id, sort_order) WHERE deleted_at IS NULL;

-- +goose Down
DROP INDEX IF EXISTS idx_notebooks_sort_order;
ALTER TABLE notebooks DROP COLUMN IF EXISTS sort_order;
