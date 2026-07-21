package command

import (
	"bytes"
	"sync"
	"testing"
)

func TestOperationKeySurvivesRetryAndCanReplaceAnExpiredOperation(t *testing.T) {
	stateDir := t.TempDir()
	lookup := func(name string) (string, bool) {
		if name == "SHORTBREAD_STATE_DIR" {
			return stateDir, true
		}
		return "", false
	}
	first, err := acquireOperationKey(
		Runtime{LookupEnv: lookup, Random: bytes.NewReader(bytes.Repeat([]byte{1}, 32))},
		false, "publish", "server", "site", "manifest",
	)
	if err != nil {
		t.Fatalf("first operation key: %v", err)
	}
	retry, err := acquireOperationKey(
		Runtime{LookupEnv: lookup, Random: bytes.NewReader(bytes.Repeat([]byte{2}, 32))},
		false, "publish", "server", "site", "manifest",
	)
	if err != nil || retry.value != first.value {
		t.Fatalf("retry key = %q, %v; want exact replay", retry.value, err)
	}
	replacement, err := acquireOperationKey(
		Runtime{LookupEnv: lookup, Random: bytes.NewReader(bytes.Repeat([]byte{3}, 32))},
		true, "publish", "server", "site", "manifest",
	)
	if err != nil || replacement.value == first.value {
		t.Fatalf("replacement key = %q, %v; want a new operation", replacement.value, err)
	}
	if err := replacement.complete(); err != nil {
		t.Fatalf("complete replacement: %v", err)
	}
}

func TestConcurrentOperationKeyAcquisitionPublishesOneCompleteKey(t *testing.T) {
	stateDir := t.TempDir()
	lookup := func(name string) (string, bool) {
		return stateDir, name == "SHORTBREAD_STATE_DIR"
	}
	start := make(chan struct{})
	results := make(chan operationKey, 2)
	errors := make(chan error, 2)
	var ready sync.WaitGroup
	ready.Add(2)
	for value := byte(1); value <= 2; value++ {
		go func(value byte) {
			ready.Done()
			<-start
			key, err := acquireOperationKey(
				Runtime{LookupEnv: lookup, Random: bytes.NewReader(bytes.Repeat([]byte{value}, 32))},
				false, "rollback", "server", "site", "1",
			)
			results <- key
			errors <- err
		}(value)
	}
	ready.Wait()
	close(start)
	first, second := <-results, <-results
	if firstErr, secondErr := <-errors, <-errors; firstErr != nil || secondErr != nil {
		t.Fatalf("concurrent errors = %v, %v", firstErr, secondErr)
	}
	if first.value == "" || first.value != second.value {
		t.Fatalf("concurrent keys = %q, %q", first.value, second.value)
	}
	if err := first.complete(); err != nil {
		t.Fatalf("complete: %v", err)
	}
}
