package helm

import (
	"os"
	"path/filepath"
	"testing"
)

func TestSetWorkerEnabled(t *testing.T) {
	tmpDir := t.TempDir()
	yamlPath := filepath.Join(tmpDir, "test-values.yaml")

	// Create a test values file
	yamlContent := `govukEnvironment: integration

govukApplications:
  - name: test-app
    helmValues:
      workers:
        enabled: true
      appResources:
        memory: 1Gi

  - name: app-without-workers
    helmValues:
      appResources:
        memory: 512Mi
`

	if err := os.WriteFile(yamlPath, []byte(yamlContent), 0644); err != nil {
		t.Fatalf("Failed to create test YAML: %v", err)
	}

	// Load the values file
	vf, err := LoadValuesFile(yamlPath)
	if err != nil {
		t.Fatalf("LoadValuesFile failed: %v", err)
	}

	// Test disabling workers for an app that has them
	change, err := vf.SetWorkerEnabled("test-app", false)
	if err != nil {
		t.Fatalf("SetWorkerEnabled failed: %v", err)
	}

	if change.AppName != "test-app" {
		t.Errorf("Change.AppName = %s, want test-app", change.AppName)
	}

	if change.Path != "workers.enabled" {
		t.Errorf("Change.Path = %s, want workers.enabled", change.Path)
	}

	if change.NewValue != "false" {
		t.Errorf("Change.NewValue = %v, want false", change.NewValue)
	}

	// Test enabling workers for an app without them - should fail with line-based approach
	_, err = vf.SetWorkerEnabled("app-without-workers", true)
	if err == nil {
		t.Error("SetWorkerEnabled should fail for app without workers.enabled field")
	}

	// Test app that doesn't exist
	_, err = vf.SetWorkerEnabled("nonexistent-app", true)
	if err == nil {
		t.Error("SetWorkerEnabled should fail for nonexistent app")
	}
}

func TestSetAppEnabled(t *testing.T) {
	tmpDir := t.TempDir()
	yamlPath := filepath.Join(tmpDir, "test-values.yaml")

	// Create a test values file
	yamlContent := `govukEnvironment: integration

govukApplications:
  - name: test-app
    helmValues:
      appEnabled: true
      appResources:
        memory: 1Gi

  - name: app-without-flag
    helmValues:
      appResources:
        memory: 512Mi
`

	if err := os.WriteFile(yamlPath, []byte(yamlContent), 0644); err != nil {
		t.Fatalf("Failed to create test YAML: %v", err)
	}

	// Load the values file
	vf, err := LoadValuesFile(yamlPath)
	if err != nil {
		t.Fatalf("LoadValuesFile failed: %v", err)
	}

	// Test disabling app
	change, err := vf.SetAppEnabled("test-app", false)
	if err != nil {
		t.Fatalf("SetAppEnabled failed: %v", err)
	}

	if change.AppName != "test-app" {
		t.Errorf("Change.AppName = %s, want test-app", change.AppName)
	}

	if change.Path != "appEnabled" {
		t.Errorf("Change.Path = %s, want appEnabled", change.Path)
	}

	if change.NewValue != "false" {
		t.Errorf("Change.NewValue = %v, want false", change.NewValue)
	}

	// Test enabling app without flag - should fail with line-based approach
	_, err = vf.SetAppEnabled("app-without-flag", true)
	if err == nil {
		t.Error("SetAppEnabled should fail for app without appEnabled field")
	}
}

func TestSaveValuesFile(t *testing.T) {
	tmpDir := t.TempDir()
	yamlPath := filepath.Join(tmpDir, "test-values.yaml")

	// Create a test values file
	yamlContent := `govukEnvironment: integration

govukApplications:
  - name: test-app
    helmValues:
      workers:
        enabled: true
`

	if err := os.WriteFile(yamlPath, []byte(yamlContent), 0644); err != nil {
		t.Fatalf("Failed to create test YAML: %v", err)
	}

	// Load, modify, and save
	vf, err := LoadValuesFile(yamlPath)
	if err != nil {
		t.Fatalf("LoadValuesFile failed: %v", err)
	}

	_, err = vf.SetWorkerEnabled("test-app", false)
	if err != nil {
		t.Fatalf("SetWorkerEnabled failed: %v", err)
	}

	if err := vf.SaveValuesFile(); err != nil {
		t.Fatalf("SaveValuesFile failed: %v", err)
	}

	// Reload and verify the change was saved
	vf2, err := LoadValuesFile(yamlPath)
	if err != nil {
		t.Fatalf("LoadValuesFile (second load) failed: %v", err)
	}

	// Check that workers.enabled is now false by searching through lines
	var found bool
	inTestApp := false
	for _, line := range vf2.Lines {
		if !inTestApp && (line == "  - name: test-app" || line == "  - name: test-app ") {
			inTestApp = true
			continue
		}
		if inTestApp && (line == "        enabled: false" || line == "        enabled: false ") {
			found = true
			break
		}
		// Exit if we hit the next app
		if inTestApp && (line == "  - name:" || (len(line) > 0 && line[0] != ' ')) {
			break
		}
	}

	if !found {
		t.Error("workers.enabled not found or not set to false in saved file")
	}
}

func TestGetValuesFilePath(t *testing.T) {
	tests := []struct {
		repoRoot string
		env      string
		want     string
	}{
		{"/repo", "integration", "/repo/charts/app-config/values-integration.yaml"},
		{"/repo", "staging", "/repo/charts/app-config/values-staging.yaml"},
		{"/repo", "production", "/repo/charts/app-config/values-production.yaml"},
	}

	for _, tt := range tests {
		t.Run(tt.env, func(t *testing.T) {
			got := GetValuesFilePath(tt.repoRoot, tt.env)
			if got != tt.want {
				t.Errorf("GetValuesFilePath(%s, %s) = %s, want %s", tt.repoRoot, tt.env, got, tt.want)
			}
		})
	}
}
