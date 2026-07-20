package cli_test

import (
	"os/exec"
	"strings"
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

func TestBinaryHelpListsProducerCommandsOffline(t *testing.T) {
	command := exec.Command("go", "run", "-mod=readonly", "./cmd/shortbread", "--help")
	output, err := command.CombinedOutput()
	if err != nil {
		t.Fatalf("shortbread --help failed: %v\n%s", err, output)
	}
	for _, commandName := range []string{"sites", "people", "access", "invite", "publish"} {
		if !strings.Contains(string(output), commandName) {
			t.Fatalf("shortbread --help does not list %q: %s", commandName, output)
		}
	}
}
