package api

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

var (
	ErrInvalidServer  = errors.New("invalid Shortbread server")
	ErrMissingToken   = errors.New("SHORTBREAD_TOKEN is required")
	ErrRequest        = errors.New("Shortbread request failed")
	ErrRejected       = errors.New("Shortbread server rejected the request")
	ErrResponse       = errors.New("Shortbread server returned an invalid response")
	ErrInvitationLink = errors.New("could not construct Invitation link")
)

type LookupEnv func(string) (string, bool)

type Client struct {
	origin *url.URL
	token  string
	http   *http.Client
}

type Site struct {
	ID   int64  `json:"id"`
	Slug string `json:"slug"`
	Name string `json:"name"`
}

type Person struct {
	ID        int64  `json:"id"`
	FirstName string `json:"first_name"`
}

type Grant struct {
	ID       int64  `json:"id"`
	SiteSlug string `json:"site_slug"`
	PersonID int64  `json:"person_id"`
}

type Invitation struct {
	ID        int64  `json:"id"`
	Locator   string `json:"locator"`
	ExpiresAt string `json:"expires_at"`
	Status    string `json:"status"`
}

type ManifestEntry struct {
	Path          string `json:"path"`
	SHA256        string `json:"sha256"`
	Size          int64  `json:"size"`
	ContentType   string `json:"content_type"`
	OfflinePolicy string `json:"offline_policy"`
}

type PublishUpload struct {
	SHA256  string            `json:"sha256"`
	Size    int64             `json:"size"`
	Method  string            `json:"method"`
	URL     string            `json:"url"`
	Headers map[string]string `json:"headers"`
}

type PublishPlan struct {
	ID          int64           `json:"id"`
	State       string          `json:"state"`
	Delta       PublishDelta    `json:"delta"`
	Uploads     []PublishUpload `json:"uploads"`
	FinalizeURL string          `json:"finalize_url"`
}

type PublishDelta struct {
	Added   int `json:"added"`
	Changed int `json:"changed"`
	Reused  int `json:"reused"`
	Removed int `json:"removed"`
}

type Release struct {
	ID             int64  `json:"id"`
	SiteSlug       string `json:"site_slug"`
	Number         int64  `json:"number"`
	ManifestSHA256 string `json:"manifest_sha256"`
}

func New(explicitServer string, lookupEnv LookupEnv) (*Client, error) {
	server := strings.TrimSpace(explicitServer)
	if server == "" {
		server, _ = lookupEnv("SHORTBREAD_URL")
		server = strings.TrimSpace(server)
	}
	origin, err := parseOrigin(server)
	if err != nil {
		return nil, ErrInvalidServer
	}

	token, ok := lookupEnv("SHORTBREAD_TOKEN")
	if !ok || token == "" || strings.ContainsAny(token, "\r\n") {
		return nil, ErrMissingToken
	}

	return &Client{
		origin: origin,
		token:  token,
		http: &http.Client{
			Timeout:   30 * time.Second,
			Transport: newHTTPTransport(),
			CheckRedirect: func(_ *http.Request, _ []*http.Request) error {
				return http.ErrUseLastResponse
			},
		},
	}, nil
}

func (client *Client) CreateSite(ctx context.Context, slug, name string) (Site, error) {
	requestBody := struct {
		Slug string `json:"slug"`
		Name string `json:"name"`
	}{Slug: slug, Name: name}
	var responseBody struct {
		Site Site `json:"site"`
	}
	if err := client.post(ctx, "/api/v1/sites", requestBody, &responseBody); err != nil {
		return Site{}, err
	}
	if responseBody.Site.ID <= 0 || responseBody.Site.Slug != slug || responseBody.Site.Name != name {
		return Site{}, ErrResponse
	}
	return responseBody.Site, nil
}

func (client *Client) CreatePerson(ctx context.Context, firstName string) (Person, error) {
	requestBody := struct {
		FirstName string `json:"first_name"`
	}{FirstName: firstName}
	var responseBody struct {
		Person Person `json:"person"`
	}
	if err := client.post(ctx, "/api/v1/people", requestBody, &responseBody); err != nil {
		return Person{}, err
	}
	if responseBody.Person.ID <= 0 || responseBody.Person.FirstName != firstName {
		return Person{}, ErrResponse
	}
	return responseBody.Person, nil
}

func (client *Client) CreateGrant(ctx context.Context, siteSlug string, personID int64) (Grant, error) {
	requestBody := struct {
		SiteSlug string `json:"site_slug"`
		PersonID int64  `json:"person_id"`
	}{SiteSlug: siteSlug, PersonID: personID}
	var responseBody struct {
		Grant Grant `json:"grant"`
	}
	if err := client.post(ctx, "/api/v1/grants", requestBody, &responseBody); err != nil {
		return Grant{}, err
	}
	if responseBody.Grant.ID <= 0 || responseBody.Grant.SiteSlug != siteSlug || responseBody.Grant.PersonID != personID {
		return Grant{}, ErrResponse
	}
	return responseBody.Grant, nil
}

func (client *Client) CreatePublishPlan(ctx context.Context, siteSlug, idempotencyKey string, entries []ManifestEntry) (PublishPlan, error) {
	if !validSiteSlug(siteSlug) || idempotencyKey == "" || len(idempotencyKey) > 512 || strings.ContainsAny(idempotencyKey, "\r\n") || len(entries) == 0 {
		return PublishPlan{}, ErrRequest
	}
	requestBody := struct {
		Manifest struct {
			Entries []ManifestEntry `json:"entries"`
		} `json:"manifest"`
	}{}
	requestBody.Manifest.Entries = entries
	var responseBody struct {
		PublishPlan PublishPlan `json:"publish_plan"`
	}
	requestPath := "/api/v1/sites/" + siteSlug + "/publish-plans"
	if err := client.postWithHeaders(ctx, requestPath, requestBody, &responseBody, map[string]string{"Idempotency-Key": idempotencyKey}); err != nil {
		return PublishPlan{}, err
	}
	if !client.validPublishPlan(responseBody.PublishPlan, entries) {
		return PublishPlan{}, ErrResponse
	}
	return responseBody.PublishPlan, nil
}

func (client *Client) UploadBlob(ctx context.Context, upload PublishUpload, body io.Reader) error {
	if client == nil || body == nil || !validSHA256(upload.SHA256) || upload.Size < 0 || upload.Method != http.MethodPut || !validUploadHeaders(upload.Headers) {
		return ErrRequest
	}
	target, sameOrigin, err := client.resolveUploadURL(upload.URL)
	if err != nil {
		return ErrResponse
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPut, target.String(), body)
	if err != nil {
		return ErrRequest
	}
	request.ContentLength = upload.Size
	request.Header.Set("Content-Type", "application/octet-stream")
	if sameOrigin {
		request.Header.Set("Authorization", "Bearer "+client.token)
	}
	response, err := client.http.Do(request)
	if err != nil {
		return ErrRequest
	}
	defer response.Body.Close()
	if response.StatusCode < http.StatusOK || response.StatusCode >= http.StatusMultipleChoices {
		return ErrRejected
	}
	return nil
}

func (client *Client) FinalizePublishPlan(ctx context.Context, plan PublishPlan, siteSlug string) (Release, error) {
	expectedPath := "/api/v1/publish-plans/" + strconv.FormatInt(plan.ID, 10) + "/finalize"
	if plan.ID <= 0 || plan.FinalizeURL != expectedPath || !validSiteSlug(siteSlug) {
		return Release{}, ErrRequest
	}
	var responseBody struct {
		Release Release `json:"release"`
	}
	if err := client.post(ctx, expectedPath, struct{}{}, &responseBody); err != nil {
		return Release{}, err
	}
	release := responseBody.Release
	if release.ID <= 0 || release.SiteSlug != siteSlug || release.Number <= 0 || !validSHA256(release.ManifestSHA256) {
		return Release{}, ErrResponse
	}
	return release, nil
}

func (client *Client) resolveUploadURL(raw string) (*url.URL, bool, error) {
	if client == nil || client.origin == nil || raw == "" {
		return nil, false, ErrResponse
	}
	reference, err := url.Parse(raw)
	if err != nil || reference.User != nil || reference.Fragment != "" {
		return nil, false, ErrResponse
	}
	if reference.IsAbs() {
		if reference.Scheme != "https" && (reference.Scheme != "http" || !isLoopback(reference.Hostname())) {
			return nil, false, ErrResponse
		}
		sameOrigin := strings.EqualFold(reference.Scheme, client.origin.Scheme) && strings.EqualFold(reference.Host, client.origin.Host)
		return reference, sameOrigin, nil
	}
	if reference.Host != "" || !strings.HasPrefix(reference.Path, "/") {
		return nil, false, ErrResponse
	}
	return client.origin.ResolveReference(reference), true, nil
}

func (client *Client) validPublishPlan(plan PublishPlan, entries []ManifestEntry) bool {
	if plan.ID <= 0 || plan.State != "open" && plan.State != "finalized" || plan.FinalizeURL != "/api/v1/publish-plans/"+strconv.FormatInt(plan.ID, 10)+"/finalize" {
		return false
	}
	if plan.Delta.Added < 0 || plan.Delta.Changed < 0 || plan.Delta.Reused < 0 || plan.Delta.Removed < 0 ||
		plan.Delta.Added+plan.Delta.Changed+plan.Delta.Reused != len(entries) {
		return false
	}
	expected := make(map[string]int64)
	for _, entry := range entries {
		if !validSHA256(entry.SHA256) || entry.Size < 0 {
			return false
		}
		if size, exists := expected[entry.SHA256]; exists && size != entry.Size {
			return false
		}
		expected[entry.SHA256] = entry.Size
	}
	seen := make(map[string]struct{})
	for _, upload := range plan.Uploads {
		size, exists := expected[upload.SHA256]
		if !exists || upload.Size != size || upload.Method != http.MethodPut || !client.validUploadURL(upload.URL, plan.ID, upload.SHA256) {
			return false
		}
		if !validUploadHeaders(upload.Headers) {
			return false
		}
		if _, duplicate := seen[upload.SHA256]; duplicate {
			return false
		}
		seen[upload.SHA256] = struct{}{}
	}
	return true
}

func (client *Client) validUploadURL(raw string, planID int64, digest string) bool {
	target, err := url.Parse(raw)
	if err != nil || target.User != nil || target.Fragment != "" {
		return false
	}
	expectedPath := "/api/v1/publish-plans/" + strconv.FormatInt(planID, 10) + "/blobs/" + digest
	if !target.IsAbs() {
		return target.Host == "" && target.Path == expectedPath && target.RawQuery == ""
	}
	if target.Host == "" || target.Scheme != "https" && (target.Scheme != "http" || !isLoopback(target.Hostname())) {
		return false
	}
	sameOrigin := strings.EqualFold(target.Scheme, client.origin.Scheme) && strings.EqualFold(target.Host, client.origin.Host)
	return !sameOrigin || target.Path == expectedPath && target.RawQuery == ""
}

func validUploadHeaders(headers map[string]string) bool {
	return len(headers) == 1 && headers["Content-Type"] == "application/octet-stream"
}

func validSHA256(value string) bool {
	if len(value) != 64 {
		return false
	}
	for _, character := range []byte(value) {
		if character >= '0' && character <= '9' || character >= 'a' && character <= 'f' {
			continue
		}
		return false
	}
	return true
}

func validSiteSlug(value string) bool {
	if value == "" || len(value) > 63 || !lowerAlphaNumeric(value[0]) {
		return false
	}
	for _, character := range []byte(value[1:]) {
		if character >= 'a' && character <= 'z' || character >= '0' && character <= '9' || character == '-' {
			continue
		}
		return false
	}
	return value[len(value)-1] != '-'
}

func lowerAlphaNumeric(character byte) bool {
	return character >= 'a' && character <= 'z' || character >= '0' && character <= '9'
}

func (client *Client) CreateInvitation(ctx context.Context, grantID int64, secretDigest string) (Invitation, error) {
	requestBody := struct {
		SecretDigest string `json:"secret_digest"`
	}{SecretDigest: secretDigest}
	var responseBody struct {
		Invitation Invitation `json:"invitation"`
	}
	requestPath := "/api/v1/grants/" + strconv.FormatInt(grantID, 10) + "/invitations"
	if err := client.post(ctx, requestPath, requestBody, &responseBody); err != nil {
		return Invitation{}, err
	}
	if !validInvitation(responseBody.Invitation) {
		return Invitation{}, ErrResponse
	}
	return responseBody.Invitation, nil
}

func validInvitation(invitation Invitation) bool {
	if invitation.ID <= 0 || invitation.Status != "pending" || !validLocator(invitation.Locator) {
		return false
	}
	expiresAt, err := time.Parse(time.RFC3339, invitation.ExpiresAt)
	return err == nil && expiresAt.After(time.Now())
}

func validLocator(locator string) bool {
	return validURLSafe(locator, 32)
}

func validURLSafe(value string, length int) bool {
	if len(value) != length {
		return false
	}
	for _, character := range []byte(value) {
		if (character >= 'a' && character <= 'z') ||
			(character >= 'A' && character <= 'Z') ||
			(character >= '0' && character <= '9') ||
			character == '-' || character == '_' {
			continue
		}
		return false
	}
	return true
}

func (client *Client) InvitationLink(locator, secret string) (string, error) {
	if client == nil || client.origin == nil || !validLocator(locator) || !validURLSafe(secret, 43) {
		return "", ErrInvitationLink
	}
	target := *client.origin
	target.Path = "/invitations/" + locator
	target.RawPath = ""
	target.RawQuery = ""
	target.Fragment = secret
	link := target.String()
	parsed, err := url.Parse(link)
	if err != nil || parsed.User != nil || parsed.RawQuery != "" || parsed.Path != target.Path || parsed.Fragment != secret {
		return "", ErrInvitationLink
	}
	return link, nil
}

func (client *Client) post(ctx context.Context, requestPath string, requestBody, responseBody any) error {
	return client.postWithHeaders(ctx, requestPath, requestBody, responseBody, nil)
}

func (client *Client) postWithHeaders(ctx context.Context, requestPath string, requestBody, responseBody any, headers map[string]string) error {
	body, err := json.Marshal(requestBody)
	if err != nil {
		return ErrRequest
	}
	target := *client.origin
	target.Path = requestPath

	request, err := http.NewRequestWithContext(ctx, http.MethodPost, target.String(), bytes.NewReader(body))
	if err != nil {
		return ErrRequest
	}
	request.Header.Set("Accept", "application/json")
	request.Header.Set("Authorization", "Bearer "+client.token)
	request.Header.Set("Content-Type", "application/json")
	for name, value := range headers {
		request.Header.Set(name, value)
	}

	response, err := client.http.Do(request)
	if err != nil {
		return ErrRequest
	}
	defer response.Body.Close()
	if response.StatusCode < http.StatusOK || response.StatusCode >= http.StatusMultipleChoices {
		return ErrRejected
	}
	decoder := json.NewDecoder(http.MaxBytesReader(nil, response.Body, 1<<20))
	if err := decoder.Decode(responseBody); err != nil {
		return ErrResponse
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		return ErrResponse
	}
	return nil
}

func parseOrigin(raw string) (*url.URL, error) {
	origin, err := url.Parse(raw)
	if err != nil || origin.Host == "" || origin.User != nil || origin.RawQuery != "" || origin.Fragment != "" {
		return nil, ErrInvalidServer
	}
	if origin.Path != "" && origin.Path != "/" {
		return nil, ErrInvalidServer
	}
	if origin.Scheme != "https" {
		if origin.Scheme != "http" || !isLoopback(origin.Hostname()) {
			return nil, ErrInvalidServer
		}
	}
	origin.Path = ""
	return origin, nil
}

func newHTTPTransport() *http.Transport {
	transport := http.DefaultTransport.(*http.Transport).Clone()
	dialContext := transport.DialContext
	transport.DialContext = func(ctx context.Context, network, address string) (net.Conn, error) {
		hostname, port, err := net.SplitHostPort(address)
		if err == nil && isReservedLocalhostSubdomain(hostname) {
			address = net.JoinHostPort("127.0.0.1", port)
		}
		return dialContext(ctx, network, address)
	}
	transport.Proxy = func(request *http.Request) (*url.URL, error) {
		if isReservedLocalhostSubdomain(request.URL.Hostname()) {
			return nil, nil
		}
		return http.ProxyFromEnvironment(request)
	}
	return transport
}

func isLoopback(hostname string) bool {
	address := net.ParseIP(hostname)
	if address != nil {
		return address.IsLoopback()
	}

	hostname = strings.ToLower(hostname)
	if hostname == "localhost" {
		return true
	}
	return isReservedLocalhostSubdomain(hostname)
}

func isReservedLocalhostSubdomain(hostname string) bool {
	hostname = strings.ToLower(hostname)
	return strings.HasSuffix(hostname, ".localhost") && validLocalhostName(hostname)
}

func validLocalhostName(hostname string) bool {
	if hostname == "" || len(hostname) > 253 {
		return false
	}

	labels := strings.Split(hostname, ".")
	if len(labels) < 2 || labels[len(labels)-1] != "localhost" {
		return false
	}
	for _, label := range labels {
		if label == "" || len(label) > 63 || !lowerAlphaNumeric(label[0]) || !lowerAlphaNumeric(label[len(label)-1]) {
			return false
		}
		for index := 1; index < len(label)-1; index++ {
			character := label[index]
			if !lowerAlphaNumeric(character) && character != '-' {
				return false
			}
		}
	}
	return true
}
