package command

import (
	"encoding/json"
	"fmt"
	"io"

	"github.com/ZempTime/shortbread/cli/internal/api"
	"github.com/spf13/cobra"
)

type feedbackThreadResult struct {
	Resource string                `json:"resource"`
	SiteSlug string                `json:"site_slug"`
	Comments []api.FeedbackComment `json:"comments"`
}

func newFeedbackCommand(runtime Runtime, server *string, jsonOutput *bool) *cobra.Command {
	feedback := &cobra.Command{Use: "feedback", Short: "Retrieve the Feedback Thread for a Site"}

	var site string
	pull := &cobra.Command{
		Use:          "pull",
		Short:        "Pull every Comment left on a Site",
		Args:         cobra.NoArgs,
		SilenceUsage: true,
		RunE: func(command *cobra.Command, _ []string) error {
			if !validSiteSlug(site) {
				return &failureError{failure: invalidInput}
			}
			client, err := newClient(*server, runtime.LookupEnv)
			if err != nil {
				return err
			}
			thread, err := client.PullFeedback(command.Context(), site)
			if err != nil {
				return &failureError{failure: requestFailed}
			}
			result := feedbackThreadResult{
				Resource: "feedback_thread",
				SiteSlug: thread.Site.Slug,
				Comments: thread.Comments,
			}
			if err := writeFeedbackThread(runtime.Stdout, *jsonOutput, result); err != nil {
				return &failureError{failure: internalFailure}
			}
			return nil
		},
	}
	pull.Flags().StringVar(&site, "site", "", "Site slug")

	feedback.AddCommand(pull)
	return feedback
}

func writeFeedbackThread(output io.Writer, jsonOutput bool, result feedbackThreadResult) error {
	if output == nil {
		return &failureError{failure: internalFailure}
	}
	if jsonOutput {
		envelope := struct {
			OK     bool                 `json:"ok"`
			Result feedbackThreadResult `json:"result"`
		}{OK: true, Result: result}
		return json.NewEncoder(output).Encode(envelope)
	}
	if len(result.Comments) == 0 {
		_, err := fmt.Fprintf(output, "Site %s has no Comments.\n", result.SiteSlug)
		return err
	}
	if _, err := fmt.Fprintf(output, "Site %s has %d Comment(s).\n", result.SiteSlug, len(result.Comments)); err != nil {
		return err
	}
	for _, comment := range result.Comments {
		if err := writeFeedbackComment(output, comment); err != nil {
			return err
		}
	}
	return nil
}

func writeFeedbackComment(output io.Writer, comment api.FeedbackComment) error {
	location := "no selection"
	if comment.Path != nil {
		location = *comment.Path
	}
	if _, err := fmt.Fprintf(output, "\n%s on Release %d, %s [%s] at %s\n",
		comment.Person, comment.ReleaseNumber, location, comment.Placement, comment.CreatedAt); err != nil {
		return err
	}
	// The quote is what makes a Comment actionable without a browser, so it is printed even when
	// the placement is orphaned — that is exactly the case a human has to resolve by hand.
	if comment.Quote != nil {
		if _, err := fmt.Fprintf(output, "  > %s\n", *comment.Quote); err != nil {
			return err
		}
	}
	_, err := fmt.Fprintf(output, "  %s\n", comment.Body)
	return err
}
