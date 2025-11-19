package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "toggle",
	Short: "Toggle CLI for managing GOV.UK Helm chart workloads",
	Long: `toggle is a CLI tool for enabling and disabling groups of workloads
per environment in the govuk-helm-charts repository.

It operates on local Helm values files and prepares changes for GitOps deployment.`,
}

// Execute runs the root command
func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func init() {
	// Global flags can be added here if needed
}
