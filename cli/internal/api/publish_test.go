package api_test

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"

	"github.com/ZempTime/shortbread/cli/internal/api"
)

func TestClientPlansOneFilePublishWithoutSendingLocalPathOrBody(t *testing.T) {
	token := "TOKEN_MARKER"
	idempotencyKey := "IDEMPOTENCY_MARKER"
	digest := strings.Repeat("a", 64)
	entry := api.ManifestEntry{
		Path:          "index.html",
		SHA256:        digest,
		Size:          31,
		ContentType:   "text/html",
		OfflinePolicy: "required",
	}
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPost || request.URL.Path != "/api/v1/sites/first-site/publish-plans" {
			t.Errorf("request = %s %s, want publish plan POST", request.Method, request.URL.Path)
		}
		if request.Header.Get("Authorization") != "Bearer "+token || request.Header.Get("Idempotency-Key") != idempotencyKey {
			t.Error("publish plan request did not carry exact authorization/idempotency headers")
		}
		body, err := io.ReadAll(request.Body)
		if err != nil {
			t.Fatal("read publish plan body")
		}
		for _, marker := range []string{"PRIVATE_LOCAL_PATH_MARKER", "PRIVATE_BODY_MARKER", token, idempotencyKey} {
			if strings.Contains(string(body), marker) {
				t.Fatal("publish plan body exposed private or header-only material")
			}
		}
		var decoded map[string]any
		if err := json.Unmarshal(body, &decoded); err != nil {
			t.Fatal("decode publish plan request")
		}
		want := map[string]any{"manifest": map[string]any{"entries": []any{map[string]any{
			"path": "index.html", "sha256": digest, "size": float64(31), "content_type": "text/html", "offline_policy": "required",
		}}}}
		if !reflect.DeepEqual(decoded, want) {
			t.Errorf("publish plan body = %#v, want exact Manifest", decoded)
		}
		response.Header().Set("Content-Type", "application/json")
		response.WriteHeader(http.StatusCreated)
		_, _ = io.WriteString(response, `{"publish_plan":{"id":19,"state":"open","uploads":[{"sha256":"`+digest+`","size":31,"method":"PUT","url":"/api/v1/publish-plans/19/blobs/`+digest+`","headers":{"Content-Type":"application/octet-stream"}}],"finalize_url":"/api/v1/publish-plans/19/finalize"}}`)
	}))
	defer server.Close()

	client, err := api.New(server.URL, testEnvironment(token))
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	plan, err := client.CreatePublishPlan(context.Background(), "first-site", idempotencyKey, []api.ManifestEntry{entry})
	if err != nil {
		t.Fatalf("CreatePublishPlan: %v", err)
	}
	if plan.ID != 19 || plan.State != "open" || plan.FinalizeURL != "/api/v1/publish-plans/19/finalize" || len(plan.Uploads) != 1 {
		t.Fatalf("PublishPlan = %#v", plan)
	}
	if plan.Uploads[0].SHA256 != digest || plan.Uploads[0].Size != 31 {
		t.Fatalf("Upload = %#v", plan.Uploads[0])
	}
}

func TestClientUploadsTheExactMissingBlobToTheLocalAdapter(t *testing.T) {
	token := "TOKEN_MARKER"
	content := "PRIVATE_BODY_MARKER"
	digest := strings.Repeat("b", 64)
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPut || request.URL.Path != "/api/v1/publish-plans/19/blobs/"+digest {
			t.Errorf("request = %s %s, want exact Blob PUT", request.Method, request.URL.Path)
		}
		if request.Header.Get("Authorization") != "Bearer "+token {
			t.Error("same-origin local Blob upload omitted authorization")
		}
		if request.Header.Get("Content-Type") != "application/octet-stream" || request.ContentLength != int64(len(content)) {
			t.Error("Blob upload omitted the declared content metadata")
		}
		body, err := io.ReadAll(request.Body)
		if err != nil || string(body) != content {
			t.Fatal("Blob upload did not carry the exact body")
		}
		response.WriteHeader(http.StatusNoContent)
	}))
	defer server.Close()

	client, err := api.New(server.URL, testEnvironment(token))
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	upload := api.PublishUpload{
		SHA256: digest,
		Size:   int64(len(content)),
		Method: http.MethodPut,
		URL:    "/api/v1/publish-plans/19/blobs/" + digest,
		Headers: map[string]string{
			"Content-Type": "application/octet-stream",
		},
	}
	if err := client.UploadBlob(context.Background(), upload, strings.NewReader(content)); err != nil {
		t.Fatalf("UploadBlob: %v", err)
	}
}

func TestClientNeverLeaksProducerAuthorizationToAnAbsoluteUploadOrigin(t *testing.T) {
	token := "TOKEN_MARKER"
	content := "PRIVATE_BODY_MARKER"
	digest := strings.Repeat("c", 64)
	uploadServer := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		if request.Header.Get("Authorization") != "" || request.Header.Get("Cookie") != "" {
			t.Fatal("cross-origin upload received producer credentials")
		}
		body, err := io.ReadAll(request.Body)
		if err != nil || string(body) != content {
			t.Fatal("cross-origin upload did not receive exact Blob bytes")
		}
		response.WriteHeader(http.StatusNoContent)
	}))
	defer uploadServer.Close()
	controlServer := httptest.NewServer(http.NotFoundHandler())
	defer controlServer.Close()

	client, err := api.New(controlServer.URL, testEnvironment(token))
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	upload := api.PublishUpload{
		SHA256: digest,
		Size:   int64(len(content)),
		Method: http.MethodPut,
		URL:    uploadServer.URL + "/private-presigned-object?synthetic=signature",
		Headers: map[string]string{
			"Content-Type": "application/octet-stream",
		},
	}
	if err := client.UploadBlob(context.Background(), upload, strings.NewReader(content)); err != nil {
		t.Fatalf("UploadBlob: %v", err)
	}
}

func TestClientAllowsDigitLeadingSiteSlugsWhenPlanning(t *testing.T) {
	digest := strings.Repeat("d", 64)
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		if request.URL.Path != "/api/v1/sites/1-site/publish-plans" {
			t.Errorf("request path = %q, want digit-leading Site slug", request.URL.Path)
		}
		response.Header().Set("Content-Type", "application/json")
		response.WriteHeader(http.StatusCreated)
		_, _ = io.WriteString(response, `{"publish_plan":{"id":19,"state":"open","uploads":[],"finalize_url":"/api/v1/publish-plans/19/finalize"}}`)
	}))
	defer server.Close()
	client, err := api.New(server.URL, testEnvironment("synthetic-test-bearer"))
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	entry := api.ManifestEntry{Path: "index.html", SHA256: digest, Size: 1, ContentType: "text/html", OfflinePolicy: "required"}
	if _, err := client.CreatePublishPlan(context.Background(), "1-site", "synthetic-idempotency", []api.ManifestEntry{entry}); err != nil {
		t.Fatalf("CreatePublishPlan: %v", err)
	}
}

func TestClientFinalizesTheExactPlanAndValidatesReleaseIdentity(t *testing.T) {
	token := "TOKEN_MARKER"
	manifestDigest := strings.Repeat("e", 64)
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPost || request.URL.Path != "/api/v1/publish-plans/19/finalize" {
			t.Errorf("request = %s %s, want exact finalize POST", request.Method, request.URL.Path)
		}
		if request.Header.Get("Authorization") != "Bearer "+token {
			t.Fatal("finalize request omitted producer authorization")
		}
		response.Header().Set("Content-Type", "application/json")
		response.WriteHeader(http.StatusCreated)
		_, _ = io.WriteString(response, `{"release":{"id":23,"site_slug":"first-site","number":1,"manifest_sha256":"`+manifestDigest+`"}}`)
	}))
	defer server.Close()

	client, err := api.New(server.URL, testEnvironment(token))
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	plan := api.PublishPlan{ID: 19, State: "open", FinalizeURL: "/api/v1/publish-plans/19/finalize"}
	release, err := client.FinalizePublishPlan(context.Background(), plan, "first-site")
	if err != nil {
		t.Fatalf("FinalizePublishPlan: %v", err)
	}
	if release.ID != 23 || release.SiteSlug != "first-site" || release.Number != 1 || release.ManifestSHA256 != manifestDigest {
		t.Fatalf("Release = %#v", release)
	}
}

func TestClientRejectsAnUnexpectedRelativeUploadTargetInThePlan(t *testing.T) {
	digest := strings.Repeat("a", 64)
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
		response.Header().Set("Content-Type", "application/json")
		response.WriteHeader(http.StatusCreated)
		_, _ = io.WriteString(response, `{"publish_plan":{"id":19,"state":"open","uploads":[{"sha256":"`+digest+`","size":1,"method":"PUT","url":"/api/v1/people","headers":{"Content-Type":"application/octet-stream"}}],"finalize_url":"/api/v1/publish-plans/19/finalize"},"private":"RESPONSE_MARKER"}`)
	}))
	defer server.Close()
	client, err := api.New(server.URL, testEnvironment("synthetic-test-bearer"))
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	entry := api.ManifestEntry{Path: "index.html", SHA256: digest, Size: 1, ContentType: "text/html", OfflinePolicy: "required"}
	_, err = client.CreatePublishPlan(context.Background(), "first-site", "synthetic-idempotency", []api.ManifestEntry{entry})
	if !errors.Is(err, api.ErrResponse) {
		t.Fatalf("CreatePublishPlan error = %v, want ErrResponse", err)
	}
	if strings.Contains(err.Error(), "RESPONSE_MARKER") || strings.Contains(err.Error(), server.URL) {
		t.Fatal("invalid upload target error exposed response material")
	}
}
