package api_test

import (
	"context"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/ZempTime/shortbread/cli/internal/api"
)

func TestReleaseClientRejectsInconsistentHistoryAndRollbackResults(t *testing.T) {
	for _, test := range []struct {
		name string
		body string
		call func(*api.Client) error
	}{
		{
			name: "history current marker",
			body: `{"site":{"slug":"first-site","current_release_number":2},"releases":[{"id":23,"number":2,"manifest_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","finalized_at":"2026-07-20T12:02:00Z","current":false,"files":1,"bytes":1}],"pagination":{"limit":1,"next_before":null}}`,
			call: func(client *api.Client) error {
				_, err := client.ListReleases(context.Background(), "first-site", 1, 0)
				return err
			},
		},
		{
			name: "history omits current Release",
			body: `{"site":{"slug":"first-site","current_release_number":2},"releases":[],"pagination":{"limit":1,"next_before":null}}`,
			call: func(client *api.Client) error {
				_, err := client.ListReleases(context.Background(), "first-site", 1, 0)
				return err
			},
		},
		{
			name: "history exposes Releases without a current pointer",
			body: `{"site":{"slug":"first-site","current_release_number":null},"releases":[{"id":23,"number":2,"manifest_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","finalized_at":"2026-07-20T12:02:00Z","current":false,"files":1,"bytes":1}],"pagination":{"limit":1,"next_before":null}}`,
			call: func(client *api.Client) error {
				_, err := client.ListReleases(context.Background(), "first-site", 1, 0)
				return err
			},
		},
		{
			name: "rollback changed marker",
			body: `{"rollback":{"id":31,"site_slug":"first-site","from_release_number":2,"to_release_number":1,"resulting_release_number":1,"changed":false,"recorded_at":"2026-07-20T12:03:00Z"}}`,
			call: func(client *api.Client) error {
				_, err := client.RollbackRelease(context.Background(), "first-site", 1, "synthetic-idempotency-key")
				return err
			},
		},
	} {
		t.Run(test.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
				response.Header().Set("Content-Type", "application/json")
				_, _ = io.WriteString(response, test.body)
			}))
			defer server.Close()

			client, err := api.New(server.URL, testEnvironment("TOKEN_MARKER"))
			if err != nil {
				t.Fatalf("New: %v", err)
			}
			if err := test.call(client); !errors.Is(err, api.ErrResponse) {
				t.Fatalf("error = %v, want ErrResponse", err)
			}
		})
	}
}
