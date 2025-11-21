package helm

import (
	"os"
	"path/filepath"
	"strings"
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

	// Test enabling workers for an app without workers section - should return nil (can't create whole section)
	change, err = vf.SetWorkerEnabled("app-without-workers", true)
	if err != nil {
		t.Fatalf("SetWorkerEnabled failed: %v", err)
	}

	if change != nil {
		t.Error("SetWorkerEnabled should return nil change when workers section doesn't exist")
	}

	// Test app that doesn't exist - should return nil change
	change, err = vf.SetWorkerEnabled("nonexistent-app", true)
	if err != nil {
		t.Fatalf("SetWorkerEnabled failed: %v", err)
	}
	if change != nil {
		t.Error("SetWorkerEnabled should return nil change for nonexistent app")
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

	// Test enabling app without flag - should add it
	change, err = vf.SetAppEnabled("app-without-flag", true)
	if err != nil {
		t.Fatalf("SetAppEnabled failed: %v", err)
	}

	if change == nil {
		t.Error("SetAppEnabled should create change for app without appEnabled")
	} else if change.NewValue != "true" {
		t.Errorf("Change.NewValue = %v, want true", change.NewValue)
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

func TestSetAppEnabled_AddsField(t *testing.T) {
	tmpDir := t.TempDir()
	yamlPath := filepath.Join(tmpDir, "test-values.yaml")

	// Create a test values file with an app that has helmValues but no appEnabled
	yamlContent := `govukEnvironment: integration

govukApplications:
  - name: test-app
    helmValues:
      appResources:
        memory: 1Gi
      replicas: 2
`

	if err := os.WriteFile(yamlPath, []byte(yamlContent), 0644); err != nil {
		t.Fatalf("Failed to create test YAML: %v", err)
	}

	// Load the values file
	vf, err := LoadValuesFile(yamlPath)
	if err != nil {
		t.Fatalf("LoadValuesFile failed: %v", err)
	}

	// Test adding appEnabled to an app that doesn't have it
	change, err := vf.SetAppEnabled("test-app", false)
	if err != nil {
		t.Fatalf("SetAppEnabled failed: %v", err)
	}

	if change == nil {
		t.Fatal("SetAppEnabled should create change when adding field")
	}

	if change.NewValue != "false" {
		t.Errorf("Change.NewValue = %v, want false", change.NewValue)
	}

	if change.OldValue != "" {
		t.Errorf("Change.OldValue = %v, want empty string (field didn't exist)", change.OldValue)
	}

	// Save and verify the structure is preserved
	if err := vf.SaveValuesFile(); err != nil {
		t.Fatalf("SaveValuesFile failed: %v", err)
	}

	// Read back the file and check structure
	vf2, err := LoadValuesFile(yamlPath)
	if err != nil {
		t.Fatalf("LoadValuesFile (second load) failed: %v", err)
	}

	// Verify appEnabled was added and other fields are preserved
	foundAppEnabled := false
	foundAppResources := false
	foundReplicas := false
	inTestApp := false

	for _, line := range vf2.Lines {
		if strings.Contains(line, "- name: test-app") {
			inTestApp = true
			continue
		}
		if inTestApp {
			if strings.Contains(line, "appEnabled: false") {
				foundAppEnabled = true
			}
			if strings.Contains(line, "appResources:") {
				foundAppResources = true
			}
			if strings.Contains(line, "replicas: 2") {
				foundReplicas = true
			}
			// Exit if we hit the next app or end of helmValues
			if strings.HasPrefix(line, "  - name:") {
				break
			}
		}
	}

	if !foundAppEnabled {
		t.Error("appEnabled: false was not added to the file")
	}
	if !foundAppResources {
		t.Error("appResources field was lost")
	}
	if !foundReplicas {
		t.Error("replicas field was lost")
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
