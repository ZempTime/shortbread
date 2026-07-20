package bundle_test

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ZempTime/shortbread/cli/internal/bundle"
)

func TestScanBuildsManifestForOneHTMLFile(t *testing.T) {
	directory := t.TempDir()
	content := []byte("<h1>synthetic private page</h1>")
	if err := os.WriteFile(filepath.Join(directory, "index.html"), content, 0o600); err != nil {
		t.Fatal("write Bundle")
	}

	scanned, err := bundle.Scan(directory)
	if err != nil {
		t.Fatalf("Scan: %v", err)
	}
	entries := scanned.ManifestEntries()
	if len(entries) != 1 {
		t.Fatalf("ManifestEntries length = %d, want 1", len(entries))
	}
	digest := sha256.Sum256(content)
	wantDigest := hex.EncodeToString(digest[:])
	entry := entries[0]
	if entry.Path != "index.html" || entry.SHA256 != wantDigest || entry.Size != int64(len(content)) || entry.ContentType != "text/html" || entry.OfflinePolicy != "required" {
		t.Fatalf("Manifest Entry = %#v", entry)
	}

	file, err := scanned.OpenBlob(wantDigest)
	if err != nil {
		t.Fatalf("OpenBlob: %v", err)
	}
	defer file.Close()
	read, err := os.ReadFile(file.Name())
	if err != nil || string(read) != string(content) {
		t.Fatal("OpenBlob did not resolve the exact scanned content")
	}
}

func TestScanRejectsUnsafeBundleEntriesWithoutDisclosingPaths(t *testing.T) {
	for _, test := range []struct {
		name  string
		build func(t *testing.T, directory string)
	}{
		{name: "symlink", build: func(t *testing.T, directory string) {
			outside := filepath.Join(t.TempDir(), "PRIVATE_OUTSIDE_MARKER")
			writeFile(t, outside, "private")
			if err := os.Symlink(outside, filepath.Join(directory, "linked.html")); err != nil {
				t.Skipf("symlinks unavailable: %v", err)
			}
		}},
		{name: "reserved directory", build: func(t *testing.T, directory string) {
			if err := os.Mkdir(filepath.Join(directory, "_shortbread"), 0o700); err != nil {
				t.Fatal("create reserved directory")
			}
			writeFile(t, filepath.Join(directory, "_shortbread", "session"), "private")
		}},
		{name: "reserved service worker", build: func(t *testing.T, directory string) {
			writeFile(t, filepath.Join(directory, "service-worker.js"), "private")
		}},
		{name: "environment file", build: func(t *testing.T, directory string) {
			writeFile(t, filepath.Join(directory, ".env.production"), "PRIVATE_SECRET_MARKER")
		}},
		{name: "private key", build: func(t *testing.T, directory string) {
			writeFile(t, filepath.Join(directory, "deploy.pem"), "PRIVATE_SECRET_MARKER")
		}},
		{name: "noncanonical punctuation", build: func(t *testing.T, directory string) {
			writeFile(t, filepath.Join(directory, "private%2ejson"), "private")
		}},
		{name: "non ASCII", build: func(t *testing.T, directory string) {
			writeFile(t, filepath.Join(directory, "caf\u00e9.html"), "private")
		}},
	} {
		t.Run(test.name, func(t *testing.T) {
			directory := t.TempDir()
			writeFile(t, filepath.Join(directory, "index.html"), "<h1>safe</h1>")
			test.build(t, directory)

			_, err := bundle.Scan(directory)
			if !errors.Is(err, bundle.ErrInvalidBundle) {
				t.Fatalf("Scan error = %v, want ErrInvalidBundle", err)
			}
			for _, marker := range []string{directory, "PRIVATE_OUTSIDE_MARKER", "PRIVATE_SECRET_MARKER"} {
				if strings.Contains(err.Error(), marker) {
					t.Fatal("Scan error exposed a private path or value")
				}
			}
		})
	}
}

func TestScanRejectsCaseCollisionsOnCaseSensitiveFilesystems(t *testing.T) {
	directory := t.TempDir()
	writeFile(t, filepath.Join(directory, "index.html"), "<h1>safe</h1>")
	first := filepath.Join(directory, "private.html")
	second := filepath.Join(directory, "PRIVATE.HTML")
	writeFile(t, first, "first")
	writeFile(t, second, "second")
	firstInfo, firstErr := os.Stat(first)
	secondInfo, secondErr := os.Stat(second)
	if firstErr != nil || secondErr != nil || os.SameFile(firstInfo, secondInfo) {
		t.Skip("filesystem does not preserve case-distinct entries")
	}

	_, err := bundle.Scan(directory)
	if !errors.Is(err, bundle.ErrInvalidBundle) {
		t.Fatalf("Scan error = %v, want case collision rejection", err)
	}
}

func TestScanRejectsMissingIndexAndSymlinkRoot(t *testing.T) {
	directory := t.TempDir()
	writeFile(t, filepath.Join(directory, "page.html"), "<h1>page</h1>")
	if _, err := bundle.Scan(directory); !errors.Is(err, bundle.ErrInvalidBundle) {
		t.Fatalf("Scan without index error = %v, want ErrInvalidBundle", err)
	}

	link := filepath.Join(t.TempDir(), "PRIVATE_ROOT_MARKER")
	if err := os.Symlink(directory, link); err != nil {
		t.Skipf("symlinks unavailable: %v", err)
	}
	if _, err := bundle.Scan(link); !errors.Is(err, bundle.ErrInvalidBundle) {
		t.Fatalf("Scan symlink root error = %v, want ErrInvalidBundle", err)
	}
}

func TestOpenBlobRejectsAFileChangedAfterScan(t *testing.T) {
	directory := t.TempDir()
	path := filepath.Join(directory, "index.html")
	writeFile(t, path, "original")
	scanned, err := bundle.Scan(directory)
	if err != nil {
		t.Fatalf("Scan: %v", err)
	}
	digest := scanned.ManifestEntries()[0].SHA256
	writeFile(t, path, "changed private content")

	file, err := scanned.OpenBlob(digest)
	if file != nil || !errors.Is(err, bundle.ErrInvalidBundle) {
		t.Fatalf("OpenBlob result = %v, %v; want fixed rejection", file, err)
	}
}

func writeFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatal("write Bundle entry")
	}
}
