package api

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/noted/server/internal/config"
	"github.com/noted/server/internal/storage"
	"github.com/noted/server/internal/store"
)

// Server holds all dependencies for the HTTP server
type Server struct {
	router    *chi.Mux
	store     store.Store
	config    *config.Config
	blobStore storage.BlobStore
}

// NewServer creates a new API server
func NewServer(s store.Store, cfg *config.Config, blobStore storage.BlobStore) *Server {
	srv := &Server{
		router:    chi.NewRouter(),
		store:     s,
		config:    cfg,
		blobStore: blobStore,
	}
	srv.setupRoutes()
	return srv
}

// ServeHTTP implements http.Handler
func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	s.router.ServeHTTP(w, r)
}

func (s *Server) setupRoutes() {
	r := s.router

	// Middleware
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.RequestID)
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   s.config.AllowedOrigins,
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	// Health check
	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	// API routes
	r.Route("/api", func(r chi.Router) {
		// Public image access (supports signed URLs OR JWT auth)
		r.Get("/images/{id}", s.handleGetImage)

		// Auth routes (public)
		r.Route("/auth", func(r chi.Router) {
			r.Post("/register", s.handleRegister)
			r.Post("/login", s.handleLogin)
			r.Post("/refresh", s.handleRefresh)

			// Protected auth routes
			r.Group(func(r chi.Router) {
				r.Use(s.authMiddleware)
				r.Get("/me", s.handleGetMe)
			})
		})

		// Protected routes
		r.Group(func(r chi.Router) {
			r.Use(s.authMiddleware)

			// Notebooks
			r.Route("/notebooks", func(r chi.Router) {
				r.Get("/", s.handleListNotebooks)
				r.Post("/", s.handleCreateNotebook)
				r.Get("/{id}", s.handleGetNotebook)
				r.Put("/{id}", s.handleUpdateNotebook)
				r.Delete("/{id}", s.handleDeleteNotebook)

				// Notes within a notebook
				r.Get("/{id}/notes", s.handleListNotes)
				r.Post("/{id}/notes", s.handleCreateNote)
			})

			// Notes
			r.Route("/notes", func(r chi.Router) {
				r.Get("/{id}", s.handleGetNote)
				r.Put("/{id}", s.handleUpdateNote)
				r.Delete("/{id}", s.handleDeleteNote)
			})

			// Tags
			r.Route("/tags", func(r chi.Router) {
				r.Get("/", s.handleListTags)
				r.Post("/", s.handleCreateTag)
				r.Get("/{id}", s.handleGetTag)
				r.Put("/{id}", s.handleUpdateTag)
				r.Delete("/{id}", s.handleDeleteTag)
			})

			// Images (upload and URL refresh require auth)
			r.Route("/images", func(r chi.Router) {
				r.Post("/", s.handleUploadImage)
				r.Get("/{id}/url", s.handleGetImageURL)
			})

			// Note images
			r.Get("/notes/{noteId}/images", s.handleListNoteImages)

			// Search
			r.Get("/search", s.handleSearch)

			// Sync
			r.Get("/sync", s.handleSyncGet)
			r.Post("/sync", s.handleSyncPost)
		})
	})
}
