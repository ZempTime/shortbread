package command

import (
	"bytes"
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestInviteCreateMapsCommitFailureAndAborts(t *testing.T) {
	locator := strings.Repeat("l", 32)
	secret := base64.RawURLEncoding.EncodeToString(bytes.Repeat([]byte{3}, 32))
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
		response.Header().Set("Content-Type", "application/json")
		response.WriteHeader(http.StatusCreated)
		_, _ = fmt.Fprintf(response, `{"invitation":{"id":17,"locator":%q,"expires_at":%q,"status":"pending"}}`, locator, time.Now().Add(time.Hour).UTC().Format(time.RFC3339))
	}))
	defer server.Close()

	output := &commitFailingOutput{}
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	runtime := Runtime{
		Version: "test-version",
		LookupEnv: func(name string) (string, bool) {
			if name == "SHORTBREAD_TOKEN" {
				return "TOKEN_MARKER", true
			}
			return "", false
		},
		Random: bytes.NewReader(bytes.Repeat([]byte{3}, 32)),
		Stdout: &stdout,
		Stderr: &stderr,
	}
	deps := dependencies{
		reserve: func(path string) (privateOutput, error) {
			if path != "PRIVATE_PATH_MARKER" {
				t.Fatal("unexpected private path")
			}
			return output, nil
		},
	}
	args := []string{"--server", server.URL, "invite", "create", "--grant", "13", "--link-file", "PRIVATE_PATH_MARKER"}
	if exitCode := execute(context.Background(), args, runtime, deps); exitCode != 5 {
		t.Fatalf("execute exit code = %d, want 5", exitCode)
	}
	if stdout.Len() != 0 || stderr.String() != "private link could not be written\n" {
		t.Fatalf("output = %q / %q, want fixed private-output failure", stdout.String(), stderr.String())
	}
	if !output.aborted || output.committed == "" {
		t.Fatal("commit failure did not attempt commit and deferred abort")
	}
	for _, marker := range []string{"TOKEN_MARKER", "PRIVATE_PATH_MARKER", "COMMIT_ERROR_MARKER", secret, locator, server.URL} {
		if strings.Contains(stdout.String()+stderr.String(), marker) {
			t.Fatal("commit-failure output exposed private material")
		}
	}
}

type commitFailingOutput struct {
	aborted   bool
	committed string
}

func (output *commitFailingOutput) Commit(content []byte) error {
	output.committed = string(content)
	return errors.New("COMMIT_ERROR_MARKER")
}

func (output *commitFailingOutput) Abort() error {
	output.aborted = true
	return nil
}
