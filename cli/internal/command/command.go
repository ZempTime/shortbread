package command

import (
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"strconv"
	"strings"

	"github.com/ZempTime/shortbread/cli/internal/api"
	"github.com/ZempTime/shortbread/cli/internal/bundle"
	"github.com/ZempTime/shortbread/cli/internal/privatefile"
	"github.com/spf13/cobra"
)

type Runtime struct {
	Version   string
	LookupEnv api.LookupEnv
	Random    io.Reader
	Stdout    io.Writer
	Stderr    io.Writer
}

func Execute(ctx context.Context, args []string, runtime Runtime) int {
	return execute(ctx, args, runtime, dependencies{reserve: reservePrivateOutput})
}

type privateOutput interface {
	Commit([]byte) error
	Abort() error
}

type dependencies struct {
	reserve func(string) (privateOutput, error)
}

func reservePrivateOutput(path string) (privateOutput, error) {
	return privatefile.Reserve(path)
}

func execute(ctx context.Context, args []string, runtime Runtime, deps dependencies) int {
	stdout := runtime.Stdout
	if stdout == nil {
		stdout = io.Discard
	}
	stderr := runtime.Stderr
	if stderr == nil {
		stderr = io.Discard
	}

	var server string
	var jsonOutput bool
	root := &cobra.Command{
		Use:           "shortbread",
		Short:         "Publish private websites with Shortbread",
		SilenceErrors: true,
		SilenceUsage:  true,
		Version:       runtime.Version,
	}
	root.SetVersionTemplate("shortbread {{.Version}}\n")
	root.PersistentFlags().StringVar(&server, "server", "", "Shortbread server origin")
	root.PersistentFlags().BoolVar(&jsonOutput, "json", false, "write machine-readable JSON")
	jsonOutput = requestedJSON(args)
	root.AddCommand(newSitesCommand(runtime, &server, &jsonOutput))
	root.AddCommand(newPeopleCommand(runtime, &server, &jsonOutput))
	root.AddCommand(newAccessCommand(runtime, &server, &jsonOutput))
	root.AddCommand(newInviteCommand(runtime, &server, &jsonOutput, deps))
	root.AddCommand(newPublishCommand(runtime, &server, &jsonOutput))
	root.AddCommand(newReleasesCommand(runtime, &server, &jsonOutput))
	root.SetArgs(args)
	root.SetOut(stdout)
	root.SetErr(io.Discard)

	if err := root.ExecuteContext(ctx); err != nil {
		failure := invalidInput
		var commandFailure *failureError
		if errors.As(err, &commandFailure) {
			failure = commandFailure.failure
		}
		if renderError := writeFailure(stdout, stderr, jsonOutput, failure); renderError != nil {
			return internalFailure.exitCode
		}
		return failure.exitCode
	}
	return 0
}

func requestedJSON(args []string) bool {
	for _, argument := range args {
		if argument == "--json" {
			return true
		}
		if strings.HasPrefix(argument, "--json=") {
			value, err := strconv.ParseBool(strings.TrimPrefix(argument, "--json="))
			if err == nil {
				return value
			}
		}
	}
	return false
}

type failure struct {
	exitCode int
	code     string
	human    string
}

var (
	invalidInput        = failure{exitCode: 2, code: "invalid_input", human: "invalid command input"}
	configurationFailed = failure{exitCode: 3, code: "configuration_failed", human: "Shortbread configuration is unavailable"}
	requestFailed       = failure{exitCode: 4, code: "request_failed", human: "Shortbread request failed"}
	privateOutputFailed = failure{exitCode: 5, code: "private_output_failed", human: "private link could not be written"}
	internalFailure     = failure{exitCode: 1, code: "internal_failure", human: "Shortbread could not complete the command"}
)

type failureError struct {
	failure failure
}

func (err *failureError) Error() string {
	return err.failure.code
}

type successResult struct {
	Resource    string `json:"resource"`
	ID          int64  `json:"id"`
	Status      string `json:"status"`
	LinkWritten bool   `json:"link_written,omitempty"`
}

type publishSuccessResult struct {
	Resource string `json:"resource"`
	ID       int64  `json:"id"`
	Status   string `json:"status"`
	Number   int64  `json:"number"`
	Files    int    `json:"files"`
	Uploaded int    `json:"uploaded"`
	Added    int    `json:"added"`
	Changed  int    `json:"changed"`
	Reused   int    `json:"reused"`
	Removed  int    `json:"removed"`
	Bytes    int64  `json:"bytes"`
}

func newSitesCommand(runtime Runtime, server *string, jsonOutput *bool) *cobra.Command {
	sites := &cobra.Command{Use: "sites", Short: "Manage Sites"}
	var slug string
	var name string
	create := &cobra.Command{
		Use:          "create",
		Short:        "Create a Site",
		Args:         cobra.NoArgs,
		SilenceUsage: true,
		RunE: func(command *cobra.Command, _ []string) error {
			if strings.TrimSpace(slug) == "" || strings.TrimSpace(name) == "" {
				return &failureError{failure: invalidInput}
			}
			client, err := newClient(*server, runtime.LookupEnv)
			if err != nil {
				return err
			}
			site, err := client.CreateSite(command.Context(), slug, name)
			if err != nil {
				return &failureError{failure: requestFailed}
			}
			if err := writeSuccess(runtime.Stdout, *jsonOutput, successResult{Resource: "site", ID: site.ID, Status: "created"}); err != nil {
				return &failureError{failure: internalFailure}
			}
			return nil
		},
	}
	create.Flags().StringVar(&slug, "slug", "", "Site slug")
	create.Flags().StringVar(&name, "name", "", "Site name")
	sites.AddCommand(create)
	return sites
}

func newPeopleCommand(runtime Runtime, server *string, jsonOutput *bool) *cobra.Command {
	people := &cobra.Command{Use: "people", Short: "Manage People"}
	var firstName string
	add := &cobra.Command{
		Use:          "add",
		Short:        "Add a Person",
		Args:         cobra.NoArgs,
		SilenceUsage: true,
		RunE: func(command *cobra.Command, _ []string) error {
			if strings.TrimSpace(firstName) == "" {
				return &failureError{failure: invalidInput}
			}
			client, err := newClient(*server, runtime.LookupEnv)
			if err != nil {
				return err
			}
			person, err := client.CreatePerson(command.Context(), firstName)
			if err != nil {
				return &failureError{failure: requestFailed}
			}
			if err := writeSuccess(runtime.Stdout, *jsonOutput, successResult{Resource: "person", ID: person.ID, Status: "created"}); err != nil {
				return &failureError{failure: internalFailure}
			}
			return nil
		},
	}
	add.Flags().StringVar(&firstName, "first-name", "", "Person first name")
	people.AddCommand(add)
	return people
}

func newAccessCommand(runtime Runtime, server *string, jsonOutput *bool) *cobra.Command {
	access := &cobra.Command{Use: "access", Short: "Manage access"}
	var siteSlug string
	var personID int64
	grant := &cobra.Command{
		Use:          "grant",
		Short:        "Grant Site access to a Person",
		Args:         cobra.NoArgs,
		SilenceUsage: true,
		RunE: func(command *cobra.Command, _ []string) error {
			if strings.TrimSpace(siteSlug) == "" || personID <= 0 {
				return &failureError{failure: invalidInput}
			}
			client, err := newClient(*server, runtime.LookupEnv)
			if err != nil {
				return err
			}
			createdGrant, err := client.CreateGrant(command.Context(), siteSlug, personID)
			if err != nil {
				return &failureError{failure: requestFailed}
			}
			if err := writeSuccess(runtime.Stdout, *jsonOutput, successResult{Resource: "grant", ID: createdGrant.ID, Status: "created"}); err != nil {
				return &failureError{failure: internalFailure}
			}
			return nil
		},
	}
	grant.Flags().StringVar(&siteSlug, "site", "", "Site slug")
	grant.Flags().Int64Var(&personID, "person", 0, "Person ID")
	access.AddCommand(grant)
	return access
}

func newInviteCommand(runtime Runtime, server *string, jsonOutput *bool, deps dependencies) *cobra.Command {
	invite := &cobra.Command{Use: "invite", Short: "Manage Invitations"}
	var grantID int64
	var linkFile string
	create := &cobra.Command{
		Use:          "create",
		Short:        "Create an Invitation",
		Args:         cobra.NoArgs,
		SilenceUsage: true,
		RunE: func(command *cobra.Command, _ []string) error {
			if grantID <= 0 {
				return &failureError{failure: invalidInput}
			}
			client, err := newClient(*server, runtime.LookupEnv)
			if err != nil {
				return err
			}
			if deps.reserve == nil {
				return &failureError{failure: internalFailure}
			}
			reservation, err := deps.reserve(linkFile)
			if err != nil {
				return &failureError{failure: privateOutputFailed}
			}
			defer reservation.Abort()

			var entropy [32]byte
			defer clear(entropy[:])
			if runtime.Random == nil {
				return &failureError{failure: privateOutputFailed}
			}
			if _, err := io.ReadFull(runtime.Random, entropy[:]); err != nil {
				return &failureError{failure: privateOutputFailed}
			}
			var encodedSecret [43]byte
			defer clear(encodedSecret[:])
			base64.RawURLEncoding.Encode(encodedSecret[:], entropy[:])
			digest := sha256.Sum256(encodedSecret[:])
			defer clear(digest[:])
			invitation, err := client.CreateInvitation(command.Context(), grantID, hex.EncodeToString(digest[:]))
			if err != nil {
				return &failureError{failure: requestFailed}
			}
			link, err := client.InvitationLink(invitation.Locator, string(encodedSecret[:]))
			if err != nil {
				return &failureError{failure: requestFailed}
			}
			linkBytes := []byte(link)
			defer clear(linkBytes)
			if err := reservation.Commit(linkBytes); err != nil {
				return &failureError{failure: privateOutputFailed}
			}
			result := successResult{Resource: "invitation", ID: invitation.ID, Status: "created", LinkWritten: true}
			if err := writeInvitationSuccess(runtime.Stdout, *jsonOutput, result); err != nil {
				return &failureError{failure: internalFailure}
			}
			return nil
		},
	}
	create.Flags().Int64Var(&grantID, "grant", 0, "Grant ID")
	create.Flags().StringVar(&linkFile, "link-file", "", "Private Invitation link output file")
	invite.AddCommand(create)
	return invite
}

func newPublishCommand(runtime Runtime, server *string, jsonOutput *bool) *cobra.Command {
	var siteSlug string
	publish := &cobra.Command{
		Use:          "publish <directory>",
		Short:        "Publish a Bundle as an immutable Release",
		Args:         cobra.ExactArgs(1),
		SilenceUsage: true,
		RunE: func(command *cobra.Command, args []string) error {
			if !validSiteSlug(siteSlug) {
				return &failureError{failure: invalidInput}
			}
			scanned, err := bundle.Scan(args[0])
			if err != nil {
				return &failureError{failure: invalidInput}
			}
			entries := scanned.ManifestEntries()
			manifest, totalBytes, ok := publishManifest(entries)
			if !ok {
				return &failureError{failure: invalidInput}
			}

			client, err := newClient(*server, runtime.LookupEnv)
			if err != nil {
				return err
			}
			manifestIdentity, err := json.Marshal(manifest)
			if err != nil {
				return &failureError{failure: internalFailure}
			}
			key, err := acquireOperationKey(runtime, "publish", *server, siteSlug, string(manifestIdentity))
			if err != nil {
				return &failureError{failure: internalFailure}
			}
			plan, err := client.CreatePublishPlan(command.Context(), siteSlug, key.value, manifest)
			if err != nil {
				return &failureError{failure: requestFailed}
			}
			for _, upload := range plan.Uploads {
				file, err := scanned.OpenBlob(upload.SHA256)
				if err != nil {
					return &failureError{failure: invalidInput}
				}
				uploadErr := client.UploadBlob(command.Context(), upload, io.LimitReader(file, upload.Size))
				closeErr := file.Close()
				if uploadErr != nil {
					return &failureError{failure: requestFailed}
				}
				if closeErr != nil {
					return &failureError{failure: internalFailure}
				}
			}
			release, err := client.FinalizePublishPlan(command.Context(), plan, siteSlug)
			if err != nil {
				return &failureError{failure: requestFailed}
			}
			result := publishSuccessResult{
				Resource: "release",
				ID:       release.ID,
				Status:   "published",
				Number:   release.Number,
				Files:    len(entries),
				Uploaded: len(plan.Uploads),
				Added:    plan.Delta.Added,
				Changed:  plan.Delta.Changed,
				Reused:   plan.Delta.Reused,
				Removed:  plan.Delta.Removed,
				Bytes:    totalBytes,
			}
			if err := writePublishSuccess(runtime.Stdout, *jsonOutput, result); err != nil {
				return &failureError{failure: internalFailure}
			}
			if err := key.complete(); err != nil {
				return &failureError{failure: internalFailure}
			}
			return nil
		},
	}
	publish.Flags().StringVar(&siteSlug, "site", "", "Site slug")
	return publish
}

func publishManifest(entries []bundle.ManifestEntry) ([]api.ManifestEntry, int64, bool) {
	manifest := make([]api.ManifestEntry, 0, len(entries))
	var totalBytes int64
	for _, entry := range entries {
		if entry.Size < 0 || totalBytes > math.MaxInt64-entry.Size {
			return nil, 0, false
		}
		totalBytes += entry.Size
		manifest = append(manifest, api.ManifestEntry{
			Path:          entry.Path,
			SHA256:        entry.SHA256,
			Size:          entry.Size,
			ContentType:   entry.ContentType,
			OfflinePolicy: entry.OfflinePolicy,
		})
	}
	return manifest, totalBytes, len(manifest) > 0
}

func validSiteSlug(value string) bool {
	if value == "" || len(value) > 63 || !lowerAlphaNumeric(value[0]) {
		return false
	}
	for _, character := range []byte(value[1:]) {
		if lowerAlphaNumeric(character) || character == '-' {
			continue
		}
		return false
	}
	return value[len(value)-1] != '-'
}

func lowerAlphaNumeric(character byte) bool {
	return character >= 'a' && character <= 'z' || character >= '0' && character <= '9'
}

func newClient(server string, lookupEnv api.LookupEnv) (*api.Client, error) {
	if lookupEnv == nil {
		lookupEnv = func(string) (string, bool) { return "", false }
	}
	client, err := api.New(server, lookupEnv)
	if err != nil {
		return nil, &failureError{failure: configurationFailed}
	}
	return client, nil
}

func writeSuccess(output io.Writer, jsonOutput bool, result successResult) error {
	if output == nil {
		return &failureError{failure: internalFailure}
	}
	if jsonOutput {
		envelope := struct {
			OK     bool          `json:"ok"`
			Result successResult `json:"result"`
		}{OK: true, Result: result}
		return json.NewEncoder(output).Encode(envelope)
	}
	_, err := fmt.Fprintf(output, "%s %d created.\n", strings.ToUpper(result.Resource[:1])+result.Resource[1:], result.ID)
	return err
}

func writeInvitationSuccess(output io.Writer, jsonOutput bool, result successResult) error {
	if jsonOutput {
		return writeSuccess(output, true, result)
	}
	_, err := fmt.Fprintf(output, "Invitation %d created; private link written.\n", result.ID)
	return err
}

func writePublishSuccess(output io.Writer, jsonOutput bool, result publishSuccessResult) error {
	if output == nil {
		return &failureError{failure: internalFailure}
	}
	if jsonOutput {
		envelope := struct {
			OK     bool                 `json:"ok"`
			Result publishSuccessResult `json:"result"`
		}{OK: true, Result: result}
		return json.NewEncoder(output).Encode(envelope)
	}
	_, err := fmt.Fprintf(output, "Release %d published; %d files, %d uploaded; %d added, %d changed, %d reused, %d removed; %d bytes.\n",
		result.Number, result.Files, result.Uploaded, result.Added, result.Changed, result.Reused, result.Removed, result.Bytes)
	return err
}

func writeFailure(stdout, stderr io.Writer, jsonOutput bool, failure failure) error {
	if jsonOutput {
		envelope := struct {
			OK    bool `json:"ok"`
			Error struct {
				Code string `json:"code"`
			} `json:"error"`
		}{OK: false}
		envelope.Error.Code = failure.code
		return json.NewEncoder(stdout).Encode(envelope)
	}
	_, err := fmt.Fprintln(stderr, failure.human)
	return err
}
