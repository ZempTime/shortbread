package main

import (
	"context"
	"crypto/rand"
	"os"

	"github.com/ZempTime/shortbread/cli/internal/command"
)

var version = "dev"

func main() {
	exitCode := command.Execute(context.Background(), os.Args[1:], command.Runtime{
		Version:   version,
		LookupEnv: os.LookupEnv,
		Random:    rand.Reader,
		Stdout:    os.Stdout,
		Stderr:    os.Stderr,
	})
	os.Exit(exitCode)
}
