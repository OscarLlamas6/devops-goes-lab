package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
)

// version is injected at build time: -ldflags "-X main.version=<sha>"
var version = "dev"

// Mock data: in a real service this would come from a database.
var tramites = map[string]string{
	"TRM-000001": "RECIBIDO",
	"TRM-000002": "EN_REVISION",
	"TRM-000003": "APROBADO",
}

func respond(w http.ResponseWriter, r *http.Request, status int, body any) {
	log.Printf("%s %q -> %d", r.Method, r.URL.Path, status) // %q: no log injection via the URL
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

func newMux() *http.ServeMux {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		// Only reports whether the secret is set, never its value.
		respond(w, r, http.StatusOK, map[string]any{
			"status":            "Server running",
			"version":           version,
			"secret_configured": os.Getenv("API_KEY") != "",
		})
	})

	mux.HandleFunc("GET /v1/tramites/{numero}", func(w http.ResponseWriter, r *http.Request) {
		numero := r.PathValue("numero")
		estado, ok := tramites[numero]
		if !ok {
			respond(w, r, http.StatusNotFound, map[string]string{"error": "tramite not found"})
			return
		}
		respond(w, r, http.StatusOK, map[string]string{"numero": numero, "estado": estado})
	})

	return mux
}

func main() {
	if os.Getenv("API_KEY") == "" {
		log.Fatal("API_KEY is not set") // never print the value
	}
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	log.Printf("listening on :%s (version %s)", port, version)
	log.Fatal(http.ListenAndServe(":"+port, newMux()))
}
