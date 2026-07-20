package api_test

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/ZempTime/shortbread/cli/internal/api"
)

func TestClientUsesExplicitServerAndEnvironmentBearer(t *testing.T) {
	token := "synthetic-test-bearer"
	requestSeen := false
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		requestSeen = true
		if request.Method != http.MethodPost || request.URL.Path != "/api/v1/sites" {
			t.Errorf("request = %s %s, want POST /api/v1/sites", request.Method, request.URL.Path)
		}
		if request.Header.Get("Authorization") != "Bearer "+token {
			t.Error("request did not carry the environment bearer")
		}
		var body map[string]any
		if err := json.NewDecoder(request.Body).Decode(&body); err != nil {
			t.Errorf("decode request: %v", err)
		}
		want := map[string]any{"slug": "first-site", "name": "First Site"}
		if !reflect.DeepEqual(body, want) {
			t.Errorf("body = %#v, want %#v", body, want)
		}
		response.Header().Set("Content-Type", "application/json")
		response.WriteHeader(http.StatusCreated)
		_, _ = io.WriteString(response, `{"site":{"id":7,"slug":"first-site","name":"First Site"}}`)
	}))
	defer server.Close()

	client, err := api.New(server.URL, func(name string) (string, bool) {
		values := map[string]string{
			"SHORTBREAD_URL":   "https://ignored.example",
			"SHORTBREAD_TOKEN": token,
		}
		value, ok := values[name]
		return value, ok
	})
	if err != nil {
		t.Fatalf("New: %v", err)
	}

	site, err := client.CreateSite(context.Background(), "first-site", "First Site")
	if err != nil {
		t.Fatalf("CreateSite: %v", err)
	}
	if !requestSeen {
		t.Fatal("server did not receive the request")
	}
	if site.ID != 7 || site.Slug != "first-site" || site.Name != "First Site" {
		t.Fatalf("site = %#v", site)
	}
}

func TestClientAllowsHTTPOnlyForIPLoopbackOrValidReservedLocalhostNames(t *testing.T) {
	for _, server := range []string{
		"http://localhost:3000",
		"http://shortbread.localhost:3000",
		"http://walking-skeleton.sites.shortbread.localhost:3000",
		"http://127.0.0.1:3000",
		"http://[::1]:3000",
	} {
		if _, err := api.New(server, testEnvironment("synthetic-test-bearer")); err != nil {
			t.Errorf("New rejected a reserved loopback origin: %v", err)
		}
	}

	for _, server := range []string{
		"http://wrong.example:3000",
		"http://localhost.attacker.test:3000",
		"http://shortbread.localhost.attacker.test:3000",
		"http://evil-localhost:3000",
		"http://bad_host.localhost:3000",
		"http://-bad.localhost:3000",
		"http://.localhost:3000",
	} {
		if _, err := api.New(server, testEnvironment("synthetic-test-bearer")); !errors.Is(err, api.ErrInvalidServer) {
			t.Errorf("New error = %v, want ErrInvalidServer", err)
		}
	}
}

func TestClientConnectsReservedLocalhostNamesDirectlyToLoopback(t *testing.T) {
	token := "synthetic-test-bearer"
	expectedHost := ""
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		if request.Host != expectedHost {
			t.Errorf("request Host = %q, want reserved localhost authority", request.Host)
		}
		response.Header().Set("Content-Type", "application/json")
		response.WriteHeader(http.StatusCreated)
		_, _ = io.WriteString(response, `{"site":{"id":7,"slug":"first-site","name":"First Site"}}`)
	}))
	defer server.Close()

	_, port, err := net.SplitHostPort(server.Listener.Addr().String())
	if err != nil {
		t.Fatalf("listener address: %v", err)
	}
	expectedHost = "shortbread.localhost:" + port
	client, err := api.New("http://"+expectedHost, testEnvironment(token))
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	if _, err := client.CreateSite(context.Background(), "first-site", "First Site"); err != nil {
		t.Fatalf("CreateSite: %v", err)
	}
}

func TestClientRejectsMalformedSiteResponses(t *testing.T) {
	for _, test := range []struct {
		name string
		body string
	}{
		{name: "nonpositive ID", body: `{"site":{"id":0,"slug":"first-site","name":"First Site"},"private":"RESPONSE_MARKER"}`},
		{name: "mismatched slug", body: `{"site":{"id":7,"slug":"RESPONSE_MARKER","name":"First Site"}}`},
		{name: "mismatched name", body: `{"site":{"id":7,"slug":"first-site","name":"RESPONSE_MARKER"}}`},
		{name: "trailing JSON", body: `{"site":{"id":7,"slug":"first-site","name":"First Site"}} {"private":"RESPONSE_MARKER"}`},
	} {
		t.Run(test.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
				response.Header().Set("Content-Type", "application/json")
				response.WriteHeader(http.StatusCreated)
				_, _ = io.WriteString(response, test.body)
			}))
			defer server.Close()

			client, err := api.New(server.URL, testEnvironment("synthetic-test-bearer"))
			if err != nil {
				t.Fatalf("New: %v", err)
			}
			_, err = client.CreateSite(context.Background(), "first-site", "First Site")
			if !errors.Is(err, api.ErrResponse) {
				t.Fatalf("CreateSite error = %v, want ErrResponse", err)
			}
			if strings.Contains(err.Error(), "RESPONSE_MARKER") || strings.Contains(err.Error(), server.URL) {
				t.Fatal("malformed response error exposed body or URL")
			}
		})
	}
}

func TestClientRedactsRejectedResponseBody(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
		response.WriteHeader(http.StatusUnprocessableEntity)
		_, _ = io.WriteString(response, `{"error":{"detail":"PRIVATE_RESPONSE_MARKER"}}`)
	}))
	defer server.Close()

	client, err := api.New(server.URL, testEnvironment("synthetic-test-bearer"))
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	_, err = client.CreateSite(context.Background(), "first-site", "First Site")
	if !errors.Is(err, api.ErrRejected) {
		t.Fatalf("CreateSite error = %v, want fixed rejected-request error", err)
	}
	if strings.Contains(err.Error(), "PRIVATE_RESPONSE_MARKER") || strings.Contains(err.Error(), server.URL) {
		t.Fatal("error exposed the response body or request URL")
	}
}

func TestClientCreatesPerson(t *testing.T) {
	token := "synthetic-test-bearer"
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPost || request.URL.Path != "/api/v1/people" {
			t.Errorf("request = %s %s, want POST /api/v1/people", request.Method, request.URL.Path)
		}
		if request.Header.Get("Authorization") != "Bearer "+token {
			t.Error("request did not carry the environment bearer")
		}
		var body map[string]any
		if err := json.NewDecoder(request.Body).Decode(&body); err != nil {
			t.Errorf("decode request: %v", err)
		}
		want := map[string]any{"first_name": "Avery"}
		if !reflect.DeepEqual(body, want) {
			t.Errorf("body = %#v, want %#v", body, want)
		}
		response.Header().Set("Content-Type", "application/json")
		response.WriteHeader(http.StatusCreated)
		_, _ = io.WriteString(response, `{"person":{"id":11,"first_name":"Avery"}}`)
	}))
	defer server.Close()

	client, err := api.New(server.URL, testEnvironment(token))
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	person, err := client.CreatePerson(context.Background(), "Avery")
	if err != nil {
		t.Fatalf("CreatePerson: %v", err)
	}
	if person.ID != 11 || person.FirstName != "Avery" {
		t.Fatalf("person = %#v", person)
	}
}

func TestClientRejectsMalformedPersonResponses(t *testing.T) {
	for _, body := range []string{
		`{"person":{"id":0,"first_name":"Avery"},"private":"RESPONSE_MARKER"}`,
		`{"person":{"id":11,"first_name":"RESPONSE_MARKER"}}`,
	} {
		server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
			response.Header().Set("Content-Type", "application/json")
			response.WriteHeader(http.StatusCreated)
			_, _ = io.WriteString(response, body)
		}))

		client, err := api.New(server.URL, testEnvironment("synthetic-test-bearer"))
		if err != nil {
			t.Fatalf("New: %v", err)
		}
		_, err = client.CreatePerson(context.Background(), "Avery")
		if !errors.Is(err, api.ErrResponse) {
			t.Errorf("CreatePerson error = %v, want ErrResponse", err)
			server.Close()
			continue
		}
		if strings.Contains(err.Error(), "RESPONSE_MARKER") || strings.Contains(err.Error(), server.URL) {
			t.Error("malformed response error exposed body or URL")
		}
		server.Close()
	}
}

func TestClientCreatesGrant(t *testing.T) {
	token := "synthetic-test-bearer"
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPost || request.URL.Path != "/api/v1/grants" {
			t.Errorf("request = %s %s, want POST /api/v1/grants", request.Method, request.URL.Path)
		}
		if request.Header.Get("Authorization") != "Bearer "+token {
			t.Error("request did not carry the environment bearer")
		}
		var body map[string]any
		if err := json.NewDecoder(request.Body).Decode(&body); err != nil {
			t.Errorf("decode request: %v", err)
		}
		want := map[string]any{"site_slug": "first-site", "person_id": float64(11)}
		if !reflect.DeepEqual(body, want) {
			t.Errorf("body = %#v, want %#v", body, want)
		}
		response.Header().Set("Content-Type", "application/json")
		response.WriteHeader(http.StatusCreated)
		_, _ = io.WriteString(response, `{"grant":{"id":13,"site_slug":"first-site","person_id":11}}`)
	}))
	defer server.Close()

	client, err := api.New(server.URL, testEnvironment(token))
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	grant, err := client.CreateGrant(context.Background(), "first-site", 11)
	if err != nil {
		t.Fatalf("CreateGrant: %v", err)
	}
	if grant.ID != 13 || grant.SiteSlug != "first-site" || grant.PersonID != 11 {
		t.Fatalf("grant = %#v", grant)
	}
}

func TestClientRejectsMalformedGrantResponses(t *testing.T) {
	for _, test := range []struct {
		name string
		body string
	}{
		{name: "nonpositive ID", body: `{"grant":{"id":0,"site_slug":"first-site","person_id":11},"private":"RESPONSE_MARKER"}`},
		{name: "mismatched Site", body: `{"grant":{"id":13,"site_slug":"RESPONSE_MARKER","person_id":11}}`},
		{name: "mismatched Person", body: `{"grant":{"id":13,"site_slug":"first-site","person_id":12},"private":"RESPONSE_MARKER"}`},
	} {
		t.Run(test.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
				response.Header().Set("Content-Type", "application/json")
				response.WriteHeader(http.StatusCreated)
				_, _ = io.WriteString(response, test.body)
			}))
			defer server.Close()

			client, err := api.New(server.URL, testEnvironment("synthetic-test-bearer"))
			if err != nil {
				t.Fatalf("New: %v", err)
			}
			_, err = client.CreateGrant(context.Background(), "first-site", 11)
			if !errors.Is(err, api.ErrResponse) {
				t.Fatalf("CreateGrant error = %v, want ErrResponse", err)
			}
			if strings.Contains(err.Error(), "RESPONSE_MARKER") || strings.Contains(err.Error(), server.URL) {
				t.Fatal("malformed response error exposed body or URL")
			}
		})
	}
}

func TestClientCreatesInvitationWithDigestOnly(t *testing.T) {
	token := "synthetic-test-bearer"
	rawSecret := "RAW_SECRET_MARKER"
	digest := strings.Repeat("a", 64)
	locator := strings.Repeat("b", 32)
	expiresAt := time.Now().Add(time.Hour).UTC().Truncate(time.Second).Format(time.RFC3339)
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPost || request.URL.Path != "/api/v1/grants/13/invitations" {
			t.Errorf("request = %s %s, want POST /api/v1/grants/13/invitations", request.Method, request.URL.Path)
		}
		if request.Header.Get("Authorization") != "Bearer "+token {
			t.Error("request did not carry the environment bearer")
		}
		body, err := io.ReadAll(request.Body)
		if err != nil {
			t.Error("read request body")
		}
		if strings.Contains(string(body), rawSecret) || strings.Contains(request.URL.String(), rawSecret) {
			t.Fatal("request exposed the raw Invitation secret")
		}
		var decoded map[string]any
		if err := json.Unmarshal(body, &decoded); err != nil {
			t.Errorf("decode request: %v", err)
		}
		want := map[string]any{"secret_digest": digest}
		if !reflect.DeepEqual(decoded, want) {
			t.Errorf("body = %#v, want digest-only body", decoded)
		}
		response.Header().Set("Content-Type", "application/json")
		response.WriteHeader(http.StatusCreated)
		_, _ = fmt.Fprintf(response, `{"invitation":{"id":17,"locator":%q,"expires_at":%q,"status":"pending"}}`, locator, expiresAt)
	}))
	defer server.Close()

	client, err := api.New(server.URL, testEnvironment(token))
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	invitation, err := client.CreateInvitation(context.Background(), 13, digest)
	if err != nil {
		t.Fatalf("CreateInvitation: %v", err)
	}
	if invitation.ID != 17 || invitation.Locator != locator || invitation.ExpiresAt != expiresAt || invitation.Status != "pending" {
		t.Fatalf("invitation = %#v", invitation)
	}
}

func TestClientRejectsMalformedInvitationResponses(t *testing.T) {
	validLocator := strings.Repeat("b", 32)
	future := time.Now().Add(time.Hour).UTC().Format(time.RFC3339)
	past := time.Now().Add(-time.Hour).UTC().Format(time.RFC3339)
	for _, test := range []struct {
		name string
		body string
	}{
		{name: "nonpositive ID", body: fmt.Sprintf(`{"invitation":{"id":0,"locator":%q,"expires_at":%q,"status":"pending"},"private":"RESPONSE_MARKER"}`, validLocator, future)},
		{name: "short locator", body: fmt.Sprintf(`{"invitation":{"id":17,"locator":%q,"expires_at":%q,"status":"pending"},"private":"RESPONSE_MARKER"}`, strings.Repeat("b", 31), future)},
		{name: "non URL safe locator", body: fmt.Sprintf(`{"invitation":{"id":17,"locator":%q,"expires_at":%q,"status":"pending"},"private":"RESPONSE_MARKER"}`, strings.Repeat("b", 31)+"=", future)},
		{name: "nonpending status", body: fmt.Sprintf(`{"invitation":{"id":17,"locator":%q,"expires_at":%q,"status":"accepted"},"private":"RESPONSE_MARKER"}`, validLocator, future)},
		{name: "invalid expiry", body: fmt.Sprintf(`{"invitation":{"id":17,"locator":%q,"expires_at":"RESPONSE_MARKER","status":"pending"}}`, validLocator)},
		{name: "past expiry", body: fmt.Sprintf(`{"invitation":{"id":17,"locator":%q,"expires_at":%q,"status":"pending"},"private":"RESPONSE_MARKER"}`, validLocator, past)},
	} {
		t.Run(test.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
				response.Header().Set("Content-Type", "application/json")
				response.WriteHeader(http.StatusCreated)
				_, _ = io.WriteString(response, test.body)
			}))
			defer server.Close()

			client, err := api.New(server.URL, testEnvironment("synthetic-test-bearer"))
			if err != nil {
				t.Fatalf("New: %v", err)
			}
			_, err = client.CreateInvitation(context.Background(), 13, strings.Repeat("a", 64))
			if !errors.Is(err, api.ErrResponse) {
				t.Fatalf("CreateInvitation error = %v, want ErrResponse", err)
			}
			if strings.Contains(err.Error(), "RESPONSE_MARKER") || strings.Contains(err.Error(), server.URL) {
				t.Fatal("malformed response error exposed body or URL")
			}
		})
	}
}

func TestClientRedactsRejectedInvitationResponse(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
		response.WriteHeader(http.StatusUnprocessableEntity)
		_, _ = io.WriteString(response, `{"error":{"detail":"RAW_SECRET_MARKER"}}`)
	}))
	defer server.Close()

	client, err := api.New(server.URL, testEnvironment("synthetic-test-bearer"))
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	_, err = client.CreateInvitation(context.Background(), 13, strings.Repeat("a", 64))
	if !errors.Is(err, api.ErrRejected) {
		t.Fatalf("CreateInvitation error = %v, want ErrRejected", err)
	}
	if strings.Contains(err.Error(), "RAW_SECRET_MARKER") || strings.Contains(err.Error(), server.URL) {
		t.Fatal("error exposed the raw Invitation secret or request URL")
	}
}

func TestClientBuildsFragmentOnlyInvitationLinkOffline(t *testing.T) {
	client, err := api.New("https://shortbread.example", testEnvironment("synthetic-test-bearer"))
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	locator := strings.Repeat("l", 32)
	secret := strings.Repeat("s", 43)
	link, err := client.InvitationLink(locator, secret)
	if err != nil {
		t.Fatalf("InvitationLink: %v", err)
	}
	if got, want := link, "https://shortbread.example/invitations/"+locator+"#"+secret; got != want {
		t.Fatalf("InvitationLink = %q, want exact fragment-only link", got)
	}
}

func TestClientRejectsUnsafeInvitationLinkPartsWithoutDisclosure(t *testing.T) {
	client, err := api.New("https://shortbread.example", testEnvironment("synthetic-test-bearer"))
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	for _, test := range []struct {
		name    string
		locator string
		secret  string
	}{
		{name: "unsafe locator", locator: "LOCATOR_MARKER?" + strings.Repeat("l", 17), secret: strings.Repeat("SYNTHETIC_MARKER", 3)[:43]},
		{name: "unsafe secret", locator: strings.Repeat("l", 32), secret: "SECRET_MARKER#" + strings.Repeat("SYNTHETIC_MARKER", 2)[:29]},
	} {
		t.Run(test.name, func(t *testing.T) {
			link, err := client.InvitationLink(test.locator, test.secret)
			if link != "" || !errors.Is(err, api.ErrInvitationLink) {
				t.Fatalf("InvitationLink result = %q, %v; want fixed error", link, err)
			}
			if strings.Contains(err.Error(), "LOCATOR_MARKER") || strings.Contains(err.Error(), "SECRET_MARKER") {
				t.Fatal("InvitationLink error exposed private input")
			}
		})
	}
}

func testEnvironment(token string) api.LookupEnv {
	return func(name string) (string, bool) {
		values := map[string]string{
			"SHORTBREAD_URL":   "https://unused.example",
			"SHORTBREAD_TOKEN": token,
		}
		value, ok := values[name]
		return value, ok
	}
}
