package linkpreview

import (
	"context"
	"errors"
	"io"
	"net"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/noted/server/internal/models"
)

const (
	defaultTimeout   = 5 * time.Second
	maxBodySize      = 1024 * 1024 // 1MB
	defaultUserAgent = "Mozilla/5.0 (compatible; NotedBot/1.0)"
)

var (
	// ErrBlockedURL is returned when a URL is blocked for security reasons
	ErrBlockedURL = errors.New("URL is blocked for security reasons")
)

// Fetcher fetches and parses link previews
type Fetcher struct {
	client *http.Client
}

// NewFetcher creates a new link preview fetcher
func NewFetcher() *Fetcher {
	return &Fetcher{
		client: &http.Client{
			Timeout: defaultTimeout,
			CheckRedirect: func(req *http.Request, via []*http.Request) error {
				if len(via) >= 3 {
					return http.ErrUseLastResponse
				}
				// Validate redirect URLs as well
				if err := validateURL(req.URL); err != nil {
					return err
				}
				return nil
			},
		},
	}
}

// validateURL checks if a URL is safe to fetch (not internal/private)
func validateURL(u *url.URL) error {
	host := u.Hostname()

	// Block localhost and loopback
	if host == "localhost" || host == "127.0.0.1" || host == "::1" {
		return ErrBlockedURL
	}

	// Block common metadata endpoints
	if host == "169.254.169.254" || host == "metadata.google.internal" {
		return ErrBlockedURL
	}

	// Resolve hostname to check for private IPs
	ips, err := net.LookupIP(host)
	if err != nil {
		// If we can't resolve, allow it (DNS may work for the HTTP client)
		return nil
	}

	for _, ip := range ips {
		if isPrivateIP(ip) {
			return ErrBlockedURL
		}
	}

	return nil
}

// isPrivateIP checks if an IP is private, loopback, or link-local
func isPrivateIP(ip net.IP) bool {
	// Check for loopback
	if ip.IsLoopback() {
		return true
	}

	// Check for link-local (169.254.x.x for IPv4, fe80::/10 for IPv6)
	if ip.IsLinkLocalUnicast() || ip.IsLinkLocalMulticast() {
		return true
	}

	// Check for private ranges
	if ip.IsPrivate() {
		return true
	}

	// Additional check for IPv4-mapped IPv6 addresses
	if ip4 := ip.To4(); ip4 != nil {
		// 10.0.0.0/8
		if ip4[0] == 10 {
			return true
		}
		// 172.16.0.0/12
		if ip4[0] == 172 && ip4[1] >= 16 && ip4[1] <= 31 {
			return true
		}
		// 192.168.0.0/16
		if ip4[0] == 192 && ip4[1] == 168 {
			return true
		}
		// 169.254.0.0/16 (link-local)
		if ip4[0] == 169 && ip4[1] == 254 {
			return true
		}
	}

	return false
}

// Fetch fetches metadata from a URL
func (f *Fetcher) Fetch(ctx context.Context, targetURL string) (*models.LinkPreview, error) {
	// Parse and validate URL first
	parsedURL, err := url.Parse(targetURL)
	if err != nil {
		return nil, err
	}

	// Only allow http and https
	if parsedURL.Scheme != "http" && parsedURL.Scheme != "https" {
		return nil, ErrBlockedURL
	}

	// Validate the URL is not targeting internal resources
	if err := validateURL(parsedURL); err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, targetURL, nil)
	if err != nil {
		return nil, err
	}

	req.Header.Set("User-Agent", defaultUserAgent)
	req.Header.Set("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
	req.Header.Set("Accept-Language", "en-US,en;q=0.5")

	resp, err := f.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	// Limit body size
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxBodySize))
	if err != nil {
		return nil, err
	}

	html := string(body)
	now := time.Now()

	preview := &models.LinkPreview{
		ID:        uuid.New(),
		URL:       targetURL,
		FetchedAt: now,
		CreatedAt: now,
	}

	// Parse OpenGraph tags first
	if title := extractMetaContent(html, `property="og:title"`); title != "" {
		preview.Title = &title
	}
	if desc := extractMetaContent(html, `property="og:description"`); desc != "" {
		preview.Description = &desc
	}
	if image := extractMetaContent(html, `property="og:image"`); image != "" {
		resolvedImage := resolveURL(targetURL, image)
		preview.ImageURL = &resolvedImage
	}
	if siteName := extractMetaContent(html, `property="og:site_name"`); siteName != "" {
		preview.SiteName = &siteName
	}

	// Fallback to standard meta tags
	if preview.Title == nil {
		if title := extractTitle(html); title != "" {
			preview.Title = &title
		}
	}
	if preview.Description == nil {
		if desc := extractMetaContent(html, `name="description"`); desc != "" {
			preview.Description = &desc
		}
	}

	// Extract favicon
	if favicon := extractFavicon(html, targetURL); favicon != "" {
		preview.FaviconURL = &favicon
	}

	// If no site name, use hostname
	if preview.SiteName == nil {
		if parsed, err := url.Parse(targetURL); err == nil {
			hostname := strings.TrimPrefix(parsed.Hostname(), "www.")
			preview.SiteName = &hostname
		}
	}

	return preview, nil
}

// extractMetaContent extracts content from a meta tag with the given attribute
func extractMetaContent(html, attr string) string {
	// Build regex to find meta tag with specified attribute
	pattern := `<meta[^>]*` + regexp.QuoteMeta(attr) + `[^>]*content="([^"]*)"[^>]*>`
	re := regexp.MustCompile(pattern)
	matches := re.FindStringSubmatch(html)
	if len(matches) > 1 {
		return decodeHTMLEntities(strings.TrimSpace(matches[1]))
	}

	// Try alternate order (content before property)
	pattern2 := `<meta[^>]*content="([^"]*)"[^>]*` + regexp.QuoteMeta(attr) + `[^>]*>`
	re2 := regexp.MustCompile(pattern2)
	matches2 := re2.FindStringSubmatch(html)
	if len(matches2) > 1 {
		return decodeHTMLEntities(strings.TrimSpace(matches2[1]))
	}

	return ""
}

// extractTitle extracts the <title> tag content
func extractTitle(html string) string {
	re := regexp.MustCompile(`(?i)<title[^>]*>([^<]*)</title>`)
	matches := re.FindStringSubmatch(html)
	if len(matches) > 1 {
		return decodeHTMLEntities(strings.TrimSpace(matches[1]))
	}
	return ""
}

// extractFavicon extracts the favicon URL
func extractFavicon(html, baseURL string) string {
	// Try various favicon link patterns
	patterns := []string{
		`<link[^>]*rel="(?:shortcut )?icon"[^>]*href="([^"]*)"`,
		`<link[^>]*href="([^"]*)"[^>]*rel="(?:shortcut )?icon"`,
		`<link[^>]*rel="apple-touch-icon"[^>]*href="([^"]*)"`,
	}

	for _, pattern := range patterns {
		re := regexp.MustCompile(`(?i)` + pattern)
		matches := re.FindStringSubmatch(html)
		if len(matches) > 1 {
			return resolveURL(baseURL, matches[1])
		}
	}

	// Default to /favicon.ico
	if parsed, err := url.Parse(baseURL); err == nil {
		parsed.Path = "/favicon.ico"
		parsed.RawQuery = ""
		return parsed.String()
	}

	return ""
}

// resolveURL resolves a potentially relative URL against a base URL
func resolveURL(baseURL, href string) string {
	if strings.HasPrefix(href, "http://") || strings.HasPrefix(href, "https://") {
		return href
	}

	base, err := url.Parse(baseURL)
	if err != nil {
		return href
	}

	ref, err := url.Parse(href)
	if err != nil {
		return href
	}

	return base.ResolveReference(ref).String()
}

// decodeHTMLEntities decodes common HTML entities
func decodeHTMLEntities(s string) string {
	replacements := map[string]string{
		"&amp;":  "&",
		"&lt;":   "<",
		"&gt;":   ">",
		"&quot;": `"`,
		"&#39;":  "'",
		"&apos;": "'",
		"&nbsp;": " ",
	}
	for entity, char := range replacements {
		s = strings.ReplaceAll(s, entity, char)
	}
	return s
}
