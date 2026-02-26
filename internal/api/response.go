package api

import (
	"encoding/json"
	"log"
	"net/http"
)

// maxBodySize is the maximum allowed request body size (10MB)
const maxBodySize = 10 << 20

// ErrorResponse represents an error response
type ErrorResponse struct {
	Error   string `json:"error"`
	Message string `json:"message,omitempty"`
}

// respondJSON writes a JSON response
func respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if data != nil {
		if err := json.NewEncoder(w).Encode(data); err != nil {
			log.Printf("failed to encode JSON response: %v", err)
		}
	}
}

// respondError writes an error response
func respondError(w http.ResponseWriter, status int, err string, message string) {
	respondJSON(w, status, ErrorResponse{Error: err, Message: message})
}

// decodeJSON decodes a JSON request body with size limit
func decodeJSON(r *http.Request, v interface{}) error {
	r.Body = http.MaxBytesReader(nil, r.Body, maxBodySize)
	return json.NewDecoder(r.Body).Decode(v)
}
