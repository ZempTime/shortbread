package api

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"time"
)

// FeedbackComment is one Comment in a Site's Feedback Thread, carrying enough context for a
// browserless client to locate what it refers to: the Release it was left against, the path, the
// quoted text, and how confidently that quote still resolves.
type FeedbackComment struct {
	ID            int64    `json:"id"`
	ReleaseNumber int64    `json:"release_number"`
	Path          *string  `json:"path"`
	Quote         *string  `json:"quote"`
	Placement     string   `json:"placement"`
	Confidence    *float64 `json:"confidence"`
	Body          string   `json:"body"`
	Person        string   `json:"person"`
	CreatedAt     string   `json:"created_at"`
}

type FeedbackThread struct {
	Site struct {
		Slug string `json:"slug"`
	} `json:"site"`
	Comments []FeedbackComment `json:"comments"`
}

var feedbackPlacements = map[string]struct{}{
	"exact":      {},
	"moved":      {},
	"ambiguous":  {},
	"orphaned":   {},
	"unanchored": {},
}

func (client *Client) PullFeedback(ctx context.Context, siteSlug string) (FeedbackThread, error) {
	if client == nil || client.origin == nil || !validSiteSlug(siteSlug) {
		return FeedbackThread{}, ErrRequest
	}
	target := *client.origin
	target.Path = "/api/v1/sites/" + siteSlug + "/feedback"

	request, err := http.NewRequestWithContext(ctx, http.MethodGet, target.String(), nil)
	if err != nil {
		return FeedbackThread{}, ErrRequest
	}
	request.Header.Set("Accept", "application/json")
	request.Header.Set("Authorization", "Bearer "+client.token)
	response, err := client.http.Do(request)
	if err != nil {
		return FeedbackThread{}, ErrRequest
	}
	defer response.Body.Close()
	if response.StatusCode < http.StatusOK || response.StatusCode >= http.StatusMultipleChoices {
		return FeedbackThread{}, ErrRejected
	}

	var thread FeedbackThread
	decoder := json.NewDecoder(http.MaxBytesReader(nil, response.Body, 1<<22))
	if err := decoder.Decode(&thread); err != nil {
		return FeedbackThread{}, ErrResponse
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		return FeedbackThread{}, ErrResponse
	}
	if !validFeedbackThread(thread, siteSlug) {
		return FeedbackThread{}, ErrResponse
	}
	return thread, nil
}

func validFeedbackThread(thread FeedbackThread, siteSlug string) bool {
	if thread.Site.Slug != siteSlug {
		return false
	}
	seen := make(map[int64]struct{}, len(thread.Comments))
	for _, comment := range thread.Comments {
		if comment.ID <= 0 || comment.ReleaseNumber <= 0 || comment.Body == "" || comment.Person == "" {
			return false
		}
		if _, known := feedbackPlacements[comment.Placement]; !known {
			return false
		}
		// The Anchor is optional as a whole — a Site-level Comment has none — but a Comment that
		// claims one must carry both halves, or the quote cannot be located.
		if (comment.Path == nil) != (comment.Quote == nil) {
			return false
		}
		if comment.Path == nil && comment.Placement != "unanchored" {
			return false
		}
		if comment.Path != nil && comment.Placement == "unanchored" {
			return false
		}
		if _, duplicate := seen[comment.ID]; duplicate {
			return false
		}
		if _, err := time.Parse(time.RFC3339Nano, comment.CreatedAt); err != nil {
			return false
		}
		seen[comment.ID] = struct{}{}
	}
	return true
}
