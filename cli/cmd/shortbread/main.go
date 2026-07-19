package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var version = "dev"

func main() {
	command := &cobra.Command{
		Use:           "shortbread",
		Short:         "Publish private websites with Shortbread",
		SilenceErrors: true,
		SilenceUsage:  true,
		Version:       version,
	}
	command.SetVersionTemplate("shortbread {{.Version}}\n")

	if err := command.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
