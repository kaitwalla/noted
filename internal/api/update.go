package api

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"syscall"
	"time"
)

// validBranchName validates that a branch name contains only safe characters
var validBranchName = regexp.MustCompile(`^[a-zA-Z0-9._/-]+$`)

// UpdateStatus tracks the current state of an update
type UpdateStatus struct {
	InProgress bool      `json:"in_progress"`
	LastUpdate time.Time `json:"last_update,omitempty"`
	LastCommit string    `json:"last_commit,omitempty"`
	LastError  string    `json:"last_error,omitempty"`
	Message    string    `json:"message,omitempty"`
}

var (
	updateMu     sync.Mutex
	updateStatus = UpdateStatus{}
)

// handleUpdate handles manual update requests
func (s *Server) handleUpdate(w http.ResponseWriter, r *http.Request) {
	if !s.cfg.UpdateEnabled {
		respondError(w, http.StatusNotFound, "not_found", "Auto-update is not enabled")
		return
	}

	// Verify secret token (header only - never accept tokens in query strings)
	token := r.Header.Get("X-Update-Token")
	if !secureCompare(token, s.cfg.UpdateSecret) {
		respondError(w, http.StatusUnauthorized, "unauthorized", "Invalid update token")
		return
	}

	// Start update in background
	go s.performUpdate("manual trigger")

	respondJSON(w, http.StatusAccepted, map[string]string{
		"status":  "accepted",
		"message": "Update started in background",
	})
}

// handleGitHubWebhook handles GitHub webhook push events
func (s *Server) handleGitHubWebhook(w http.ResponseWriter, r *http.Request) {
	if !s.cfg.UpdateEnabled {
		respondError(w, http.StatusNotFound, "not_found", "Auto-update is not enabled")
		return
	}

	// Read the body
	body, err := io.ReadAll(r.Body)
	if err != nil {
		respondError(w, http.StatusBadRequest, "bad_request", "Failed to read request body")
		return
	}

	// Verify GitHub signature (always required - UpdateSecret is validated at startup)
	signature := r.Header.Get("X-Hub-Signature-256")
	if !verifyGitHubSignature(body, signature, s.cfg.UpdateSecret) {
		respondError(w, http.StatusUnauthorized, "unauthorized", "Invalid signature")
		return
	}

	// Parse the event
	event := r.Header.Get("X-GitHub-Event")
	if event != "push" {
		// Acknowledge but ignore non-push events
		respondJSON(w, http.StatusOK, map[string]string{
			"status":  "ignored",
			"message": fmt.Sprintf("Event type '%s' ignored", event),
		})
		return
	}

	// Parse push payload to check branch
	var payload struct {
		Ref string `json:"ref"`
	}
	if err := json.Unmarshal(body, &payload); err != nil {
		respondError(w, http.StatusBadRequest, "bad_request", "Invalid payload")
		return
	}

	// Check if it's the configured branch
	expectedRef := fmt.Sprintf("refs/heads/%s", s.cfg.GitBranch)
	if payload.Ref != expectedRef {
		respondJSON(w, http.StatusOK, map[string]string{
			"status":  "ignored",
			"message": fmt.Sprintf("Push to %s ignored (watching %s)", payload.Ref, expectedRef),
		})
		return
	}

	// Start update in background
	go s.performUpdate(fmt.Sprintf("GitHub push to %s", s.cfg.GitBranch))

	respondJSON(w, http.StatusAccepted, map[string]string{
		"status":  "accepted",
		"message": "Update triggered",
	})
}

// handleUpdateStatus returns the current update status
func (s *Server) handleUpdateStatus(w http.ResponseWriter, r *http.Request) {
	if !s.cfg.UpdateEnabled {
		respondError(w, http.StatusNotFound, "not_found", "Auto-update is not enabled")
		return
	}

	// Verify secret token (header only - never accept tokens in query strings)
	token := r.Header.Get("X-Update-Token")
	if !secureCompare(token, s.cfg.UpdateSecret) {
		respondError(w, http.StatusUnauthorized, "unauthorized", "Invalid update token")
		return
	}

	updateMu.Lock()
	status := updateStatus
	updateMu.Unlock()

	respondJSON(w, http.StatusOK, status)
}

// performUpdate runs the git pull, rebuild, and signals restart
func (s *Server) performUpdate(trigger string) {
	updateMu.Lock()
	if updateStatus.InProgress {
		updateMu.Unlock()
		log.Printf("Update already in progress, skipping trigger: %s", trigger)
		return
	}
	updateStatus.InProgress = true
	updateStatus.Message = fmt.Sprintf("Starting update: %s", trigger)
	updateStatus.LastError = ""
	updateMu.Unlock()

	log.Printf("Starting update: %s", trigger)

	defer func() {
		updateMu.Lock()
		updateStatus.InProgress = false
		updateMu.Unlock()
	}()

	rootPath := s.cfg.ServerRootPath
	branch := s.cfg.GitBranch

	// Validate branch name to prevent command injection
	if !validBranchName.MatchString(branch) {
		setError(fmt.Sprintf("Invalid branch name: %s", branch))
		return
	}

	// Step 1: Git fetch and pull
	setStatus("Fetching latest changes...")
	if err := runCommandWithTimeout(rootPath, 2*time.Minute, "git", "fetch", "origin", branch); err != nil {
		setError(fmt.Sprintf("Git fetch failed: %v", err))
		return
	}

	if err := runCommandWithTimeout(rootPath, 1*time.Minute, "git", "reset", "--hard", fmt.Sprintf("origin/%s", branch)); err != nil {
		setError(fmt.Sprintf("Git reset failed: %v", err))
		return
	}

	// Get the current commit
	commit, err := getCommandOutput(rootPath, "git", "rev-parse", "--short", "HEAD")
	if err != nil {
		log.Printf("Warning: couldn't get commit hash: %v", err)
	}

	// Step 2: Rebuild the server (with 10 minute timeout)
	setStatus("Building server...")
	serverDir := filepath.Join(rootPath, "server")
	if err := runCommandWithTimeout(serverDir, 10*time.Minute, "go", "build", "-o", "server", "./cmd/server"); err != nil {
		setError(fmt.Sprintf("Build failed: %v", err))
		return
	}

	// Step 3: Signal for restart by creating a restart marker file
	setStatus("Signaling restart...")
	restartFile := filepath.Join(serverDir, ".restart")
	if err := os.WriteFile(restartFile, []byte(time.Now().Format(time.RFC3339)), 0644); err != nil {
		log.Printf("Warning: couldn't write restart file: %v", err)
	}

	// Update status
	updateMu.Lock()
	updateStatus.LastUpdate = time.Now()
	updateStatus.LastCommit = strings.TrimSpace(commit)
	updateStatus.Message = "Update complete, restart pending"
	updateMu.Unlock()

	log.Printf("Update complete (commit: %s), signaling restart", strings.TrimSpace(commit))

	// Give a moment for the response to be sent, then signal ourselves to restart
	time.Sleep(500 * time.Millisecond)

	// Send SIGUSR1 to self to trigger graceful restart (handled by wrapper script)
	// If no wrapper script, this will be ignored
	if p, err := os.FindProcess(os.Getpid()); err == nil {
		p.Signal(syscall.SIGUSR1)
	}
}

func setStatus(msg string) {
	updateMu.Lock()
	updateStatus.Message = msg
	updateMu.Unlock()
	log.Printf("Update: %s", msg)
}

func setError(msg string) {
	updateMu.Lock()
	updateStatus.LastError = msg
	updateStatus.Message = "Update failed"
	updateMu.Unlock()
	log.Printf("Update error: %s", msg)
}

func runCommand(dir string, name string, args ...string) error {
	return runCommandWithTimeout(dir, 5*time.Minute, name, args...)
}

func runCommandWithTimeout(dir string, timeout time.Duration, name string, args ...string) error {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Dir = dir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func getCommandOutput(dir string, name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	out, err := cmd.Output()
	return string(out), err
}

func verifyGitHubSignature(payload []byte, signature, secret string) bool {
	if signature == "" {
		return false
	}

	// GitHub signature format: sha256=<hex>
	if !strings.HasPrefix(signature, "sha256=") {
		return false
	}
	sig, err := hex.DecodeString(signature[7:])
	if err != nil {
		return false
	}

	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(payload)
	expected := mac.Sum(nil)

	return hmac.Equal(sig, expected)
}

func secureCompare(a, b string) bool {
	if b == "" {
		return false
	}
	return subtle.ConstantTimeCompare([]byte(a), []byte(b)) == 1
}
