package api

import (
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"runtime"
	"strconv"
	"strings"
	"time"

	"github.com/noted/server/internal/models"
	"github.com/noted/server/internal/store"
)

// AppUpdateInfo represents version information for a native app
type AppUpdateInfo struct {
	Version          string `json:"version"`
	Build            int    `json:"build"`
	ReleaseNotes     string `json:"release_notes,omitempty"`
	DownloadURL      string `json:"download_url"`
	MinimumOSVersion string `json:"minimum_os_version,omitempty"`
	PublishedAt      string `json:"published_at,omitempty"`
}

// handleGetAppUpdate returns version info for a platform if an update is available
func (s *Server) handleGetAppUpdate(w http.ResponseWriter, r *http.Request) {
	// Get platform from URL path (e.g., /api/app/updates/macos)
	path := r.URL.Path
	parts := strings.Split(path, "/")
	var platform string
	for i, part := range parts {
		if part == "updates" && i+1 < len(parts) {
			platform = parts[i+1]
			break
		}
	}

	if platform == "" {
		respondError(w, http.StatusBadRequest, "missing_platform", "Platform is required")
		return
	}

	// Get current app version from User-Agent or query params
	userAgent := r.Header.Get("User-Agent")
	currentVersion := ""
	currentBuild := 0

	// Parse User-Agent: "Noted/1.0 (macOS; Build 1)"
	if strings.HasPrefix(userAgent, "Noted/") {
		uaParts := strings.Split(userAgent, " ")
		if len(uaParts) >= 1 {
			versionPart := strings.TrimPrefix(uaParts[0], "Noted/")
			currentVersion = versionPart
		}
		for _, part := range uaParts {
			if strings.HasPrefix(part, "Build") {
				buildStr := strings.TrimPrefix(part, "Build")
				buildStr = strings.Trim(buildStr, " )")
				if b, err := strconv.Atoi(buildStr); err == nil {
					currentBuild = b
				}
			}
		}
	}

	// Also check query params as fallback
	if v := r.URL.Query().Get("version"); v != "" {
		currentVersion = v
	}
	if b := r.URL.Query().Get("build"); b != "" {
		if build, err := strconv.Atoi(b); err == nil {
			currentBuild = build
		}
	}

	// Get latest release from database
	release, err := s.store.GetAppRelease(r.Context(), platform)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			respondError(w, http.StatusNotFound, "unknown_platform", "Unknown platform: "+platform)
			return
		}
		respondError(w, http.StatusInternalServerError, "server_error", "Failed to get release info")
		return
	}

	// Check if update is available
	if currentBuild >= release.Build {
		if !isNewerVersion(release.Version, currentVersion) {
			w.WriteHeader(http.StatusNoContent)
			return
		}
	}

	respondJSON(w, http.StatusOK, AppUpdateInfo{
		Version:          release.Version,
		Build:            release.Build,
		ReleaseNotes:     release.ReleaseNotes,
		DownloadURL:      release.DownloadURL,
		MinimumOSVersion: release.MinimumOSVersion,
	})
}

// isNewerVersion returns true if newVersion is newer than currentVersion
func isNewerVersion(newVersion, currentVersion string) bool {
	if currentVersion == "" {
		return true
	}

	newParts := strings.Split(newVersion, ".")
	currentParts := strings.Split(currentVersion, ".")

	maxLen := len(newParts)
	if len(currentParts) > maxLen {
		maxLen = len(currentParts)
	}

	for i := 0; i < maxLen; i++ {
		newPart := 0
		currentPart := 0

		if i < len(newParts) {
			newPart, _ = strconv.Atoi(newParts[i])
		}
		if i < len(currentParts) {
			currentPart, _ = strconv.Atoi(currentParts[i])
		}

		if newPart > currentPart {
			return true
		} else if newPart < currentPart {
			return false
		}
	}

	return false
}

// handleGetAppInfo returns information about available app downloads
func (s *Server) handleGetAppInfo(w http.ResponseWriter, r *http.Request) {
	macRelease, _ := s.store.GetAppRelease(r.Context(), "macos")
	iosRelease, _ := s.store.GetAppRelease(r.Context(), "ios")

	platforms := []map[string]interface{}{}

	if macRelease != nil {
		platforms = append(platforms, map[string]interface{}{
			"platform":     "macos",
			"display_name": "macOS",
			"version":      macRelease.Version,
			"download_url": macRelease.DownloadURL,
			"min_os":       macRelease.MinimumOSVersion,
			"arch":         runtime.GOARCH,
		})
	}
	if iosRelease != nil {
		platforms = append(platforms, map[string]interface{}{
			"platform":     "ios",
			"display_name": "iOS",
			"version":      iosRelease.Version,
			"download_url": iosRelease.DownloadURL,
			"min_os":       iosRelease.MinimumOSVersion,
		})
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"platforms": platforms,
	})
}

// handleSparkleAppcast serves the Sparkle appcast XML for macOS auto-updates
func (s *Server) handleSparkleAppcast(w http.ResponseWriter, r *http.Request) {
	release, err := s.store.GetAppRelease(r.Context(), "macos")
	if err != nil || release.DownloadURL == "" {
		respondError(w, http.StatusNotFound, "no_release", "No macOS release configured")
		return
	}

	appcastXML := fmt.Sprintf(`<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Noted Updates</title>
    <link>https://noted.app/updates</link>
    <description>Updates for Noted macOS app</description>
    <language>en</language>
    <item>
      <title>Version %s</title>
      <sparkle:version>%d</sparkle:version>
      <sparkle:shortVersionString>%s</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>%s</sparkle:minimumSystemVersion>
      <pubDate>%s</pubDate>
      <description><![CDATA[
        %s
      ]]></description>
      <enclosure
        url="%s"
        type="application/octet-stream"`,
		release.Version,
		release.Build,
		release.Version,
		release.MinimumOSVersion,
		release.PublishedAt.Format(time.RFC1123Z),
		release.ReleaseNotes,
		release.DownloadURL,
	)

	if release.EdSignature != "" {
		appcastXML += fmt.Sprintf(`
        sparkle:edSignature="%s"`, release.EdSignature)
	}
	if release.FileLength > 0 {
		appcastXML += fmt.Sprintf(`
        length="%d"`, release.FileLength)
	}

	appcastXML += `
      />
    </item>
  </channel>
</rss>`

	w.Header().Set("Content-Type", "application/xml; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(appcastXML))
}

// UpdateReleaseRequest is the request body for updating a release
type UpdateReleaseRequest struct {
	Platform         string `json:"platform"`
	Version          string `json:"version"`
	Build            int    `json:"build"`
	ReleaseNotes     string `json:"release_notes"`
	DownloadURL      string `json:"download_url"`
	MinimumOSVersion string `json:"minimum_os_version,omitempty"`
	EdSignature      string `json:"ed_signature"`
	FileLength       int64  `json:"file_length"`
}

// handleUpdateRelease updates the release info for a platform (admin endpoint)
func (s *Server) handleUpdateRelease(w http.ResponseWriter, r *http.Request) {
	token := r.Header.Get("X-Update-Token")
	if !secureCompare(token, s.cfg.UpdateSecret) {
		respondError(w, http.StatusUnauthorized, "unauthorized", "Invalid update token")
		return
	}

	var req UpdateReleaseRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "invalid_json", "Invalid request body")
		return
	}

	if req.Platform == "" {
		respondError(w, http.StatusBadRequest, "missing_platform", "Platform is required")
		return
	}

	if req.Version == "" || req.Build == 0 || req.DownloadURL == "" {
		respondError(w, http.StatusBadRequest, "missing_fields", "version, build, and download_url are required")
		return
	}

	now := time.Now()
	minOS := req.MinimumOSVersion
	if minOS == "" {
		minOS = "14.0"
	}

	release := &models.AppRelease{
		Platform:         req.Platform,
		Version:          req.Version,
		Build:            req.Build,
		ReleaseNotes:     req.ReleaseNotes,
		DownloadURL:      req.DownloadURL,
		MinimumOSVersion: minOS,
		EdSignature:      req.EdSignature,
		FileLength:       req.FileLength,
		PublishedAt:      now,
		UpdatedAt:        now,
	}

	if err := s.store.UpsertAppRelease(r.Context(), release); err != nil {
		log.Printf("Failed to persist release: %v", err)
		respondError(w, http.StatusInternalServerError, "server_error", "Failed to save release")
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"status":   "ok",
		"message":  fmt.Sprintf("Release %s build %d updated for %s", req.Version, req.Build, req.Platform),
		"platform": req.Platform,
		"version":  req.Version,
		"build":    req.Build,
	})
}

// handleGetRelease returns the current release info for a platform (admin endpoint)
func (s *Server) handleGetRelease(w http.ResponseWriter, r *http.Request) {
	token := r.Header.Get("X-Update-Token")
	if !secureCompare(token, s.cfg.UpdateSecret) {
		respondError(w, http.StatusUnauthorized, "unauthorized", "Invalid update token")
		return
	}

	platform := r.URL.Query().Get("platform")
	if platform == "" {
		platform = "macos"
	}

	release, err := s.store.GetAppRelease(r.Context(), platform)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			respondError(w, http.StatusNotFound, "not_found", "No release found for platform: "+platform)
			return
		}
		respondError(w, http.StatusInternalServerError, "server_error", "Failed to get release")
		return
	}

	respondJSON(w, http.StatusOK, release)
}
