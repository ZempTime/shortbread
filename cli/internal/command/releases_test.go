package command_test

import (
	"bytes"
	"context"
	"encoding/base64"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/ZempTime/shortbread/cli/internal/command"
)

func TestReleasesListWritesStableBoundedJSON(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodGet || request.URL.Path != "/api/v1/sites/first-site/releases" || request.URL.RawQuery != "before=3&limit=1" {
			t.Fatalf("request = %s %s?%s", request.Method, request.URL.Path, request.URL.RawQuery)
		}
		response.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(response, `{"site":{"slug":"first-site","current_release_number":2},"releases":[{"id":23,"number":2,"manifest_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","finalized_at":"2026-07-20T12:02:00.000000Z","current":true,"files":2,"bytes":12}],"pagination":{"limit":1,"next_before":2}}`)
	}))
	defer server.Close()

	stdout, stderr, runtime := releaseRuntime(strings.NewReader("unused"))
	args := []string{"--server", server.URL, "--json", "releases", "list", "--site", "first-site", "--limit", "1", "--before", "3"}
	if exitCode := command.Execute(context.Background(), args, runtime); exitCode != 0 {
		t.Fatalf("exit = %d, output=%q/%q", exitCode, stdout.String(), stderr.String())
	}
	want := "{\"ok\":true,\"result\":{\"resource\":\"release_history\",\"site_slug\":\"first-site\",\"current_release_number\":2,\"releases\":[{\"id\":23,\"number\":2,\"manifest_sha256\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"finalized_at\":\"2026-07-20T12:02:00.000000Z\",\"current\":true,\"files\":2,\"bytes\":12}],\"pagination\":{\"limit\":1,\"next_before\":2}}}\n"
	if stdout.String() != want || stderr.Len() != 0 {
		t.Fatalf("output = %q / %q", stdout.String(), stderr.String())
	}
}

func TestReleasesRollbackGeneratesASecretKeyAndWritesStableJSON(t *testing.T) {
	randomBytes := bytes.Repeat([]byte{0x31}, 32)
	wantKey := base64.RawURLEncoding.EncodeToString(randomBytes)
	token := "TOKEN_MARKER"
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPost || request.URL.Path != "/api/v1/sites/first-site/releases/1/rollback" {
			t.Fatalf("request = %s %s", request.Method, request.URL.Path)
		}
		if request.Header.Get("Idempotency-Key") != wantKey {
			t.Fatal("rollback omitted its generated idempotency key")
		}
		response.Header().Set("Content-Type", "application/json")
		response.WriteHeader(http.StatusCreated)
		_, _ = io.WriteString(response, `{"rollback":{"id":31,"site_slug":"first-site","from_release_number":2,"to_release_number":1,"resulting_release_number":1,"changed":true,"recorded_at":"2026-07-20T12:03:00.000000Z"}}`)
	}))
	defer server.Close()

	stdout, stderr, runtime := releaseRuntime(bytes.NewReader(randomBytes))
	args := []string{"--server", server.URL, "--json", "releases", "rollback", "--site", "first-site", "--release", "1"}
	if exitCode := command.Execute(context.Background(), args, runtime); exitCode != 0 {
		t.Fatalf("exit = %d, output=%q/%q", exitCode, stdout.String(), stderr.String())
	}
	want := "{\"ok\":true,\"result\":{\"resource\":\"release_rollback\",\"status\":\"rolled_back\",\"id\":31,\"site_slug\":\"first-site\",\"from_release_number\":2,\"to_release_number\":1,\"resulting_release_number\":1,\"changed\":true,\"recorded_at\":\"2026-07-20T12:03:00.000000Z\"}}\n"
	if stdout.String() != want || stderr.Len() != 0 {
		t.Fatalf("output = %q / %q", stdout.String(), stderr.String())
	}
	for _, marker := range []string{wantKey, token, server.URL} {
		if strings.Contains(stdout.String()+stderr.String(), marker) {
			t.Fatal("rollback output exposed request-only material")
		}
	}
}

func releaseRuntime(random io.Reader) (*bytes.Buffer, *bytes.Buffer, command.Runtime) {
	stdout := &bytes.Buffer{}
	stderr := &bytes.Buffer{}
	runtime := command.Runtime{
		Version: "test-version",
		LookupEnv: func(name string) (string, bool) {
			if name == "SHORTBREAD_TOKEN" {
				return "TOKEN_MARKER", true
			}
			return "", false
		},
		Random: random,
		Stdout: stdout,
		Stderr: stderr,
	}
	return stdout, stderr, runtime
}
