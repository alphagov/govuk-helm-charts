package ui

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	"github.com/alphagov/govuk-helm-charts/toggle/internal/helm"
)

// PrintChanges prints the changes that will be made
func PrintChanges(changes []*helm.Change, valuesFilePath string) {
	fmt.Printf("\n=== Planned Changes ===\n")
	fmt.Printf("File: %s\n\n", valuesFilePath)

	for _, change := range changes {
		fmt.Printf("  App: %s\n", change.AppName)
		fmt.Printf("    Path: %s\n", change.Path)
		fmt.Printf("    Change: %v → %v\n", change.OldValue, change.NewValue)
		fmt.Println()
	}

	fmt.Printf("Total changes: %d\n\n", len(changes))
}

// Confirm asks the user for confirmation
func Confirm(message string) bool {
	fmt.Printf("%s [y/N]: ", message)

	reader := bufio.NewReader(os.Stdin)
	response, err := reader.ReadString('\n')
	if err != nil {
		return false
	}

	response = strings.ToLower(strings.TrimSpace(response))
	return response == "y" || response == "yes"
}

// PrintDryRunHeader prints the dry-run header
func PrintDryRunHeader() {
	fmt.Println("\n🔍 DRY RUN MODE - No changes will be written")
	fmt.Println("═══════════════════════════════════════════════")
}

// PrintProductionWarning prints a warning for production changes
func PrintProductionWarning() {
	fmt.Println("\n⚠️  WARNING: PRODUCTION ENVIRONMENT")
	fmt.Println("═══════════════════════════════════════════════")
	fmt.Println("You are about to make changes to PRODUCTION.")
	fmt.Println("These changes will affect live services.")
	fmt.Println()
}

// PrintSuccess prints a success message
func PrintSuccess(message string) {
	fmt.Printf("\n✅ %s\n\n", message)
}

// PrintError prints an error message
func PrintError(message string) {
	fmt.Fprintf(os.Stderr, "\n❌ Error: %s\n\n", message)
}
