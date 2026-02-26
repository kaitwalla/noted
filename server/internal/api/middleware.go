package api

import (
	"context"
	"fmt"
	"net/http"
	"strings"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

type contextKey string

const (
	userIDKey contextKey = "userID"
)

// GetUserID extracts the user ID from context
func GetUserID(ctx context.Context) (uuid.UUID, bool) {
	id, ok := ctx.Value(userIDKey).(uuid.UUID)
	return id, ok
}

// authMiddleware validates JWT tokens and adds user ID to context
func (s *Server) authMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			respondError(w, http.StatusUnauthorized, "unauthorized", "missing authorization header")
			return
		}

		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			respondError(w, http.StatusUnauthorized, "unauthorized", "invalid authorization header format")
			return
		}

		tokenString := parts[1]
		claims := &Claims{}

		token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
			// Validate signing algorithm to prevent algorithm confusion attacks
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
			}
			return []byte(s.config.JWTSecret), nil
		})

		if err != nil || !token.Valid {
			respondError(w, http.StatusUnauthorized, "unauthorized", "invalid or expired token")
			return
		}

		if claims.TokenType != "access" {
			respondError(w, http.StatusUnauthorized, "unauthorized", "invalid token type")
			return
		}

		userID, err := uuid.Parse(claims.Subject)
		if err != nil {
			respondError(w, http.StatusUnauthorized, "unauthorized", "invalid user ID in token")
			return
		}

		ctx := context.WithValue(r.Context(), userIDKey, userID)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
