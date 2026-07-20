package bundle

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"io"
	"mime"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

var ErrInvalidBundle = errors.New("invalid Bundle")

type ManifestEntry struct {
	Path          string `json:"path"`
	SHA256        string `json:"sha256"`
	Size          int64  `json:"size"`
	ContentType   string `json:"content_type"`
	OfflinePolicy string `json:"offline_policy"`
}

type Bundle struct {
	entries []ManifestEntry
	sources map[string]source
}

type source struct {
	path   string
	info   os.FileInfo
	digest string
}

func Scan(root string) (*Bundle, error) {
	rootInfo, err := os.Lstat(root)
	if err != nil || !rootInfo.IsDir() || rootInfo.Mode()&os.ModeSymlink != 0 {
		return nil, ErrInvalidBundle
	}

	result := &Bundle{sources: make(map[string]source)}
	casePaths := make(map[string]struct{})
	err = filepath.WalkDir(root, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return ErrInvalidBundle
		}
		if path == root {
			return nil
		}
		if entry.Type()&os.ModeSymlink != 0 {
			return ErrInvalidBundle
		}
		info, err := entry.Info()
		if err != nil {
			return ErrInvalidBundle
		}
		if info.IsDir() {
			return nil
		}
		if !info.Mode().IsRegular() {
			return ErrInvalidBundle
		}

		relative, err := filepath.Rel(root, path)
		if err != nil {
			return ErrInvalidBundle
		}
		manifestPath := filepath.ToSlash(relative)
		if !validPath(manifestPath) {
			return ErrInvalidBundle
		}
		casePath := strings.ToLower(manifestPath)
		if _, exists := casePaths[casePath]; exists {
			return ErrInvalidBundle
		}
		casePaths[casePath] = struct{}{}

		digest, size, err := digestFile(path, info)
		if err != nil {
			return ErrInvalidBundle
		}
		result.entries = append(result.entries, ManifestEntry{
			Path:          manifestPath,
			SHA256:        digest,
			Size:          size,
			ContentType:   contentType(manifestPath),
			OfflinePolicy: "required",
		})
		if _, exists := result.sources[digest]; !exists {
			result.sources[digest] = source{path: path, info: info, digest: digest}
		}
		return nil
	})
	if err != nil {
		return nil, ErrInvalidBundle
	}
	sort.Slice(result.entries, func(left, right int) bool {
		return result.entries[left].Path < result.entries[right].Path
	})
	if len(result.entries) == 0 || !hasHTMLIndex(result.entries) {
		return nil, ErrInvalidBundle
	}
	return result, nil
}

func (bundle *Bundle) ManifestEntries() []ManifestEntry {
	if bundle == nil {
		return nil
	}
	entries := make([]ManifestEntry, len(bundle.entries))
	copy(entries, bundle.entries)
	return entries
}

func (bundle *Bundle) OpenBlob(digest string) (*os.File, error) {
	if bundle == nil {
		return nil, ErrInvalidBundle
	}
	source, exists := bundle.sources[digest]
	if !exists {
		return nil, ErrInvalidBundle
	}
	currentInfo, err := os.Lstat(source.path)
	if err != nil || !currentInfo.Mode().IsRegular() || currentInfo.Mode()&os.ModeSymlink != 0 || !os.SameFile(source.info, currentInfo) {
		return nil, ErrInvalidBundle
	}
	file, err := os.Open(source.path)
	if err != nil {
		return nil, ErrInvalidBundle
	}
	openedInfo, err := file.Stat()
	if err != nil || !openedInfo.Mode().IsRegular() || !os.SameFile(currentInfo, openedInfo) {
		file.Close()
		return nil, ErrInvalidBundle
	}
	hash := sha256.New()
	size, err := io.Copy(hash, file)
	if err != nil || size != openedInfo.Size() || hex.EncodeToString(hash.Sum(nil)) != source.digest {
		file.Close()
		return nil, ErrInvalidBundle
	}
	if _, err := file.Seek(0, io.SeekStart); err != nil {
		file.Close()
		return nil, ErrInvalidBundle
	}
	return file, nil
}

func digestFile(path string, expected os.FileInfo) (string, int64, error) {
	file, err := os.Open(path)
	if err != nil {
		return "", 0, err
	}
	defer file.Close()
	opened, err := file.Stat()
	if err != nil || !opened.Mode().IsRegular() || !os.SameFile(expected, opened) {
		return "", 0, ErrInvalidBundle
	}
	hash := sha256.New()
	size, err := io.Copy(hash, file)
	if err != nil || size != opened.Size() {
		return "", 0, ErrInvalidBundle
	}
	return hex.EncodeToString(hash.Sum(nil)), size, nil
}

func hasHTMLIndex(entries []ManifestEntry) bool {
	for _, entry := range entries {
		if entry.Path == "index.html" && entry.ContentType == "text/html" && entry.OfflinePolicy == "required" {
			return true
		}
	}
	return false
}

func validPath(path string) bool {
	if path == "" || !isASCII(path) || strings.HasPrefix(path, "/") || strings.ContainsAny(path, "\\\x00") {
		return false
	}
	segments := strings.Split(path, "/")
	for index, segment := range segments {
		if !validSegment(segment) || secretLike(segment) {
			return false
		}
		if index == 0 && strings.EqualFold(segment, "_shortbread") {
			return false
		}
	}
	return !strings.EqualFold(path, "service-worker.js")
}

func validSegment(segment string) bool {
	if segment == "" || segment == "." || segment == ".." || !asciiAlphaNumeric(segment[0]) {
		return false
	}
	for _, character := range []byte(segment[1:]) {
		if !asciiAlphaNumeric(character) && character != '.' && character != '_' && character != '-' {
			return false
		}
	}
	return true
}

func asciiAlphaNumeric(character byte) bool {
	return character >= 'a' && character <= 'z' ||
		character >= 'A' && character <= 'Z' ||
		character >= '0' && character <= '9'
}

func isASCII(value string) bool {
	for _, character := range []byte(value) {
		if character > 0x7f {
			return false
		}
	}
	return true
}

func secretLike(segment string) bool {
	lower := strings.ToLower(segment)
	if lower == ".env" || strings.HasPrefix(lower, ".env.") {
		return true
	}
	if lower == "credentials.yml.enc" || lower == "id_rsa" || lower == "id_dsa" || lower == "id_ecdsa" || lower == "id_ed25519" {
		return true
	}
	return strings.HasSuffix(lower, ".pem") || strings.HasSuffix(lower, ".key")
}

func contentType(path string) string {
	switch strings.ToLower(filepath.Ext(path)) {
	case ".html", ".htm":
		return "text/html"
	case ".css":
		return "text/css"
	case ".js", ".mjs":
		return "text/javascript"
	case ".json":
		return "application/json"
	case ".svg":
		return "image/svg+xml"
	}
	value := mime.TypeByExtension(strings.ToLower(filepath.Ext(path)))
	if separator := strings.IndexByte(value, ';'); separator >= 0 {
		value = value[:separator]
	}
	if value == "" {
		return "application/octet-stream"
	}
	return value
}
