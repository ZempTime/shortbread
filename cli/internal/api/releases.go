package api

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"
)

type ReleaseSummary struct {
	ID             int64  `json:"id"`
	Number         int64  `json:"number"`
	ManifestSHA256 string `json:"manifest_sha256"`
	FinalizedAt    string `json:"finalized_at"`
	Current        bool   `json:"current"`
	Files          int    `json:"files"`
	Bytes          int64  `json:"bytes"`
}

type ReleasePagination struct {
	Limit      int    `json:"limit"`
	NextBefore *int64 `json:"next_before"`
}

type ReleaseHistory struct {
	Site struct {
		Slug                 string `json:"slug"`
		CurrentReleaseNumber *int64 `json:"current_release_number"`
	} `json:"site"`
	Releases   []ReleaseSummary  `json:"releases"`
	Pagination ReleasePagination `json:"pagination"`
}

type ReleaseRollback struct {
	ID                     int64  `json:"id"`
	SiteSlug               string `json:"site_slug"`
	FromReleaseNumber      int64  `json:"from_release_number"`
	ToReleaseNumber        int64  `json:"to_release_number"`
	ResultingReleaseNumber int64  `json:"resulting_release_number"`
	Changed                bool   `json:"changed"`
	RecordedAt             string `json:"recorded_at"`
}

func (client *Client) ListReleases(ctx context.Context, siteSlug string, limit int, before int64) (ReleaseHistory, error) {
	if client == nil || client.origin == nil || !validSiteSlug(siteSlug) || limit < 1 || limit > 100 || before < 0 {
		return ReleaseHistory{}, ErrRequest
	}
	target := *client.origin
	target.Path = "/api/v1/sites/" + siteSlug + "/releases"
	query := target.Query()
	query.Set("limit", strconv.Itoa(limit))
	if before > 0 {
		query.Set("before", strconv.FormatInt(before, 10))
	}
	target.RawQuery = query.Encode()

	request, err := http.NewRequestWithContext(ctx, http.MethodGet, target.String(), nil)
	if err != nil {
		return ReleaseHistory{}, ErrRequest
	}
	request.Header.Set("Accept", "application/json")
	request.Header.Set("Authorization", "Bearer "+client.token)
	response, err := client.http.Do(request)
	if err != nil {
		return ReleaseHistory{}, ErrRequest
	}
	defer response.Body.Close()
	if response.StatusCode < http.StatusOK || response.StatusCode >= http.StatusMultipleChoices {
		return ReleaseHistory{}, ErrRejected
	}

	var history ReleaseHistory
	decoder := json.NewDecoder(http.MaxBytesReader(nil, response.Body, 1<<20))
	if err := decoder.Decode(&history); err != nil {
		return ReleaseHistory{}, ErrResponse
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		return ReleaseHistory{}, ErrResponse
	}
	if !validReleaseHistory(history, siteSlug, limit, before) {
		return ReleaseHistory{}, ErrResponse
	}
	return history, nil
}

func (client *Client) RollbackRelease(ctx context.Context, siteSlug string, number int64, idempotencyKey string) (ReleaseRollback, error) {
	if client == nil || client.origin == nil || !validSiteSlug(siteSlug) || number <= 0 || idempotencyKey == "" || len(idempotencyKey) > 512 || strings.ContainsAny(idempotencyKey, "\r\n") {
		return ReleaseRollback{}, ErrRequest
	}
	requestPath := "/api/v1/sites/" + siteSlug + "/releases/" + strconv.FormatInt(number, 10) + "/rollback"
	var responseBody struct {
		Rollback ReleaseRollback `json:"rollback"`
	}
	if err := client.postWithHeaders(
		ctx,
		requestPath,
		struct{}{},
		&responseBody,
		map[string]string{"Idempotency-Key": idempotencyKey},
	); err != nil {
		return ReleaseRollback{}, err
	}
	rollback := responseBody.Rollback
	if rollback.ID <= 0 || rollback.SiteSlug != siteSlug || rollback.FromReleaseNumber <= 0 ||
		rollback.ToReleaseNumber != number || rollback.ResultingReleaseNumber != number ||
		rollback.Changed != (rollback.FromReleaseNumber != rollback.ToReleaseNumber) {
		return ReleaseRollback{}, ErrResponse
	}
	if _, err := time.Parse(time.RFC3339Nano, rollback.RecordedAt); err != nil {
		return ReleaseRollback{}, ErrResponse
	}
	return rollback, nil
}

func validReleaseHistory(history ReleaseHistory, siteSlug string, limit int, before int64) bool {
	if history.Site.Slug != siteSlug || history.Pagination.Limit != limit || len(history.Releases) > limit {
		return false
	}
	if history.Site.CurrentReleaseNumber != nil && *history.Site.CurrentReleaseNumber <= 0 {
		return false
	}
	seenIDs := make(map[int64]struct{}, len(history.Releases))
	seenNumbers := make(map[int64]struct{}, len(history.Releases))
	var previous int64
	for index, release := range history.Releases {
		if release.ID <= 0 || release.Number <= 0 || !validSHA256(release.ManifestSHA256) || release.Files < 0 || release.Bytes < 0 {
			return false
		}
		if before > 0 && release.Number >= before || index > 0 && release.Number >= previous {
			return false
		}
		if _, duplicate := seenIDs[release.ID]; duplicate {
			return false
		}
		if _, duplicate := seenNumbers[release.Number]; duplicate {
			return false
		}
		if _, err := time.Parse(time.RFC3339Nano, release.FinalizedAt); err != nil {
			return false
		}
		isCurrent := history.Site.CurrentReleaseNumber != nil && release.Number == *history.Site.CurrentReleaseNumber
		if release.Current != isCurrent {
			return false
		}
		seenIDs[release.ID] = struct{}{}
		seenNumbers[release.Number] = struct{}{}
		previous = release.Number
	}
	if history.Pagination.NextBefore != nil {
		if len(history.Releases) != limit || len(history.Releases) == 0 || *history.Pagination.NextBefore != history.Releases[len(history.Releases)-1].Number {
			return false
		}
	}
	return true
}
