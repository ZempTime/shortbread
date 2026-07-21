package command_test

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync/atomic"
	"testing"

	"github.com/ZempTime/shortbread/cli/internal/command"
)

func TestPublishScansPlansUploadsAndFinalizesOneHTMLFile(t *testing.T) {
	directory := t.TempDir()
	content := []byte("<h1>PRIVATE_BODY_MARKER</h1>")
	if err := os.WriteFile(filepath.Join(directory, "index.html"), content, 0o600); err != nil {
		t.Fatal("write Bundle")
	}
	digest := sha256.Sum256(content)
	digestHex := hex.EncodeToString(digest[:])
	randomBytes := bytes.Repeat([]byte{0x52}, 32)
	wantIdempotencyKey := base64.RawURLEncoding.EncodeToString(randomBytes)
	token := "TOKEN_MARKER"
	requests := 0
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		requests++
		if request.Header.Get("Authorization") != "Bearer "+token {
			t.Fatal("publish request omitted the producer bearer")
		}
		switch requests {
		case 1:
			if request.Method != http.MethodPost || request.URL.Path != "/api/v1/sites/first-site/publish-plans" {
				t.Fatalf("plan request = %s %s", request.Method, request.URL.Path)
			}
			if request.Header.Get("Idempotency-Key") != wantIdempotencyKey {
				t.Fatal("plan request omitted the generated idempotency key")
			}
			body, err := io.ReadAll(request.Body)
			if err != nil {
				t.Fatal("read plan request")
			}
			if strings.Contains(string(body), directory) || strings.Contains(string(body), string(content)) {
				t.Fatal("plan request exposed a local path or Bundle body")
			}
			var decoded struct {
				Manifest struct {
					Entries []map[string]any `json:"entries"`
				} `json:"manifest"`
			}
			if err := json.Unmarshal(body, &decoded); err != nil || len(decoded.Manifest.Entries) != 1 {
				t.Fatal("plan request did not contain one Manifest Entry")
			}
			entry := decoded.Manifest.Entries[0]
			if entry["path"] != "index.html" || entry["sha256"] != digestHex || entry["size"] != float64(len(content)) || entry["content_type"] != "text/html" || entry["offline_policy"] != "required" {
				t.Fatalf("Manifest Entry = %#v", entry)
			}
			response.Header().Set("Content-Type", "application/json")
			response.WriteHeader(http.StatusCreated)
			_, _ = io.WriteString(response, `{"publish_plan":{"id":19,"state":"open","delta":{"added":1,"changed":0,"reused":0,"removed":0},"uploads":[{"sha256":"`+digestHex+`","size":`+strconv.Itoa(len(content))+`,"method":"PUT","url":"/api/v1/publish-plans/19/blobs/`+digestHex+`","headers":{"Content-Type":"application/octet-stream"}}],"finalize_url":"/api/v1/publish-plans/19/finalize"}}`)
		case 2:
			if request.Method != http.MethodPut || request.URL.Path != "/api/v1/publish-plans/19/blobs/"+digestHex {
				t.Fatalf("upload request = %s %s", request.Method, request.URL.Path)
			}
			body, err := io.ReadAll(request.Body)
			if err != nil || !bytes.Equal(body, content) {
				t.Fatal("upload request did not contain exact Blob bytes")
			}
			response.WriteHeader(http.StatusNoContent)
		case 3:
			if request.Method != http.MethodPost || request.URL.Path != "/api/v1/publish-plans/19/finalize" {
				t.Fatalf("finalize request = %s %s", request.Method, request.URL.Path)
			}
			response.Header().Set("Content-Type", "application/json")
			response.WriteHeader(http.StatusCreated)
			_, _ = io.WriteString(response, `{"release":{"id":23,"site_slug":"first-site","number":1,"manifest_sha256":"`+strings.Repeat("f", 64)+`"}}`)
		default:
			t.Fatal("publish made an unexpected network request")
		}
	}))
	defer server.Close()

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	runtime := command.Runtime{
		Version: "test-version",
		LookupEnv: func(name string) (string, bool) {
			if name == "SHORTBREAD_TOKEN" {
				return token, true
			}
			return "", false
		},
		Random: bytes.NewReader(randomBytes),
		Stdout: &stdout,
		Stderr: &stderr,
	}
	args := []string{"--server", server.URL, "--json", "publish", directory, "--site", "first-site"}
	if exitCode := command.Execute(context.Background(), args, runtime); exitCode != 0 {
		t.Fatalf("Execute exit code = %d, want 0; requests=%d stdout=%q stderr=%q", exitCode, requests, stdout.String(), stderr.String())
	}
	if requests != 3 {
		t.Fatalf("network requests = %d, want plan/upload/finalize", requests)
	}
	wantOutput := "{\"ok\":true,\"result\":{\"resource\":\"release\",\"id\":23,\"status\":\"published\",\"number\":1,\"files\":1,\"uploaded\":1,\"added\":1,\"changed\":0,\"reused\":0,\"removed\":0,\"bytes\":" + strconv.Itoa(len(content)) + "}}\n"
	if stdout.String() != wantOutput || stderr.Len() != 0 {
		t.Fatalf("output = %q / %q, want fixed success JSON", stdout.String(), stderr.String())
	}
	for _, marker := range []string{directory, string(content), token, wantIdempotencyKey, server.URL} {
		if strings.Contains(stdout.String()+stderr.String(), marker) {
			t.Fatal("publish output exposed private request material")
		}
	}
}

func TestPublishRejectsUnsafeBundleBeforeRandomnessOrNetwork(t *testing.T) {
	for _, test := range []struct {
		name  string
		build func(t *testing.T, directory string)
	}{
		{name: "symlink", build: func(t *testing.T, directory string) {
			outside := filepath.Join(t.TempDir(), "PRIVATE_OUTSIDE_MARKER")
			if err := os.WriteFile(outside, []byte("private"), 0o600); err != nil {
				t.Fatal("write outside file")
			}
			if err := os.Symlink(outside, filepath.Join(directory, "linked.html")); err != nil {
				t.Skipf("symlinks unavailable: %v", err)
			}
		}},
		{name: "reserved", build: func(t *testing.T, directory string) {
			if err := os.Mkdir(filepath.Join(directory, "_shortbread"), 0o700); err != nil {
				t.Fatal("create reserved directory")
			}
			if err := os.WriteFile(filepath.Join(directory, "_shortbread", "session"), []byte("private"), 0o600); err != nil {
				t.Fatal("write reserved file")
			}
		}},
		{name: "secret-like", build: func(t *testing.T, directory string) {
			if err := os.WriteFile(filepath.Join(directory, ".env"), []byte("PRIVATE_SECRET_MARKER"), 0o600); err != nil {
				t.Fatal("write secret-like file")
			}
		}},
	} {
		t.Run(test.name, func(t *testing.T) {
			directory := t.TempDir()
			if err := os.WriteFile(filepath.Join(directory, "index.html"), []byte("<h1>safe</h1>"), 0o600); err != nil {
				t.Fatal("write index")
			}
			test.build(t, directory)
			var requests atomic.Int32
			server := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
				requests.Add(1)
			}))
			defer server.Close()
			random := &countingReader{reader: bytes.NewReader(bytes.Repeat([]byte{1}, 32))}
			var stdout bytes.Buffer
			var stderr bytes.Buffer
			runtime := command.Runtime{
				Version: "test-version",
				LookupEnv: func(name string) (string, bool) {
					if name == "SHORTBREAD_TOKEN" {
						return "TOKEN_MARKER", true
					}
					return "", false
				},
				Random: random,
				Stdout: &stdout,
				Stderr: &stderr,
			}
			args := []string{"--server", server.URL, "--json", "publish", directory, "--site", "first-site"}
			if exitCode := command.Execute(context.Background(), args, runtime); exitCode != 2 {
				t.Fatalf("Execute exit code = %d, want invalid input", exitCode)
			}
			if got, want := stdout.String(), "{\"ok\":false,\"error\":{\"code\":\"invalid_input\"}}\n"; got != want || stderr.Len() != 0 {
				t.Fatalf("output = %q / %q, want fixed invalid-input JSON", got, stderr.String())
			}
			if requests.Load() != 0 || random.reads != 0 {
				t.Fatal("unsafe Bundle reached randomness or network")
			}
			for _, marker := range []string{directory, server.URL, "PRIVATE_OUTSIDE_MARKER", "PRIVATE_SECRET_MARKER", "TOKEN_MARKER"} {
				if strings.Contains(stdout.String()+stderr.String(), marker) {
					t.Fatal("unsafe-Bundle output exposed private material")
				}
			}
		})
	}
}

func TestPublishSkipsAReusableBlobAndStillFinalizes(t *testing.T) {
	directory := t.TempDir()
	content := []byte("<h1>already present</h1>")
	if err := os.WriteFile(filepath.Join(directory, "index.html"), content, 0o600); err != nil {
		t.Fatal("write Bundle")
	}
	requests := 0
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		requests++
		response.Header().Set("Content-Type", "application/json")
		switch requests {
		case 1:
			if request.Method != http.MethodPost || request.URL.Path != "/api/v1/sites/first-site/publish-plans" {
				t.Fatal("first request was not the publish plan")
			}
			response.WriteHeader(http.StatusCreated)
			_, _ = io.WriteString(response, `{"publish_plan":{"id":19,"state":"open","delta":{"added":0,"changed":0,"reused":1,"removed":0},"uploads":[],"finalize_url":"/api/v1/publish-plans/19/finalize"}}`)
		case 2:
			if request.Method != http.MethodPost || request.URL.Path != "/api/v1/publish-plans/19/finalize" {
				t.Fatal("reusable Blob caused an upload request")
			}
			response.WriteHeader(http.StatusCreated)
			_, _ = io.WriteString(response, `{"release":{"id":23,"site_slug":"first-site","number":2,"manifest_sha256":"`+strings.Repeat("f", 64)+`"}}`)
		default:
			t.Fatal("publish made an unexpected request")
		}
	}))
	defer server.Close()
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	runtime := command.Runtime{
		Version: "test-version",
		LookupEnv: func(name string) (string, bool) {
			if name == "SHORTBREAD_TOKEN" {
				return "synthetic-test-bearer", true
			}
			return "", false
		},
		Random: bytes.NewReader(bytes.Repeat([]byte{4}, 32)),
		Stdout: &stdout,
		Stderr: &stderr,
	}
	args := []string{"--server", server.URL, "--json", "publish", directory, "--site", "first-site"}
	if exitCode := command.Execute(context.Background(), args, runtime); exitCode != 0 {
		t.Fatalf("Execute exit code = %d; output=%q/%q", exitCode, stdout.String(), stderr.String())
	}
	want := "{\"ok\":true,\"result\":{\"resource\":\"release\",\"id\":23,\"status\":\"published\",\"number\":2,\"files\":1,\"uploaded\":0,\"added\":0,\"changed\":0,\"reused\":1,\"removed\":0,\"bytes\":" + strconv.Itoa(len(content)) + "}}\n"
	if requests != 2 || stdout.String() != want || stderr.Len() != 0 {
		t.Fatalf("result = requests:%d %q/%q, want missing-only finalize", requests, stdout.String(), stderr.String())
	}
}

func TestPublishFailsClosedIfAFileChangesAfterPlanning(t *testing.T) {
	directory := t.TempDir()
	path := filepath.Join(directory, "index.html")
	original := []byte("<h1>original private body</h1>")
	if err := os.WriteFile(path, original, 0o600); err != nil {
		t.Fatal("write Bundle")
	}
	digest := sha256.Sum256(original)
	digestHex := hex.EncodeToString(digest[:])
	requests := 0
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
		requests++
		if requests != 1 {
			t.Fatal("changed Bundle file reached upload or finalize")
		}
		if err := os.WriteFile(path, []byte("PRIVATE_CHANGED_MARKER"), 0o600); err != nil {
			t.Fatal("change Bundle after plan")
		}
		response.Header().Set("Content-Type", "application/json")
		response.WriteHeader(http.StatusCreated)
		_, _ = io.WriteString(response, `{"publish_plan":{"id":19,"state":"open","delta":{"added":1,"changed":0,"reused":0,"removed":0},"uploads":[{"sha256":"`+digestHex+`","size":`+strconv.Itoa(len(original))+`,"method":"PUT","url":"/api/v1/publish-plans/19/blobs/`+digestHex+`","headers":{"Content-Type":"application/octet-stream"}}],"finalize_url":"/api/v1/publish-plans/19/finalize"}}`)
	}))
	defer server.Close()
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	runtime := command.Runtime{
		Version: "test-version",
		LookupEnv: func(name string) (string, bool) {
			if name == "SHORTBREAD_TOKEN" {
				return "TOKEN_MARKER", true
			}
			return "", false
		},
		Random: bytes.NewReader(bytes.Repeat([]byte{5}, 32)),
		Stdout: &stdout,
		Stderr: &stderr,
	}
	args := []string{"--server", server.URL, "--json", "publish", directory, "--site", "first-site"}
	if exitCode := command.Execute(context.Background(), args, runtime); exitCode != 2 {
		t.Fatalf("Execute exit code = %d, want fail-closed invalid input", exitCode)
	}
	if requests != 1 || stdout.String() != "{\"ok\":false,\"error\":{\"code\":\"invalid_input\"}}\n" || stderr.Len() != 0 {
		t.Fatalf("result = requests:%d %q/%q", requests, stdout.String(), stderr.String())
	}
	for _, marker := range []string{directory, string(original), "PRIVATE_CHANGED_MARKER", "TOKEN_MARKER", server.URL} {
		if strings.Contains(stdout.String()+stderr.String(), marker) {
			t.Fatal("changed-file failure exposed private material")
		}
	}
}

func TestPublishReusesDurableOperationKeyAfterAnAmbiguousFinalize(t *testing.T) {
	directory := t.TempDir()
	content := []byte("<h1>retry</h1>")
	if err := os.WriteFile(filepath.Join(directory, "index.html"), content, 0o600); err != nil {
		t.Fatal("write Bundle")
	}
	stateDir := t.TempDir()
	randomBytes := bytes.Repeat([]byte{0x44}, 32)
	wantKey := base64.RawURLEncoding.EncodeToString(randomBytes)
	requests := 0
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		requests++
		if request.Header.Get("Idempotency-Key") != "" && request.Header.Get("Idempotency-Key") != wantKey {
			t.Fatal("publish changed its operation key")
		}
		response.Header().Set("Content-Type", "application/json")
		switch requests {
		case 1:
			response.WriteHeader(http.StatusCreated)
			_, _ = io.WriteString(response, `{"publish_plan":{"id":19,"state":"open","delta":{"added":1,"changed":0,"reused":0,"removed":0},"uploads":[],"finalize_url":"/api/v1/publish-plans/19/finalize"}}`)
		case 2:
			response.WriteHeader(http.StatusInternalServerError)
		case 3:
			response.WriteHeader(http.StatusOK)
			_, _ = io.WriteString(response, `{"publish_plan":{"id":19,"state":"finalized","delta":{"added":1,"changed":0,"reused":0,"removed":0},"uploads":[],"finalize_url":"/api/v1/publish-plans/19/finalize"}}`)
		case 4:
			response.WriteHeader(http.StatusOK)
			_, _ = io.WriteString(response, `{"release":{"id":23,"site_slug":"first-site","number":1,"manifest_sha256":"`+strings.Repeat("f", 64)+`"}}`)
		default:
			t.Fatal("unexpected retry request")
		}
	}))
	defer server.Close()

	lookup := func(name string) (string, bool) {
		switch name {
		case "SHORTBREAD_TOKEN":
			return "TOKEN_MARKER", true
		case "SHORTBREAD_STATE_DIR":
			return stateDir, true
		default:
			return "", false
		}
	}
	args := []string{"--server", server.URL, "--json", "publish", directory, "--site", "first-site"}
	firstOut := &bytes.Buffer{}
	if exit := command.Execute(context.Background(), args, command.Runtime{LookupEnv: lookup, Random: bytes.NewReader(randomBytes), Stdout: firstOut}); exit != 4 {
		t.Fatalf("first exit = %d, want ambiguous request failure", exit)
	}
	secondOut := &bytes.Buffer{}
	if exit := command.Execute(context.Background(), args, command.Runtime{LookupEnv: lookup, Random: strings.NewReader(""), Stdout: secondOut}); exit != 0 {
		t.Fatalf("retry exit = %d, output=%q", exit, secondOut.String())
	}
	if requests != 4 || !strings.Contains(secondOut.String(), `"number":1`) {
		t.Fatalf("retry evidence requests=%d output=%q", requests, secondOut.String())
	}
}
