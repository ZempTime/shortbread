package command_test

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/ZempTime/shortbread/cli/internal/command"
)

const feedbackThreadJSON = `{"site":{"slug":"first-site"},"comments":[` +
	`{"id":11,"release_number":2,"path":"index.html","quote":"ships behind a flag","placement":"exact","confidence":1.0,"body":"Which flag is this?","person":"Avery","created_at":"2026-07-25T12:00:00.000000Z"},` +
	`{"id":12,"release_number":1,"path":"chapter-2.html","quote":"capped at three attempts","placement":"orphaned","confidence":0.0,"body":"Why three?","person":"Blair","created_at":"2026-07-25T12:05:00.000000Z"},` +
	`{"id":13,"release_number":2,"path":null,"quote":null,"placement":"unanchored","confidence":null,"body":"Looks good overall.","person":"Avery","created_at":"2026-07-25T12:10:00.000000Z"}]}`

func feedbackServer(t *testing.T, body string) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		if request.URL.Path != "/api/v1/sites/first-site/feedback" {
			response.WriteHeader(http.StatusNotFound)
			return
		}
		response.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(response, body)
	}))
}

func TestFeedbackPullWritesHumanOutputWithQuoteAndPlacement(t *testing.T) {
	server := feedbackServer(t, feedbackThreadJSON)
	defer server.Close()

	stdout, stderr, runtime := releaseRuntime(bytes.NewReader(nil))
	args := []string{"--server", server.URL, "feedback", "pull", "--site", "first-site"}
	if exitCode := command.Execute(context.Background(), args, runtime); exitCode != 0 {
		t.Fatalf("exit = %d, output=%q/%q", exitCode, stdout.String(), stderr.String())
	}

	output := stdout.String()
	for _, want := range []string{
		"Avery",
		"Which flag is this?",
		"ships behind a flag",
		"Release 2",
		"index.html",
		"Blair",
		"Why three?",
		"orphaned",
		"Looks good overall.",
	} {
		if !strings.Contains(output, want) {
			t.Fatalf("human output missing %q; got %q", want, output)
		}
	}
	if stderr.Len() != 0 {
		t.Fatalf("stderr = %q", stderr.String())
	}
}

func TestFeedbackPullJSONCarriesEveryRequiredField(t *testing.T) {
	server := feedbackServer(t, feedbackThreadJSON)
	defer server.Close()

	stdout, stderr, runtime := releaseRuntime(bytes.NewReader(nil))
	args := []string{"--server", server.URL, "--json", "feedback", "pull", "--site", "first-site"}
	if exitCode := command.Execute(context.Background(), args, runtime); exitCode != 0 {
		t.Fatalf("exit = %d, output=%q/%q", exitCode, stdout.String(), stderr.String())
	}

	var envelope struct {
		OK     bool `json:"ok"`
		Result struct {
			Resource string `json:"resource"`
			SiteSlug string `json:"site_slug"`
			Comments []struct {
				ID            int64   `json:"id"`
				ReleaseNumber int64   `json:"release_number"`
				Path          *string `json:"path"`
				Quote         *string `json:"quote"`
				Placement     string  `json:"placement"`
				Body          string  `json:"body"`
				Person        string  `json:"person"`
				CreatedAt     string  `json:"created_at"`
			} `json:"comments"`
		} `json:"result"`
	}
	if err := json.Unmarshal(stdout.Bytes(), &envelope); err != nil {
		t.Fatalf("decode: %v; output=%q", err, stdout.String())
	}
	if !envelope.OK || envelope.Result.SiteSlug != "first-site" || len(envelope.Result.Comments) != 3 {
		t.Fatalf("envelope = %+v", envelope)
	}

	first := envelope.Result.Comments[0]
	if first.ID != 11 || first.ReleaseNumber != 2 || first.Placement != "exact" ||
		first.Body != "Which flag is this?" || first.Person != "Avery" || first.CreatedAt == "" {
		t.Fatalf("first comment = %+v", first)
	}
	if first.Path == nil || *first.Path != "index.html" || first.Quote == nil || *first.Quote != "ships behind a flag" {
		t.Fatalf("first comment lost its Anchor: %+v", first)
	}

	unanchored := envelope.Result.Comments[2]
	if unanchored.Path != nil || unanchored.Quote != nil || unanchored.Placement != "unanchored" {
		t.Fatalf("site-level comment = %+v", unanchored)
	}
	if stderr.Len() != 0 {
		t.Fatalf("stderr = %q", stderr.String())
	}
}

func TestFeedbackPullReportsAnEmptyThread(t *testing.T) {
	server := feedbackServer(t, `{"site":{"slug":"first-site"},"comments":[]}`)
	defer server.Close()

	stdout, stderr, runtime := releaseRuntime(bytes.NewReader(nil))
	args := []string{"--server", server.URL, "feedback", "pull", "--site", "first-site"}
	if exitCode := command.Execute(context.Background(), args, runtime); exitCode != 0 {
		t.Fatalf("exit = %d, output=%q/%q", exitCode, stdout.String(), stderr.String())
	}
	if !strings.Contains(stdout.String(), "no Comments") {
		t.Fatalf("output = %q", stdout.String())
	}
	if stderr.Len() != 0 {
		t.Fatalf("stderr = %q", stderr.String())
	}
}

func TestFeedbackPullRejectsAnInvalidSiteSlug(t *testing.T) {
	stdout, stderr, runtime := releaseRuntime(bytes.NewReader(nil))
	args := []string{"--server", "http://127.0.0.1:1", "feedback", "pull", "--site", "Not A Slug"}
	if exitCode := command.Execute(context.Background(), args, runtime); exitCode == 0 {
		t.Fatalf("invalid slug accepted; output=%q/%q", stdout.String(), stderr.String())
	}
}

func TestFeedbackPullFailsWhenTheServerRejectsTheRequest(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
		response.WriteHeader(http.StatusUnauthorized)
	}))
	defer server.Close()

	stdout, stderr, runtime := releaseRuntime(bytes.NewReader(nil))
	args := []string{"--server", server.URL, "feedback", "pull", "--site", "first-site"}
	if exitCode := command.Execute(context.Background(), args, runtime); exitCode == 0 {
		t.Fatalf("rejected request reported success; output=%q/%q", stdout.String(), stderr.String())
	}
}
