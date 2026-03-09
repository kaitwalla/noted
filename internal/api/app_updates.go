package api

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"
)

// In-memory storage for app release info (persisted via env vars on restart)
var (
	appReleasesMu sync.RWMutex
	appReleases   = map[string]*AppReleaseConfig{
		"macos": {
			Version:          "1.0",
			Build:            2,
			ReleaseNotes:     "Initial release with auto-update support.",
			DownloadURL:      "",
			MinimumOSVersion: "14.0",
			EdSignature:      "",
			FileLength:       0,
			PublishedAt:      time.Now(),
		},
	}
)

// AppReleaseConfig holds the full release configuration including signature
type AppReleaseConfig struct {
	Version          string    `json:"version"`
	Build            int       `json:"build"`
	ReleaseNotes     string    `json:"release_notes"`
	DownloadURL      string    `json:"download_url"`
	MinimumOSVersion string    `json:"minimum_os_version"`
	EdSignature      string    `json:"ed_signature"`
	FileLength       int64     `json:"file_length"`
	PublishedAt      time.Time `json:"published_at"`
}

func init() {
	// Load from environment variables on startup
	loadReleaseFromEnv("macos")
}

func loadReleaseFromEnv(platform string) {
	appReleasesMu.Lock()
	defer appReleasesMu.Unlock()

	upper := strings.ToUpper(platform)
	release, ok := appReleases[platform]
	if !ok {
		release = &AppReleaseConfig{}
		appReleases[platform] = release
	}

	if v := os.Getenv("APP_VERSION_" + upper); v != "" {
		release.Version = v
	}
	if b := os.Getenv("APP_BUILD_" + upper); b != "" {
		release.Build, _ = strconv.Atoi(b)
	}
	if url := os.Getenv("APP_DOWNLOAD_URL_" + upper); url != "" {
		release.DownloadURL = url
	}
	if notes := os.Getenv("APP_RELEASE_NOTES_" + upper); notes != "" {
		release.ReleaseNotes = notes
	}
	if sig := os.Getenv("APP_ED_SIGNATURE_" + upper); sig != "" {
		release.EdSignature = sig
	}
	if length := os.Getenv("APP_FILE_LENGTH_" + upper); length != "" {
		release.FileLength, _ = strconv.ParseInt(length, 10, 64)
	}
	if minOS := os.Getenv("APP_MIN_OS_" + upper); minOS != "" {
		release.MinimumOSVersion = minOS
	}
}

// AppUpdateInfo represents version information for a native app
type AppUpdateInfo struct {
	Version          string `json:"version"`
	Build            int    `json:"build"`
	ReleaseNotes     string `json:"release_notes,omitempty"`
	DownloadURL      string `json:"download_url"`
	MinimumOSVersion string `json:"minimum_os_version,omitempty"`
	PublishedAt      string `json:"published_at,omitempty"`
}

// App version configuration (in production, these would come from config/DB)
var appVersions = map[string]AppUpdateInfo{
	"macos": {
		Version:          "1.0",
		Build:            2,
		ReleaseNotes:     "Initial release with auto-update support.",
		DownloadURL:      "https://github.com/kaitcollins/noted/releases/latest/download/Noted.dmg",
		MinimumOSVersion: "14.0",
	},
	"ios": {
		Version:          "1.0",
		Build:            1,
		ReleaseNotes:     "Initial release.",
		DownloadURL:      "https://apps.apple.com/app/noted/id123456789", // Placeholder
		MinimumOSVersion: "17.0",
	},
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
		parts := strings.Split(userAgent, " ")
		if len(parts) >= 1 {
			versionPart := strings.TrimPrefix(parts[0], "Noted/")
			currentVersion = versionPart
		}
		// Extract build number
		for _, part := range parts {
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

	// Check for environment variable overrides (for development/testing)
	if envVersion := os.Getenv("APP_VERSION_" + strings.ToUpper(platform)); envVersion != "" {
		if info, ok := appVersions[platform]; ok {
			info.Version = envVersion
			appVersions[platform] = info
		}
	}
	if envBuild := os.Getenv("APP_BUILD_" + strings.ToUpper(platform)); envBuild != "" {
		if build, err := strconv.Atoi(envBuild); err == nil {
			if info, ok := appVersions[platform]; ok {
				info.Build = build
				appVersions[platform] = info
			}
		}
	}

	// Get latest version for platform
	info, ok := appVersions[platform]
	if !ok {
		respondError(w, http.StatusNotFound, "unknown_platform", "Unknown platform: "+platform)
		return
	}

	// Check if update is available
	// Compare build numbers (more reliable than version strings)
	if currentBuild >= info.Build {
		// Also check version string as fallback
		if !isNewerVersion(info.Version, currentVersion) {
			// No update available
			w.WriteHeader(http.StatusNoContent)
			return
		}
	}

	// Update available
	respondJSON(w, http.StatusOK, info)
}

// isNewerVersion returns true if newVersion is newer than currentVersion
func isNewerVersion(newVersion, currentVersion string) bool {
	if currentVersion == "" {
		return true // If no current version, any version is newer
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

	return false // Versions are equal
}

// handleGetAppInfo returns information about available app downloads
func (s *Server) handleGetAppInfo(w http.ResponseWriter, r *http.Request) {
	// Return info about all available platforms
	info := map[string]interface{}{
		"platforms": []map[string]interface{}{
			{
				"platform":     "macos",
				"display_name": "macOS",
				"version":      appVersions["macos"].Version,
				"download_url": appVersions["macos"].DownloadURL,
				"min_os":       appVersions["macos"].MinimumOSVersion,
				"arch":         runtime.GOARCH, // Current server arch for reference
			},
			{
				"platform":     "ios",
				"display_name": "iOS",
				"version":      appVersions["ios"].Version,
				"download_url": appVersions["ios"].DownloadURL,
				"min_os":       appVersions["ios"].MinimumOSVersion,
			},
		},
	}
	respondJSON(w, http.StatusOK, info)
}

// SparkleAppcastItem represents a single update item in the appcast
type SparkleAppcastItem struct {
	Version          string
	Build            string
	DownloadURL      string
	ReleaseNotes     string
	MinimumOSVersion string
	PublishedAt      time.Time
	// EdDSA signature - must be generated when creating release
	EdSignature string
	// File size in bytes
	Length int64
}

// handleSparkleAppcast serves the Sparkle appcast XML for macOS auto-updates
func (s *Server) handleSparkleAppcast(w http.ResponseWriter, r *http.Request) {
	appReleasesMu.RLock()
	release, ok := appReleases["macos"]
	appReleasesMu.RUnlock()

	if !ok || release.DownloadURL == "" {
		// Fall back to defaults if no release configured
		respondError(w, http.StatusNotFound, "no_release", "No macOS release configured")
		return
	}

	info := AppUpdateInfo{
		Version:          release.Version,
		Build:            release.Build,
		ReleaseNotes:     release.ReleaseNotes,
		DownloadURL:      release.DownloadURL,
		MinimumOSVersion: release.MinimumOSVersion,
	}

	edSignature := release.EdSignature
	fileLength := release.FileLength
	publishedAt := release.PublishedAt

	// Build the appcast XML
	// Note: In production, you should sign your updates with EdDSA
	// Generate keys with: ./bin/generate_keys (from Sparkle)
	// Sign updates with: ./bin/sign_update <path-to-update.zip>

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
		info.Version,
		info.Build,
		info.Version,
		info.MinimumOSVersion,
		publishedAt.Format(time.RFC1123Z),
		info.ReleaseNotes,
		info.DownloadURL,
	)

	// Add optional attributes
	if edSignature != "" {
		appcastXML += fmt.Sprintf(`
        sparkle:edSignature="%s"`, edSignature)
	}
	if fileLength > 0 {
		appcastXML += fmt.Sprintf(`
        length="%d"`, fileLength)
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

// escapeXML escapes special XML characters
func escapeXML(s string) string {
	s = strings.ReplaceAll(s, "&", "&amp;")
	s = strings.ReplaceAll(s, "<", "&lt;")
	s = strings.ReplaceAll(s, ">", "&gt;")
	s = strings.ReplaceAll(s, "\"", "&quot;")
	s = strings.ReplaceAll(s, "'", "&apos;")
	return s
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
	// Verify admin token (reuse UPDATE_SECRET from server auto-update)
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

	// Validate required fields
	if req.Version == "" || req.Build == 0 || req.DownloadURL == "" {
		respondError(w, http.StatusBadRequest, "missing_fields", "version, build, and download_url are required")
		return
	}

	appReleasesMu.Lock()
	release, ok := appReleases[req.Platform]
	if !ok {
		release = &AppReleaseConfig{}
		appReleases[req.Platform] = release
	}

	release.Version = req.Version
	release.Build = req.Build
	release.ReleaseNotes = req.ReleaseNotes
	release.DownloadURL = req.DownloadURL
	release.EdSignature = req.EdSignature
	release.FileLength = req.FileLength
	release.PublishedAt = time.Now()

	if req.MinimumOSVersion != "" {
		release.MinimumOSVersion = req.MinimumOSVersion
	}
	appReleasesMu.Unlock()

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
	// Verify admin token
	token := r.Header.Get("X-Update-Token")
	if !secureCompare(token, s.cfg.UpdateSecret) {
		respondError(w, http.StatusUnauthorized, "unauthorized", "Invalid update token")
		return
	}

	platform := r.URL.Query().Get("platform")
	if platform == "" {
		platform = "macos"
	}

	appReleasesMu.RLock()
	release, ok := appReleases[platform]
	appReleasesMu.RUnlock()

	if !ok {
		respondError(w, http.StatusNotFound, "not_found", "No release found for platform: "+platform)
		return
	}

	respondJSON(w, http.StatusOK, release)
}
