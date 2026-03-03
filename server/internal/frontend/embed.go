package frontend

import (
	"embed"
	"io/fs"
)

//go:embed dist/*
var distFS embed.FS

// FS returns the embedded frontend filesystem
func FS() (fs.FS, error) {
	return fs.Sub(distFS, "dist")
}
