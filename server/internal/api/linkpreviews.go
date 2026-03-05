package api

import (
	"context"
	"log"
	"net/http"
	"sync"

	"github.com/google/uuid"
	"github.com/noted/server/internal/linkpreview"
	"github.com/noted/server/internal/models"
	"github.com/noted/server/internal/utils"
)

const maxURLsPerRequest = 10

func (s *Server) handleFetchLinkPreviews(w http.ResponseWriter, r *http.Request) {
	var req models.FetchLinkPreviewsRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "invalid JSON body")
		return
	}

	if len(req.URLs) == 0 {
		respondJSON(w, http.StatusOK, []models.LinkPreview{})
		return
	}

	if len(req.URLs) > maxURLsPerRequest {
		req.URLs = req.URLs[:maxURLsPerRequest]
	}

	previews := s.fetchLinkPreviews(r.Context(), req.URLs)
	respondJSON(w, http.StatusOK, previews)
}

// fetchLinkPreviews fetches link previews for the given URLs, using cache when available
func (s *Server) fetchLinkPreviews(ctx context.Context, urls []string) []models.LinkPreview {
	var (
		mu       sync.Mutex
		wg       sync.WaitGroup
		previews []models.LinkPreview
	)

	fetcher := linkpreview.NewFetcher()

	for _, url := range urls {
		wg.Add(1)
		go func(targetURL string) {
			defer wg.Done()

			// Check cache first
			cached, err := s.store.GetLinkPreviewByURL(ctx, targetURL)
			if err == nil {
				mu.Lock()
				previews = append(previews, *cached)
				mu.Unlock()
				return
			}

			// Fetch new preview
			preview, err := fetcher.Fetch(ctx, targetURL)
			if err != nil {
				log.Printf("failed to fetch link preview for %s: %v", targetURL, err)
				return
			}

			// Cache the preview
			if err := s.store.CreateLinkPreview(ctx, preview); err != nil {
				log.Printf("failed to cache link preview for %s: %v", targetURL, err)
			}

			mu.Lock()
			previews = append(previews, *preview)
			mu.Unlock()
		}(url)
	}

	wg.Wait()
	return previews
}

// loadNoteLinkPreviews loads link previews for a note, fetching if needed
func (s *Server) loadNoteLinkPreviews(ctx context.Context, note *models.Note) {
	// First check if we have cached previews for this note
	previews, err := s.store.GetLinkPreviewsForNote(ctx, note.ID)
	if err == nil && len(previews) > 0 {
		note.LinkPreviews = previews
		return
	}

	// Extract URLs from plain text
	urls := utils.ExtractURLs(note.PlainText)
	if len(urls) == 0 {
		return
	}

	// Limit URLs
	if len(urls) > maxURLsPerRequest {
		urls = urls[:maxURLsPerRequest]
	}

	// Fetch previews
	previews = s.fetchLinkPreviews(ctx, urls)
	if len(previews) == 0 {
		return
	}

	// Link previews to note
	previewIDs := make([]uuid.UUID, len(previews))
	for i, p := range previews {
		previewIDs[i] = p.ID
	}

	// Store the association (best effort)
	if err := s.store.SetNoteLinkPreviews(ctx, note.ID, previewIDs); err != nil {
		log.Printf("failed to set note link previews for %s: %v", note.ID, err)
	}

	note.LinkPreviews = previews
}

// loadLinkPreviewsForNotes loads link previews for multiple notes
func (s *Server) loadLinkPreviewsForNotes(ctx context.Context, notes []models.Note) {
	for i := range notes {
		s.loadNoteLinkPreviews(ctx, &notes[i])
	}
}
