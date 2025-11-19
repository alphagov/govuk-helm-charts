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

var enableCmd = &cobra.Command{
	Use:   "enable",
	Short: "Enable workloads in an environment",
	Long: `Enable workers or apps for a specific workload in the given environment.

Examples:
  # Enable integration workers in publishing
  toggle enable --environment integration --type workers --workload Publishing

  # Enable staging apps in frontend with dry-run
  toggle enable --environment staging --type apps --workload Frontend --dry-run`,
	RunE: runEnable,
}

var (
	enableEnvironment string
	enableType        string
	enableWorkload    string
	enableDryRun      bool
	enableYes         bool
)

func init() {
	rootCmd.AddCommand(enableCmd)

	enableCmd.Flags().StringVarP(&enableEnvironment, "environment", "n", "", "Environment (integration, staging, production) [required]")
	enableCmd.Flags().StringVarP(&enableType, "type", "t", "", "Type of workload (workers, apps) [required]")
	enableCmd.Flags().StringVarP(&enableWorkload, "workload", "w", "", "Workload category (Publishing, Frontend) [required]")
	enableCmd.Flags().BoolVar(&enableDryRun, "dry-run", false, "Show changes without writing to disk")
	enableCmd.Flags().BoolVarP(&enableYes, "yes", "y", false, "Skip interactive confirmation")

	enableCmd.MarkFlagRequired("environment")
	enableCmd.MarkFlagRequired("type")
	enableCmd.MarkFlagRequired("workload")
}

func runEnable(cmd *cobra.Command, args []string) error {
	// Get current working directory (should be repo root)
	repoRoot, err := os.Getwd()
	if err != nil {
		return fmt.Errorf("failed to get current directory: %w", err)
	}

	// Check if working tree is dirty (unless dry-run)
	if !enableDryRun {
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
	apps, err := catalog.GetAppsForType(enableWorkload, enableType)
	if err != nil {
		return err
	}

	fmt.Printf("Found %d app(s) for workload '%s' with type '%s'\n", len(apps), enableWorkload, enableType)
	for _, app := range apps {
		fmt.Printf("  - %s\n", app.Name)
	}
	fmt.Println()

	// Production guardrail
	if enableEnvironment == "production" {
		ui.PrintProductionWarning()
		if !enableYes {
			if !ui.Confirm("Are you absolutely sure you want to modify PRODUCTION?") {
				fmt.Println("Aborted.")
				return nil
			}
		} else {
			fmt.Println("⚠️  Production changes authorized with --yes flag")
		}
	}

	// Load values file
	valuesFilePath := helm.GetValuesFilePath(repoRoot, enableEnvironment)
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

		switch enableType {
		case "workers":
			change, err = valuesFile.SetWorkerEnabled(app.Name, true)
		case "apps":
			change, err = valuesFile.SetAppEnabled(app.Name, true)
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
	if enableDryRun {
		ui.PrintDryRunHeader()
	}

	// Print changes
	ui.PrintChanges(changes, valuesFilePath)

	// If dry-run, exit here
	if enableDryRun {
		fmt.Println("Dry-run complete. No files were modified.")
		return nil
	}

	// Ask for confirmation unless --yes was provided
	if !enableYes {
		if !ui.Confirm("Apply these changes?") {
			fmt.Println("Aborted.")
			return nil
		}
	}

	// Save the file
	if err := valuesFile.SaveValuesFile(); err != nil {
		return fmt.Errorf("failed to save values file: %w", err)
	}

	ui.PrintSuccess(fmt.Sprintf("Successfully enabled %s for %s in %s", enableType, enableWorkload, enableEnvironment))
	fmt.Println("Changes have been written to:", valuesFilePath)
	fmt.Println("\nNext steps:")
	fmt.Println("  1. Review the changes: git diff")
	fmt.Println("  2. Commit the changes: git add . && git commit -m '♻️Enable <workload> <type>'")
	fmt.Println("  3. Push and create a PR")

	return nil
}
