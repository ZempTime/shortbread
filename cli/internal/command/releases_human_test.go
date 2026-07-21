package command_test

import (
	"bytes"
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/ZempTime/shortbread/cli/internal/command"
)

func TestReleasesListWritesUsefulHumanOutput(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
		response.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(response, `{"site":{"slug":"first-site","current_release_number":2},"releases":[{"id":23,"number":2,"manifest_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","finalized_at":"2026-07-20T12:02:00.000000Z","current":true,"files":2,"bytes":12}],"pagination":{"limit":1,"next_before":2}}`)
	}))
	defer server.Close()

	stdout, stderr, runtime := releaseRuntime(bytes.NewReader(nil))
	args := []string{"--server", server.URL, "releases", "list", "--site", "first-site", "--limit", "1"}
	if exitCode := command.Execute(context.Background(), args, runtime); exitCode != 0 {
		t.Fatalf("exit = %d, output=%q/%q", exitCode, stdout.String(), stderr.String())
	}
	want := "Site first-site current Release: 2.\n* Release 2; 2 files, 12 bytes; finalized 2026-07-20T12:02:00.000000Z.\nMore Releases: use --before 2.\n"
	if stdout.String() != want || stderr.Len() != 0 {
		t.Fatalf("output = %q / %q", stdout.String(), stderr.String())
	}
}

func TestReleasesRollbackWritesUsefulNoOpHumanOutput(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
		response.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(response, `{"rollback":{"id":31,"site_slug":"first-site","from_release_number":1,"to_release_number":1,"resulting_release_number":1,"changed":false,"recorded_at":"2026-07-20T12:03:00.000000Z"}}`)
	}))
	defer server.Close()

	stdout, stderr, runtime := releaseRuntime(bytes.NewReader(bytes.Repeat([]byte{0x31}, 32)))
	args := []string{"--server", server.URL, "releases", "rollback", "--site", "first-site", "--release", "1"}
	if exitCode := command.Execute(context.Background(), args, runtime); exitCode != 0 {
		t.Fatalf("exit = %d, output=%q/%q", exitCode, stdout.String(), stderr.String())
	}
	want := "Release 1 is already current for Site first-site.\n"
	if stdout.String() != want || stderr.Len() != 0 {
		t.Fatalf("output = %q / %q", stdout.String(), stderr.String())
	}
}
