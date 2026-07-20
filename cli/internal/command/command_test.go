package command_test

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/ZempTime/shortbread/cli/internal/command"
)

func TestHelpAndVersionNeedNoConfiguration(t *testing.T) {
	for _, test := range []struct {
		name       string
		args       []string
		wantOutput string
	}{
		{name: "help", args: []string{"--help"}, wantOutput: "Publish private websites with Shortbread"},
		{name: "version", args: []string{"--version"}, wantOutput: "shortbread test-version\n"},
	} {
		t.Run(test.name, func(t *testing.T) {
			var stdout bytes.Buffer
			var stderr bytes.Buffer
			runtime := command.Runtime{
				Version: "test-version",
				LookupEnv: func(string) (string, bool) {
					t.Fatal("offline command consulted the environment")
					return "", false
				},
				Random: strings.NewReader("unused"),
				Stdout: &stdout,
				Stderr: &stderr,
			}

			if exitCode := command.Execute(context.Background(), test.args, runtime); exitCode != 0 {
				t.Fatalf("Execute exit code = %d, want 0", exitCode)
			}
			if !strings.Contains(stdout.String(), test.wantOutput) {
				t.Fatalf("stdout = %q, want it to contain %q", stdout.String(), test.wantOutput)
			}
			if stderr.Len() != 0 {
				t.Fatalf("stderr = %q, want empty", stderr.String())
			}
		})
	}
}

func TestSitesCreateJSONUsesSafeStableOutput(t *testing.T) {
	token := "TOKEN_MARKER"
	slug := "SLUG_MARKER"
	name := "NAME_MARKER"
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPost || request.URL.Path != "/api/v1/sites" {
			t.Errorf("request = %s %s, want POST /api/v1/sites", request.Method, request.URL.Path)
		}
		if request.Header.Get("Authorization") != "Bearer "+token {
			t.Error("request did not carry the environment bearer")
		}
		var body map[string]any
		if err := json.NewDecoder(request.Body).Decode(&body); err != nil {
			t.Error("decode Site request")
		}
		if body["slug"] != slug || body["name"] != name || len(body) != 2 {
			t.Errorf("Site request body = %#v", body)
		}
		response.Header().Set("Content-Type", "application/json")
		response.WriteHeader(http.StatusCreated)
		_, _ = io.WriteString(response, `{"site":{"id":7,"slug":"SLUG_MARKER","name":"NAME_MARKER"}}`)
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
		Random: strings.NewReader("unused"),
		Stdout: &stdout,
		Stderr: &stderr,
	}
	args := []string{"--server", server.URL, "--json", "sites", "create", "--slug", slug, "--name", name}
	if exitCode := command.Execute(context.Background(), args, runtime); exitCode != 0 {
		t.Fatalf("Execute exit code = %d, want 0; stderr=%q", exitCode, stderr.String())
	}
	if got, want := stdout.String(), "{\"ok\":true,\"result\":{\"resource\":\"site\",\"id\":7,\"status\":\"created\"}}\n"; got != want {
		t.Fatalf("stdout = %q, want %q", got, want)
	}
	if stderr.Len() != 0 {
		t.Fatalf("stderr = %q, want empty", stderr.String())
	}
	for _, marker := range []string{token, slug, name, server.URL} {
		if strings.Contains(stdout.String()+stderr.String(), marker) {
			t.Fatalf("command output exposed a supplied marker")
		}
	}
}

func TestPeopleAddUsesSafeHumanOutput(t *testing.T) {
	token := "TOKEN_MARKER"
	firstName := "FIRST_NAME_MARKER"
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPost || request.URL.Path != "/api/v1/people" {
			t.Errorf("request = %s %s, want POST /api/v1/people", request.Method, request.URL.Path)
		}
		if request.Header.Get("Authorization") != "Bearer "+token {
			t.Error("request did not carry the environment bearer")
		}
		var body map[string]any
		if err := json.NewDecoder(request.Body).Decode(&body); err != nil {
			t.Error("decode Person request")
		}
		if body["first_name"] != firstName || len(body) != 1 {
			t.Errorf("Person request body = %#v", body)
		}
		response.Header().Set("Content-Type", "application/json")
		response.WriteHeader(http.StatusCreated)
		_, _ = io.WriteString(response, `{"person":{"id":11,"first_name":"FIRST_NAME_MARKER"}}`)
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
		Random: strings.NewReader("unused"),
		Stdout: &stdout,
		Stderr: &stderr,
	}
	args := []string{"--server", server.URL, "people", "add", "--first-name", firstName}
	if exitCode := command.Execute(context.Background(), args, runtime); exitCode != 0 {
		t.Fatalf("Execute exit code = %d, want 0; stderr=%q", exitCode, stderr.String())
	}
	if got, want := stdout.String(), "Person 11 created.\n"; got != want {
		t.Fatalf("stdout = %q, want %q", got, want)
	}
	if stderr.Len() != 0 {
		t.Fatalf("stderr = %q, want empty", stderr.String())
	}
	for _, marker := range []string{token, firstName, server.URL} {
		if strings.Contains(stdout.String()+stderr.String(), marker) {
			t.Fatal("command output exposed a supplied marker")
		}
	}
}

func TestAccessGrantUsesSafeHumanOutput(t *testing.T) {
	token := "TOKEN_MARKER"
	slug := "SLUG_MARKER"
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPost || request.URL.Path != "/api/v1/grants" {
			t.Errorf("request = %s %s, want POST /api/v1/grants", request.Method, request.URL.Path)
		}
		if request.Header.Get("Authorization") != "Bearer "+token {
			t.Error("request did not carry the environment bearer")
		}
		var body map[string]any
		if err := json.NewDecoder(request.Body).Decode(&body); err != nil {
			t.Error("decode Grant request")
		}
		if body["site_slug"] != slug || body["person_id"] != float64(11) || len(body) != 2 {
			t.Errorf("Grant request body = %#v", body)
		}
		response.Header().Set("Content-Type", "application/json")
		response.WriteHeader(http.StatusCreated)
		_, _ = io.WriteString(response, `{"grant":{"id":13,"site_slug":"SLUG_MARKER","person_id":11}}`)
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
		Random: strings.NewReader("unused"),
		Stdout: &stdout,
		Stderr: &stderr,
	}
	args := []string{"--server", server.URL, "access", "grant", "--site", slug, "--person", "11"}
	if exitCode := command.Execute(context.Background(), args, runtime); exitCode != 0 {
		t.Fatalf("Execute exit code = %d, want 0; stderr=%q", exitCode, stderr.String())
	}
	if got, want := stdout.String(), "Grant 13 created.\n"; got != want {
		t.Fatalf("stdout = %q, want %q", got, want)
	}
	if stderr.Len() != 0 {
		t.Fatalf("stderr = %q, want empty", stderr.String())
	}
	for _, marker := range []string{token, slug, server.URL} {
		if strings.Contains(stdout.String()+stderr.String(), marker) {
			t.Fatal("command output exposed a supplied marker")
		}
	}
}

func TestInvalidInputJSONIsStableWhenParsingStopsBeforeJSONFlag(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	runtime := command.Runtime{
		Version: "test-version",
		LookupEnv: func(string) (string, bool) {
			t.Fatal("invalid input must fail before configuration")
			return "", false
		},
		Random: strings.NewReader("unused"),
		Stdout: &stdout,
		Stderr: &stderr,
	}
	args := []string{"access", "grant", "--site", "SITE_MARKER", "--person", "RAW_INPUT_MARKER", "--json"}
	if exitCode := command.Execute(context.Background(), args, runtime); exitCode != 2 {
		t.Fatalf("Execute exit code = %d, want 2", exitCode)
	}
	if got, want := stdout.String(), "{\"ok\":false,\"error\":{\"code\":\"invalid_input\"}}\n"; got != want {
		t.Fatalf("stdout = %q, want %q", got, want)
	}
	if stderr.Len() != 0 {
		t.Fatalf("stderr = %q, want empty", stderr.String())
	}
	if strings.Contains(stdout.String()+stderr.String(), "RAW_INPUT_MARKER") || strings.Contains(stdout.String()+stderr.String(), "SITE_MARKER") {
		t.Fatal("invalid-input output exposed supplied values")
	}
}

func TestConfigurationFailureJSONIsFixedAndRedacted(t *testing.T) {
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
		Random: strings.NewReader("unused"),
		Stdout: &stdout,
		Stderr: &stderr,
	}
	args := []string{"--json", "--server", "http://NON_LOOPBACK_SERVER_MARKER.invalid", "sites", "create", "--slug", "SLUG_MARKER", "--name", "NAME_MARKER"}
	if exitCode := command.Execute(context.Background(), args, runtime); exitCode != 3 {
		t.Fatalf("Execute exit code = %d, want 3", exitCode)
	}
	if got, want := stdout.String(), "{\"ok\":false,\"error\":{\"code\":\"configuration_failed\"}}\n"; got != want {
		t.Fatalf("stdout = %q, want %q", got, want)
	}
	if stderr.Len() != 0 {
		t.Fatalf("stderr = %q, want empty", stderr.String())
	}
	for _, marker := range []string{"TOKEN_MARKER", "NON_LOOPBACK_SERVER_MARKER", "SLUG_MARKER", "NAME_MARKER"} {
		if strings.Contains(stdout.String()+stderr.String(), marker) {
			t.Fatal("configuration output exposed a supplied marker")
		}
	}
}

func TestRequestFailureHumanOutputIsFixedAndRedacted(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
		response.WriteHeader(http.StatusUnprocessableEntity)
		_, _ = io.WriteString(response, `{"error":{"detail":"RESPONSE_BODY_MARKER"}}`)
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
		Random: strings.NewReader("unused"),
		Stdout: &stdout,
		Stderr: &stderr,
	}
	args := []string{"--server", server.URL, "sites", "create", "--slug", "SLUG_MARKER", "--name", "NAME_MARKER"}
	if exitCode := command.Execute(context.Background(), args, runtime); exitCode != 4 {
		t.Fatalf("Execute exit code = %d, want 4", exitCode)
	}
	if stdout.Len() != 0 {
		t.Fatalf("stdout = %q, want empty", stdout.String())
	}
	if got, want := stderr.String(), "Shortbread request failed\n"; got != want {
		t.Fatalf("stderr = %q, want %q", got, want)
	}
	for _, marker := range []string{"TOKEN_MARKER", "RESPONSE_BODY_MARKER", "SLUG_MARKER", "NAME_MARKER", server.URL} {
		if strings.Contains(stdout.String()+stderr.String(), marker) {
			t.Fatal("request output exposed a supplied marker")
		}
	}
}

func TestInviteCreateWritesPrivateFragmentLinkAndSafeJSON(t *testing.T) {
	directory := t.TempDir()
	linkPath := filepath.Join(directory, "PRIVATE_PATH_MARKER")
	token := "TOKEN_MARKER"
	randomBytes := bytes.Repeat([]byte{0x42}, 32)
	secret := base64.RawURLEncoding.EncodeToString(randomBytes)
	digest := sha256.Sum256([]byte(secret))
	digestHex := hex.EncodeToString(digest[:])
	locator := strings.Repeat("l", 32)
	expiresAt := time.Now().Add(time.Hour).UTC().Format(time.RFC3339)

	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		info, err := os.Stat(linkPath)
		if err != nil {
			t.Fatal("private sink was not reserved before network request")
		}
		if info.Mode().Perm() != 0o600 || info.Size() != 0 {
			t.Errorf("reserved sink mode/size = %o/%d, want 600/0", info.Mode().Perm(), info.Size())
		}
		if request.Method != http.MethodPost || request.URL.Path != "/api/v1/grants/13/invitations" {
			t.Errorf("request = %s %s, want Invitation create", request.Method, request.URL.Path)
		}
		if request.Header.Get("Authorization") != "Bearer "+token {
			t.Error("request did not carry the environment bearer")
		}
		body, err := io.ReadAll(request.Body)
		if err != nil {
			t.Error("read Invitation request")
		}
		if strings.Contains(string(body), secret) || strings.Contains(request.URL.String(), secret) {
			t.Fatal("Invitation request exposed the raw secret")
		}
		var decoded map[string]any
		if err := json.Unmarshal(body, &decoded); err != nil {
			t.Error("decode Invitation request")
		}
		if decoded["secret_digest"] != digestHex || len(decoded) != 1 {
			t.Errorf("Invitation request body = %#v, want digest only", decoded)
		}
		response.Header().Set("Content-Type", "application/json")
		response.WriteHeader(http.StatusCreated)
		_, _ = fmt.Fprintf(response, `{"invitation":{"id":17,"locator":%q,"expires_at":%q,"status":"pending"}}`, locator, expiresAt)
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
	args := []string{"--server", server.URL, "--json", "invite", "create", "--grant", "13", "--link-file", linkPath}
	if exitCode := command.Execute(context.Background(), args, runtime); exitCode != 0 {
		t.Fatalf("Execute exit code = %d, want 0; stderr=%q", exitCode, stderr.String())
	}
	if got, want := stdout.String(), "{\"ok\":true,\"result\":{\"resource\":\"invitation\",\"id\":17,\"status\":\"created\",\"link_written\":true}}\n"; got != want {
		t.Fatalf("stdout = %q, want %q", got, want)
	}
	if stderr.Len() != 0 {
		t.Fatalf("stderr = %q, want empty", stderr.String())
	}
	link, err := os.ReadFile(linkPath)
	if err != nil {
		t.Fatal("read private link sink")
	}
	if got, want := string(link), server.URL+"/invitations/"+locator+"#"+secret; got != want {
		t.Fatal("private sink did not contain the exact fragment link")
	}
	info, err := os.Stat(linkPath)
	if err != nil || info.Mode().Perm() != 0o600 {
		t.Fatal("committed private sink is not mode 0600")
	}
	for _, marker := range []string{token, secret, locator, linkPath, server.URL} {
		if strings.Contains(stdout.String()+stderr.String(), marker) {
			t.Fatal("command output exposed private Invitation material")
		}
	}
}

func TestInviteCreateRejectsInvalidSinksBeforeRandomAndNetwork(t *testing.T) {
	for _, test := range []struct {
		name string
		path func(t *testing.T) string
	}{
		{name: "existing", path: func(t *testing.T) string {
			path := filepath.Join(t.TempDir(), "PRIVATE_PATH_MARKER")
			if err := os.WriteFile(path, []byte("ORIGINAL_CONTENT_MARKER"), 0o640); err != nil {
				t.Fatal("create existing sink")
			}
			return path
		}},
		{name: "dash", path: func(*testing.T) string { return "-" }},
	} {
		t.Run(test.name, func(t *testing.T) {
			var networkRequests atomic.Int32
			server := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
				networkRequests.Add(1)
			}))
			defer server.Close()
			path := test.path(t)
			random := &countingReader{reader: bytes.NewReader(bytes.Repeat([]byte{1}, 32))}
			stdout, stderr, exitCode := executeInvite(t, server.URL, path, random, true)
			if exitCode != 5 || stdout != "{\"ok\":false,\"error\":{\"code\":\"private_output_failed\"}}\n" || stderr != "" {
				t.Fatalf("result = %d, %q, %q; want fixed JSON private-output failure", exitCode, stdout, stderr)
			}
			if random.reads != 0 || networkRequests.Load() != 0 {
				t.Fatal("invalid sink allowed random or network activity")
			}
			if test.name == "existing" {
				content, err := os.ReadFile(path)
				if err != nil || string(content) != "ORIGINAL_CONTENT_MARKER" {
					t.Fatal("existing sink was changed")
				}
			}
			for _, marker := range []string{path, server.URL, "ORIGINAL_CONTENT_MARKER", "TOKEN_MARKER"} {
				if marker != "-" && strings.Contains(stdout+stderr, marker) {
					t.Fatal("invalid-sink output exposed private material")
				}
			}
		})
	}
}

func TestInviteCreateAbortsReservationWhenRandomFails(t *testing.T) {
	var networkRequests atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		networkRequests.Add(1)
	}))
	defer server.Close()
	path := filepath.Join(t.TempDir(), "PRIVATE_PATH_MARKER")
	stdout, stderr, exitCode := executeInvite(t, server.URL, path, strings.NewReader("short"), false)
	if exitCode != 5 || stdout != "" || stderr != "private link could not be written\n" {
		t.Fatalf("result = %d, %q, %q; want fixed private-output failure", exitCode, stdout, stderr)
	}
	if networkRequests.Load() != 0 {
		t.Fatal("random failure allowed a network request")
	}
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Fatal("random failure left the reserved sink behind")
	}
	if strings.Contains(stdout+stderr, path) || strings.Contains(stdout+stderr, server.URL) {
		t.Fatal("random-failure output exposed private material")
	}
}

func TestInviteCreateAbortsReservationOnRequestOrLocatorFailure(t *testing.T) {
	for _, test := range []struct {
		name       string
		statusCode int
		body       func() string
	}{
		{name: "request rejected", statusCode: http.StatusUnprocessableEntity, body: func() string { return `{"error":{"detail":"RESPONSE_BODY_MARKER"}}` }},
		{name: "invalid locator", statusCode: http.StatusCreated, body: func() string {
			return fmt.Sprintf(`{"invitation":{"id":17,"locator":"LOCATOR_MARKER","expires_at":%q,"status":"pending"}}`, time.Now().Add(time.Hour).UTC().Format(time.RFC3339))
		}},
	} {
		t.Run(test.name, func(t *testing.T) {
			var networkRequests atomic.Int32
			server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
				networkRequests.Add(1)
				response.WriteHeader(test.statusCode)
				_, _ = io.WriteString(response, test.body())
			}))
			defer server.Close()
			path := filepath.Join(t.TempDir(), "PRIVATE_PATH_MARKER")
			stdout, stderr, exitCode := executeInvite(t, server.URL, path, bytes.NewReader(bytes.Repeat([]byte{2}, 32)), false)
			if exitCode != 4 || stdout != "" || stderr != "Shortbread request failed\n" {
				t.Fatalf("result = %d, %q, %q; want fixed request failure", exitCode, stdout, stderr)
			}
			if networkRequests.Load() != 1 {
				t.Fatalf("network requests = %d, want 1", networkRequests.Load())
			}
			if _, err := os.Stat(path); !os.IsNotExist(err) {
				t.Fatal("request failure left the reserved sink behind")
			}
			for _, marker := range []string{path, server.URL, "RESPONSE_BODY_MARKER", "LOCATOR_MARKER", "TOKEN_MARKER"} {
				if strings.Contains(stdout+stderr, marker) {
					t.Fatal("request-failure output exposed private material")
				}
			}
		})
	}
}

type countingReader struct {
	reader io.Reader
	reads  int
}

func (reader *countingReader) Read(buffer []byte) (int, error) {
	reader.reads++
	return reader.reader.Read(buffer)
}

func executeInvite(t *testing.T, server, path string, random io.Reader, jsonOutput bool) (string, string, int) {
	t.Helper()
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
	args := []string{"--server", server}
	if jsonOutput {
		args = append(args, "--json")
	}
	args = append(args, "invite", "create", "--grant", "13", "--link-file", path)
	exitCode := command.Execute(context.Background(), args, runtime)
	return stdout.String(), stderr.String(), exitCode
}
