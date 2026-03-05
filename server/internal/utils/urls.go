package utils

import (
	"regexp"
	"strings"
)

// URL regex pattern that matches http/https URLs
var urlRegex = regexp.MustCompile(`https?://[^\s<>"{}|\\^` + "`" + `\[\]]+`)

// ExtractURLs extracts all URLs from the given text
func ExtractURLs(text string) []string {
	matches := urlRegex.FindAllString(text, -1)
	if matches == nil {
		return []string{}
	}

	// Deduplicate and clean URLs
	seen := make(map[string]bool)
	var urls []string
	for _, url := range matches {
		// Remove trailing punctuation that's likely not part of the URL
		url = strings.TrimRight(url, ".,;:!?)")
		if !seen[url] {
			seen[url] = true
			urls = append(urls, url)
		}
	}
	return urls
}
