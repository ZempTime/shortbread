package privatefile

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
)

func TestCommitFailureKeepsResidualFileCleanupRetryable(t *testing.T) {
	directory := t.TempDir()
	path := filepath.Join(directory, "invitation-link")
	reservation, err := Reserve(path)
	if err != nil {
		t.Fatalf("Reserve: %v", err)
	}
	if _, err := reservation.file.Write([]byte("PRIVATE_CONTENT_MARKER")); err != nil {
		t.Fatal("seed partial private content")
	}
	if err := reservation.file.Close(); err != nil {
		t.Fatal("close reservation to force Commit failure")
	}

	blockedPath := filepath.Join(directory, "blocked")
	if err := os.Mkdir(blockedPath, 0o700); err != nil {
		t.Fatal("create blocked cleanup path")
	}
	if err := os.WriteFile(filepath.Join(blockedPath, "child"), []byte("MARKER"), 0o600); err != nil {
		t.Fatal("make cleanup path nonempty")
	}
	originalPath := reservation.path
	reservation.path = blockedPath

	if err := reservation.Commit([]byte("PRIVATE_CONTENT_MARKER")); !errors.Is(err, ErrCommit) {
		t.Fatalf("Commit error = %v, want ErrCommit", err)
	}
	if reservation.done {
		t.Fatal("failed cleanup made the reservation non-retryable")
	}

	reservation.path = originalPath
	if err := reservation.Abort(); err != nil {
		t.Fatalf("retry Abort: %v", err)
	}
	if _, err := os.Stat(originalPath); !errors.Is(err, os.ErrNotExist) {
		t.Fatal("retry Abort left partial private content behind")
	}
}
