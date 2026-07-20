package api

import (
	"testing"
	"time"
)

func TestDefaultHTTPClientHasBoundedTimeout(t *testing.T) {
	client, err := New("https://shortbread.invalid", func(name string) (string, bool) {
		if name == "SHORTBREAD_TOKEN" {
			return "synthetic-test-bearer", true
		}
		return "", false
	})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	if client.http.Timeout <= 0 || client.http.Timeout > 30*time.Second {
		t.Fatalf("default HTTP timeout = %s, want > 0 and <= 30s", client.http.Timeout)
	}
}
