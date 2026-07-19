package cli_test

import (
	"os/exec"
	"testing"
)

func TestBinaryReportsItsVersion(t *testing.T) {
	command := exec.Command("go", "run", "-mod=readonly", "./cmd/shortbread", "--version")
	output, err := command.CombinedOutput()
	if err != nil {
		t.Fatalf("shortbread --version failed: %v\n%s", err, output)
	}

	if got, want := string(output), "shortbread dev\n"; got != want {
		t.Fatalf("shortbread --version = %q, want %q", got, want)
	}
}
