package api

import (
	"net/http"
	"sync"
	"time"
)

// RateLimiter implements a simple token bucket rate limiter
type RateLimiter struct {
	mu       sync.Mutex
	visitors map[string]*visitor
	rate     int           // requests per window
	window   time.Duration // time window
	done     chan struct{} // for graceful shutdown
}

type visitor struct {
	tokens    int
	lastReset time.Time
}

// NewRateLimiter creates a new rate limiter
func NewRateLimiter(rate int, window time.Duration) *RateLimiter {
	rl := &RateLimiter{
		visitors: make(map[string]*visitor),
		rate:     rate,
		window:   window,
		done:     make(chan struct{}),
	}
	// Clean up old entries periodically
	go rl.cleanup()
	return rl
}

// Close stops the cleanup goroutine
func (rl *RateLimiter) Close() {
	close(rl.done)
}

func (rl *RateLimiter) cleanup() {
	ticker := time.NewTicker(rl.window * 2)
	defer ticker.Stop()

	for {
		select {
		case <-rl.done:
			return
		case <-ticker.C:
			rl.mu.Lock()
			for ip, v := range rl.visitors {
				if time.Since(v.lastReset) > rl.window*2 {
					delete(rl.visitors, ip)
				}
			}
			rl.mu.Unlock()
		}
	}
}

// Allow checks if a request from the given IP is allowed
// This method handles all visitor logic within a single lock to avoid race conditions
func (rl *RateLimiter) Allow(ip string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	v, exists := rl.visitors[ip]
	if !exists {
		v = &visitor{
			tokens:    rl.rate,
			lastReset: time.Now(),
		}
		rl.visitors[ip] = v
	}

	// Reset tokens if window has passed
	if time.Since(v.lastReset) > rl.window {
		v.tokens = rl.rate
		v.lastReset = time.Now()
	}

	if v.tokens > 0 {
		v.tokens--
		return true
	}
	return false
}

// Middleware returns a rate limiting middleware handler
func (rl *RateLimiter) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ip := getClientIP(r)
		if !rl.Allow(ip) {
			respondError(w, http.StatusTooManyRequests, "rate_limited", "too many requests, please try again later")
			return
		}
		next.ServeHTTP(w, r)
	})
}

// getClientIP extracts the client IP from the request
func getClientIP(r *http.Request) string {
	// Check X-Forwarded-For header first (for proxied requests)
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		// Take the first IP in the list
		for i := 0; i < len(xff); i++ {
			if xff[i] == ',' {
				return xff[:i]
			}
		}
		return xff
	}

	// Check X-Real-IP header
	if xri := r.Header.Get("X-Real-IP"); xri != "" {
		return xri
	}

	// Fall back to RemoteAddr
	// Remove port if present
	addr := r.RemoteAddr
	for i := len(addr) - 1; i >= 0; i-- {
		if addr[i] == ':' {
			return addr[:i]
		}
	}
	return addr
}
