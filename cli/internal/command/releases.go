package command

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"

	"github.com/ZempTime/shortbread/cli/internal/api"
	"github.com/spf13/cobra"
)

type releaseHistoryResult struct {
	Resource             string                `json:"resource"`
	SiteSlug             string                `json:"site_slug"`
	CurrentReleaseNumber *int64                `json:"current_release_number"`
	Releases             []api.ReleaseSummary  `json:"releases"`
	Pagination           api.ReleasePagination `json:"pagination"`
}

type releaseRollbackResult struct {
	Resource               string `json:"resource"`
	Status                 string `json:"status"`
	ID                     int64  `json:"id"`
	SiteSlug               string `json:"site_slug"`
	FromReleaseNumber      int64  `json:"from_release_number"`
	ToReleaseNumber        int64  `json:"to_release_number"`
	ResultingReleaseNumber int64  `json:"resulting_release_number"`
	Changed                bool   `json:"changed"`
	RecordedAt             string `json:"recorded_at"`
}

func newReleasesCommand(runtime Runtime, server *string, jsonOutput *bool) *cobra.Command {
	releases := &cobra.Command{Use: "releases", Short: "Inspect and roll back Releases"}

	var listSite string
	var limit int
	var before int64
	list := &cobra.Command{
		Use:          "list",
		Short:        "List immutable Releases",
		Args:         cobra.NoArgs,
		SilenceUsage: true,
		RunE: func(command *cobra.Command, _ []string) error {
			if !validSiteSlug(listSite) || limit < 1 || limit > 100 || before < 0 {
				return &failureError{failure: invalidInput}
			}
			client, err := newClient(*server, runtime.LookupEnv)
			if err != nil {
				return err
			}
			history, err := client.ListReleases(command.Context(), listSite, limit, before)
			if err != nil {
				return &failureError{failure: requestFailed}
			}
			result := releaseHistoryResult{
				Resource:             "release_history",
				SiteSlug:             history.Site.Slug,
				CurrentReleaseNumber: history.Site.CurrentReleaseNumber,
				Releases:             history.Releases,
				Pagination:           history.Pagination,
			}
			if err := writeReleaseHistory(runtime.Stdout, *jsonOutput, result); err != nil {
				return &failureError{failure: internalFailure}
			}
			return nil
		},
	}
	list.Flags().StringVar(&listSite, "site", "", "Site slug")
	list.Flags().IntVar(&limit, "limit", 50, "maximum Releases to return (1-100)")
	list.Flags().Int64Var(&before, "before", 0, "list Releases before this number")

	var rollbackSite string
	var releaseNumber int64
	rollback := &cobra.Command{
		Use:          "rollback",
		Short:        "Select an earlier immutable Release",
		Args:         cobra.NoArgs,
		SilenceUsage: true,
		RunE: func(command *cobra.Command, _ []string) error {
			if !validSiteSlug(rollbackSite) || releaseNumber <= 0 || runtime.Random == nil {
				return &failureError{failure: invalidInput}
			}
			var entropy [32]byte
			defer clear(entropy[:])
			if _, err := io.ReadFull(runtime.Random, entropy[:]); err != nil {
				return &failureError{failure: internalFailure}
			}
			idempotencyKey := base64.RawURLEncoding.EncodeToString(entropy[:])
			client, err := newClient(*server, runtime.LookupEnv)
			if err != nil {
				return err
			}
			rolledBack, err := client.RollbackRelease(command.Context(), rollbackSite, releaseNumber, idempotencyKey)
			if err != nil {
				return &failureError{failure: requestFailed}
			}
			status := "already_current"
			if rolledBack.Changed {
				status = "rolled_back"
			}
			result := releaseRollbackResult{
				Resource:               "release_rollback",
				Status:                 status,
				ID:                     rolledBack.ID,
				SiteSlug:               rolledBack.SiteSlug,
				FromReleaseNumber:      rolledBack.FromReleaseNumber,
				ToReleaseNumber:        rolledBack.ToReleaseNumber,
				ResultingReleaseNumber: rolledBack.ResultingReleaseNumber,
				Changed:                rolledBack.Changed,
				RecordedAt:             rolledBack.RecordedAt,
			}
			if err := writeReleaseRollback(runtime.Stdout, *jsonOutput, result); err != nil {
				return &failureError{failure: internalFailure}
			}
			return nil
		},
	}
	rollback.Flags().StringVar(&rollbackSite, "site", "", "Site slug")
	rollback.Flags().Int64Var(&releaseNumber, "release", 0, "Release number")

	releases.AddCommand(list, rollback)
	return releases
}

func writeReleaseHistory(output io.Writer, jsonOutput bool, result releaseHistoryResult) error {
	if output == nil {
		return &failureError{failure: internalFailure}
	}
	if jsonOutput {
		envelope := struct {
			OK     bool                 `json:"ok"`
			Result releaseHistoryResult `json:"result"`
		}{OK: true, Result: result}
		return json.NewEncoder(output).Encode(envelope)
	}
	if result.CurrentReleaseNumber == nil {
		if _, err := fmt.Fprintf(output, "Site %s has no current Release.\n", result.SiteSlug); err != nil {
			return err
		}
	} else if _, err := fmt.Fprintf(output, "Site %s current Release: %d.\n", result.SiteSlug, *result.CurrentReleaseNumber); err != nil {
		return err
	}
	for _, release := range result.Releases {
		marker := "-"
		if release.Current {
			marker = "*"
		}
		if _, err := fmt.Fprintf(output, "%s Release %d; %d files, %d bytes; finalized %s.\n",
			marker, release.Number, release.Files, release.Bytes, release.FinalizedAt); err != nil {
			return err
		}
	}
	if result.Pagination.NextBefore != nil {
		_, err := fmt.Fprintf(output, "More Releases: use --before %d.\n", *result.Pagination.NextBefore)
		return err
	}
	return nil
}

func writeReleaseRollback(output io.Writer, jsonOutput bool, result releaseRollbackResult) error {
	if output == nil {
		return &failureError{failure: internalFailure}
	}
	if jsonOutput {
		envelope := struct {
			OK     bool                  `json:"ok"`
			Result releaseRollbackResult `json:"result"`
		}{OK: true, Result: result}
		return json.NewEncoder(output).Encode(envelope)
	}
	if result.Changed {
		_, err := fmt.Fprintf(output, "Site %s rolled back from Release %d to Release %d.\n",
			result.SiteSlug, result.FromReleaseNumber, result.ToReleaseNumber)
		return err
	}
	_, err := fmt.Fprintf(output, "Release %d is already current for Site %s.\n", result.ToReleaseNumber, result.SiteSlug)
	return err
}
