package cmd

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/alphagov/govuk-helm-charts/toggle/internal/config"
	"github.com/alphagov/govuk-helm-charts/toggle/internal/git"
	"github.com/alphagov/govuk-helm-charts/toggle/internal/helm"
	"github.com/alphagov/govuk-helm-charts/toggle/internal/ui"
	"github.com/spf13/cobra"
)

var disableCmd = &cobra.Command{
	Use:   "disable",
	Short: "Disable workload types in an environment",
	Long: `Disable workers or apps for a specific workload in the given environment.

Examples:
  # Disable integration workers in publishing
  toggle disable --environment integration --type workers --workload Publishing

  # Disable staging apps in frontend with dry-run
  toggle disable --environment staging --type apps --workload Frontend --dry-run`,
	RunE: runDisable,
}

var (
	disableEnvironment string
	disableType        string
	disableWorkload    string
	disableDryRun      bool
	disableYes         bool
)

func init() {
	rootCmd.AddCommand(disableCmd)

	disableCmd.Flags().StringVarP(&disableEnvironment, "environment", "n", "", "Environment (integration, staging, production) [required]")
	disableCmd.Flags().StringVarP(&disableType, "type", "t", "", "Type of workload (workers, apps) [required]")
	disableCmd.Flags().StringVarP(&disableWorkload, "workload", "w", "", "Workload category (Publishing, Frontend) [required]")
	disableCmd.Flags().BoolVar(&disableDryRun, "dry-run", false, "Show changes without writing to disk")
	disableCmd.Flags().BoolVarP(&disableYes, "yes", "y", false, "Skip interactive confirmation")

	disableCmd.MarkFlagRequired("environment")
	disableCmd.MarkFlagRequired("type")
	disableCmd.MarkFlagRequired("workload")
}

func runDisable(cmd *cobra.Command, args []string) error {
	// Get current working directory (should be repo root)
	repoRoot, err := os.Getwd()
	if err != nil {
		return fmt.Errorf("failed to get current directory: %w", err)
	}

	// Check if working tree is dirty (unless dry-run)
	if !disableDryRun {
		dirty, err := git.IsWorkingTreeDirty(repoRoot)
		if err != nil {
			return fmt.Errorf("failed to check git status: %w", err)
		}
		if dirty {
			return fmt.Errorf("working tree is dirty. Please commit or stash your changes before running toggle")
		}
	}

	// Load app catalog from CSV
	csvPath := filepath.Join(repoRoot, "apps.csv")
	catalog, err := config.LoadAppCatalog(csvPath)
	if err != nil {
		return fmt.Errorf("failed to load app catalog: %w", err)
	}

	// Get apps for the specified workload and type
	apps, err := catalog.GetAppsForType(disableWorkload, disableType)
	if err != nil {
		return err
	}

	fmt.Printf("Found %d app(s) for workload '%s' with type '%s'\n", len(apps), disableWorkload, disableType)
	for _, app := range apps {
		fmt.Printf("  - %s\n", app.Name)
	}
	fmt.Println()

	// Production guardrail
	if disableEnvironment == "production" {
		ui.PrintProductionWarning()
		fmt.Println("⚠️  DISABLING production workloads can cause service outages!")
		fmt.Println()
		if !disableYes {
			if !ui.Confirm("Are you absolutely sure you want to DISABLE workloads in PRODUCTION?") {
				fmt.Println("Aborted.")
				return nil
			}
		} else {
			fmt.Println("⚠️  Production changes authorized with --yes flag")
		}
	}

	// Load values file
	valuesFilePath := helm.GetValuesFilePath(repoRoot, disableEnvironment)
	if _, err := os.Stat(valuesFilePath); os.IsNotExist(err) {
		return fmt.Errorf("values file not found: %s", valuesFilePath)
	}

	valuesFile, err := helm.LoadValuesFile(valuesFilePath)
	if err != nil {
		return fmt.Errorf("failed to load values file: %w", err)
	}

	// Apply changes based on type
	var changes []*helm.Change
	for _, app := range apps {
		var change *helm.Change
		var err error

		switch disableType {
		case "workers":
			change, err = valuesFile.SetWorkerEnabled(app.Name, false)
		case "apps":
			change, err = valuesFile.SetAppEnabled(app.Name, false)
		}

		if err != nil {
			fmt.Fprintf(os.Stderr, "Warning: %v\n", err)
			continue
		}

		if change != nil {
			changes = append(changes, change)
		}
	}

	if len(changes) == 0 {
		fmt.Println("No changes to make.")
		return nil
	}

	// Show dry-run header if applicable
	if disableDryRun {
		ui.PrintDryRunHeader()
	}

	// Print changes
	ui.PrintChanges(changes, valuesFilePath)

	// If dry-run, exit here
	if disableDryRun {
		fmt.Println("Dry-run complete. No files were modified.")
		return nil
	}

	// Ask for confirmation unless --yes was provided
	if !disableYes {
		if !ui.Confirm("Apply these changes?") {
			fmt.Println("Aborted.")
			return nil
		}
	}

	// Save the file
	if err := valuesFile.SaveValuesFile(); err != nil {
		return fmt.Errorf("failed to save values file: %w", err)
	}

	ui.PrintSuccess(fmt.Sprintf("Successfully disabled %s for %s in %s", disableType, disableWorkload, disableEnvironment))
	fmt.Println("Changes have been written to:", valuesFilePath)
	fmt.Println("\nNext steps:")
	fmt.Println("  1. Review the changes: git diff")
	fmt.Println("  2. Commit the changes: git add . && git commit -m '♻️Disable <workload> <type>'")
	fmt.Println("  3. Push and create a PR")

	return nil
}
