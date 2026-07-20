package privatefile_test

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ZempTime/shortbread/cli/internal/privatefile"
)

func TestReserveLeavesExistingFileUnchanged(t *testing.T) {
	directory := t.TempDir()
	path := filepath.Join(directory, "PRIVATE_PATH_MARKER")
	original := []byte("ORIGINAL_CONTENT_MARKER")
	if err := os.WriteFile(path, original, 0o640); err != nil {
		t.Fatal("create existing file")
	}

	reservation, err := privatefile.Reserve(path)
	if reservation != nil {
		t.Fatal("Reserve returned a reservation for an existing file")
	}
	if !errors.Is(err, privatefile.ErrReserve) {
		t.Fatalf("Reserve error = %v, want ErrReserve", err)
	}
	if strings.Contains(err.Error(), "PRIVATE_PATH_MARKER") || strings.Contains(err.Error(), "ORIGINAL_CONTENT_MARKER") {
		t.Fatal("Reserve error exposed private path or content")
	}

	content, readErr := os.ReadFile(path)
	if readErr != nil {
		t.Fatal("read existing file")
	}
	if string(content) != string(original) {
		t.Fatalf("existing file changed: got %q", content)
	}
}

func TestCommitWritesExactContentToMode0600File(t *testing.T) {
	path := filepath.Join(t.TempDir(), "invitation-link")
	reservation, err := privatefile.Reserve(path)
	if err != nil {
		t.Fatalf("Reserve: %v", err)
	}
	content := []byte("PRIVATE_CONTENT_MARKER")
	if err := reservation.Commit(content); err != nil {
		t.Fatalf("Commit: %v", err)
	}

	info, err := os.Stat(path)
	if err != nil {
		t.Fatal("stat committed file")
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("mode = %o, want 600", info.Mode().Perm())
	}
	stored, err := os.ReadFile(path)
	if err != nil {
		t.Fatal("read committed file")
	}
	if string(stored) != string(content) {
		t.Fatal("committed content changed")
	}
}

func TestAbortRemovesReservation(t *testing.T) {
	path := filepath.Join(t.TempDir(), "invitation-link")
	reservation, err := privatefile.Reserve(path)
	if err != nil {
		t.Fatalf("Reserve: %v", err)
	}
	if err := reservation.Abort(); err != nil {
		t.Fatalf("Abort: %v", err)
	}
	if _, err := os.Stat(path); !errors.Is(err, os.ErrNotExist) {
		t.Fatal("Abort left the reserved file behind")
	}
}

func TestReserveRejectsNonFileSinksWithRedactedErrors(t *testing.T) {
	for _, path := range []string{"", "-", filepath.Join(t.TempDir(), "PRIVATE_PATH_MARKER", "link")} {
		reservation, err := privatefile.Reserve(path)
		if reservation != nil || !errors.Is(err, privatefile.ErrReserve) {
			t.Fatalf("Reserve(%q) = (%v, %v), want nil ErrReserve", path, reservation, err)
		}
		if strings.Contains(err.Error(), "PRIVATE_PATH_MARKER") {
			t.Fatal("Reserve error exposed a private path")
		}
	}
}
