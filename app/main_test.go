package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func get(path string) *httptest.ResponseRecorder {
	rec := httptest.NewRecorder()
	newMux().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
	return rec
}

func TestHealth(t *testing.T) {
	t.Setenv("API_KEY", "test")
	if rec := get("/health"); rec.Code != http.StatusOK {
		t.Fatalf("got %d, want 200", rec.Code)
	}
}

func TestTramiteExists(t *testing.T) {
	if rec := get("/v1/tramites/TRM-000001"); rec.Code != http.StatusOK {
		t.Fatalf("got %d, want 200", rec.Code)
	}
}

func TestTramiteNotFound(t *testing.T) {
	if rec := get("/v1/tramites/TRM-999999"); rec.Code != http.StatusNotFound {
		t.Fatalf("got %d, want 404", rec.Code)
	}
}
