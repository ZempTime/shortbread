package api_test

import (
	"context"
	"encoding/base64"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/ZempTime/shortbread/cli/internal/api"
)

func TestClientListsABoundedReleasePageAndValidatesCurrentState(t *testing.T) {
	token := "TOKEN_MARKER"
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodGet || request.URL.Path != "/api/v1/sites/first-site/releases" || request.URL.RawQuery != "before=3&limit=1" {
			t.Fatalf("request = %s %s?%s", request.Method, request.URL.Path, request.URL.RawQuery)
		}
		if request.Header.Get("Authorization") != "Bearer "+token {
			t.Fatal("history request omitted the producer bearer")
		}
		response.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(response, `{"site":{"slug":"first-site","current_release_number":2},"releases":[{"id":23,"number":2,"manifest_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","finalized_at":"2026-07-20T12:02:00.000000Z","current":true,"files":2,"bytes":12}],"pagination":{"limit":1,"next_before":2}}`)
	}))
	defer server.Close()

	client, err := api.New(server.URL, testEnvironment(token))
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	history, err := client.ListReleases(context.Background(), "first-site", 1, 3)
	if err != nil {
		t.Fatalf("ListReleases: %v", err)
	}
	if history.Site.Slug != "first-site" || history.Site.CurrentReleaseNumber == nil || *history.Site.CurrentReleaseNumber != 2 {
		t.Fatalf("Site history = %#v", history.Site)
	}
	if len(history.Releases) != 1 || history.Releases[0].Number != 2 || !history.Releases[0].Current {
		t.Fatalf("Releases = %#v", history.Releases)
	}
	if history.Pagination.Limit != 1 || history.Pagination.NextBefore == nil || *history.Pagination.NextBefore != 2 {
		t.Fatalf("Pagination = %#v", history.Pagination)
	}
}

func TestClientRollsBackWithAHeaderOnlyIdempotencyKeyAndValidatesTheResult(t *testing.T) {
	token := "TOKEN_MARKER"
	key := base64.RawURLEncoding.EncodeToString(make([]byte, 32))
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPost || request.URL.Path != "/api/v1/sites/first-site/releases/1/rollback" {
			t.Fatalf("request = %s %s", request.Method, request.URL.Path)
		}
		if request.Header.Get("Authorization") != "Bearer "+token || request.Header.Get("Idempotency-Key") != key {
			t.Fatal("rollback request omitted exact authorization/idempotency headers")
		}
		body, err := io.ReadAll(request.Body)
		if err != nil || string(body) != "{}" {
			t.Fatalf("rollback body = %q", body)
		}
		response.Header().Set("Content-Type", "application/json")
		response.WriteHeader(http.StatusCreated)
		_, _ = io.WriteString(response, `{"rollback":{"id":31,"site_slug":"first-site","from_release_number":2,"to_release_number":1,"resulting_release_number":1,"changed":true,"recorded_at":"2026-07-20T12:03:00.000000Z"}}`)
	}))
	defer server.Close()

	client, err := api.New(server.URL, testEnvironment(token))
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	rollback, err := client.RollbackRelease(context.Background(), "first-site", 1, key)
	if err != nil {
		t.Fatalf("RollbackRelease: %v", err)
	}
	if rollback.ID != 31 || rollback.FromReleaseNumber != 2 || rollback.ToReleaseNumber != 1 || rollback.ResultingReleaseNumber != 1 || !rollback.Changed {
		t.Fatalf("Rollback = %#v", rollback)
	}
}

func TestReleaseClientRefusesRedirectsAndRedactsRejectedBodies(t *testing.T) {
	destinationRequests := 0
	destination := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		destinationRequests++
	}))
	defer destination.Close()
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		if request.URL.Path == "/api/v1/sites/first-site/releases" {
			http.Redirect(response, request, destination.URL+"/PRIVATE_REDIRECT_MARKER", http.StatusFound)
			return
		}
		response.WriteHeader(http.StatusUnprocessableEntity)
		_, _ = io.WriteString(response, `{"error":{"detail":"PRIVATE_RESPONSE_MARKER"}}`)
	}))
	defer server.Close()

	client, err := api.New(server.URL, testEnvironment("TOKEN_MARKER"))
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	_, err = client.ListReleases(context.Background(), "first-site", 50, 0)
	if !errors.Is(err, api.ErrRejected) || destinationRequests != 0 {
		t.Fatalf("redirect result = %v, requests=%d", err, destinationRequests)
	}
}
