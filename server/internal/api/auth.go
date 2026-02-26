package api

import (
	"errors"
	"fmt"
	"net/http"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/noted/server/internal/models"
	"github.com/noted/server/internal/store"
	"golang.org/x/crypto/bcrypt"
)

// Claims represents JWT claims
type Claims struct {
	jwt.RegisteredClaims
	TokenType string `json:"type"`
}

func (s *Server) handleRegister(w http.ResponseWriter, r *http.Request) {
	var req models.CreateUserRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "invalid JSON body")
		return
	}

	if req.Email == "" || req.Password == "" {
		respondError(w, http.StatusBadRequest, "validation_error", "email and password are required")
		return
	}

	if len(req.Password) < 8 {
		respondError(w, http.StatusBadRequest, "validation_error", "password must be at least 8 characters")
		return
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "server_error", "failed to hash password")
		return
	}

	now := time.Now()
	user := &models.User{
		ID:           uuid.New(),
		Email:        req.Email,
		PasswordHash: string(hashedPassword),
		CreatedAt:    now,
		UpdatedAt:    now,
	}

	if err := s.store.CreateUser(r.Context(), user); err != nil {
		if errors.Is(err, store.ErrAlreadyExists) {
			respondError(w, http.StatusConflict, "conflict", "user with this email already exists")
			return
		}
		respondError(w, http.StatusInternalServerError, "server_error", "failed to create user")
		return
	}

	tokens, err := s.generateTokens(user.ID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "server_error", "failed to generate tokens")
		return
	}

	respondJSON(w, http.StatusCreated, models.AuthResponse{
		User:         user,
		AccessToken:  tokens.AccessToken,
		RefreshToken: tokens.RefreshToken,
	})
}

func (s *Server) handleLogin(w http.ResponseWriter, r *http.Request) {
	var req models.LoginRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "invalid JSON body")
		return
	}

	user, err := s.store.GetUserByEmail(r.Context(), req.Email)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			respondError(w, http.StatusUnauthorized, "unauthorized", "invalid email or password")
			return
		}
		respondError(w, http.StatusInternalServerError, "server_error", "failed to get user")
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		respondError(w, http.StatusUnauthorized, "unauthorized", "invalid email or password")
		return
	}

	tokens, err := s.generateTokens(user.ID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "server_error", "failed to generate tokens")
		return
	}

	respondJSON(w, http.StatusOK, models.AuthResponse{
		User:         user,
		AccessToken:  tokens.AccessToken,
		RefreshToken: tokens.RefreshToken,
	})
}

func (s *Server) handleRefresh(w http.ResponseWriter, r *http.Request) {
	var req struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, http.StatusBadRequest, "invalid_request", "invalid JSON body")
		return
	}

	claims := &Claims{}
	token, err := jwt.ParseWithClaims(req.RefreshToken, claims, func(token *jwt.Token) (interface{}, error) {
		// Validate signing algorithm to prevent algorithm confusion attacks
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(s.config.JWTSecret), nil
	})

	if err != nil || !token.Valid {
		respondError(w, http.StatusUnauthorized, "unauthorized", "invalid or expired refresh token")
		return
	}

	if claims.TokenType != "refresh" {
		respondError(w, http.StatusUnauthorized, "unauthorized", "invalid token type")
		return
	}

	userID, err := uuid.Parse(claims.Subject)
	if err != nil {
		respondError(w, http.StatusUnauthorized, "unauthorized", "invalid user ID in token")
		return
	}

	// Verify user still exists
	user, err := s.store.GetUserByID(r.Context(), userID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			respondError(w, http.StatusUnauthorized, "unauthorized", "user not found")
			return
		}
		respondError(w, http.StatusInternalServerError, "server_error", "failed to get user")
		return
	}

	tokens, err := s.generateTokens(user.ID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "server_error", "failed to generate tokens")
		return
	}

	respondJSON(w, http.StatusOK, models.AuthResponse{
		User:         user,
		AccessToken:  tokens.AccessToken,
		RefreshToken: tokens.RefreshToken,
	})
}

func (s *Server) handleGetMe(w http.ResponseWriter, r *http.Request) {
	userID, ok := GetUserID(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized", "user not found in context")
		return
	}

	user, err := s.store.GetUserByID(r.Context(), userID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			respondError(w, http.StatusNotFound, "not_found", "user not found")
			return
		}
		respondError(w, http.StatusInternalServerError, "server_error", "failed to get user")
		return
	}

	respondJSON(w, http.StatusOK, user)
}

type tokenPair struct {
	AccessToken  string
	RefreshToken string
}

func (s *Server) generateTokens(userID uuid.UUID) (*tokenPair, error) {
	now := time.Now()

	// Access token
	accessClaims := &Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID.String(),
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(s.config.JWTExpiration)),
		},
		TokenType: "access",
	}
	accessToken := jwt.NewWithClaims(jwt.SigningMethodHS256, accessClaims)
	accessTokenString, err := accessToken.SignedString([]byte(s.config.JWTSecret))
	if err != nil {
		return nil, err
	}

	// Refresh token
	refreshClaims := &Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID.String(),
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(s.config.RefreshExpiry)),
		},
		TokenType: "refresh",
	}
	refreshToken := jwt.NewWithClaims(jwt.SigningMethodHS256, refreshClaims)
	refreshTokenString, err := refreshToken.SignedString([]byte(s.config.JWTSecret))
	if err != nil {
		return nil, err
	}

	return &tokenPair{
		AccessToken:  accessTokenString,
		RefreshToken: refreshTokenString,
	}, nil
}
