package main

import (
	"os"
	"strings"
	"testing"
)

func TestProcessYAML_EnableAppEnabled(t *testing.T) {
	input := `govukApplications:
  - name: account-api
    helmValues:
      appEnabled: false
  - name: email-alert-service
    helmValues:
      appEnabled: false
  - name: content-store
    helmValues:
      appEnabled: false`

	expected := `govukApplications:
  - name: account-api
    helmValues:
      appEnabled: true
  - name: email-alert-service
    helmValues:
      appEnabled: false
  - name: content-store
    helmValues:
      appEnabled: true`

	publishingApps := map[string]bool{
		"account-api":    true,
		"content-store":  true,
	}

	lines := strings.Split(input, "\n")
	result, count := processYAML(lines, publishingApps, true, "app", false)
	output := strings.Join(result, "\n")

	if count != 2 {
		t.Errorf("Expected 2 changes, got %d", count)
	}

	if output != expected {
		t.Errorf("Output mismatch.\nExpected:\n%s\n\nGot:\n%s", expected, output)
	}
}

func TestProcessYAML_DisableAppEnabled(t *testing.T) {
	input := `govukApplications:
  - name: account-api
    helmValues:
      appEnabled: true
  - name: email-alert-service
    helmValues:
      appEnabled: true
  - name: content-store
    helmValues:
      appEnabled: true`

	expected := `govukApplications:
  - name: account-api
    helmValues:
      appEnabled: false
  - name: email-alert-service
    helmValues:
      appEnabled: true
  - name: content-store
    helmValues:
      appEnabled: false`

	publishingApps := map[string]bool{
		"account-api":    true,
		"content-store":  true,
	}

	lines := strings.Split(input, "\n")
	result, count := processYAML(lines, publishingApps, false, "app", false)
	output := strings.Join(result, "\n")

	if count != 2 {
		t.Errorf("Expected 2 changes, got %d", count)
	}

	if output != expected {
		t.Errorf("Output mismatch.\nExpected:\n%s\n\nGot:\n%s", expected, output)
	}
}

func TestProcessYAML_EnableWorkers(t *testing.T) {
	input := `govukApplications:
  - name: account-api
    helmValues:
      workers:
        enabled: false
  - name: email-alert-service
    helmValues:
      workers:
        enabled: false
  - name: content-store
    helmValues:
      workers:
        enabled: false`

	expected := `govukApplications:
  - name: account-api
    helmValues:
      workers:
        enabled: true
  - name: email-alert-service
    helmValues:
      workers:
        enabled: false
  - name: content-store
    helmValues:
      workers:
        enabled: true`

	publishingApps := map[string]bool{
		"account-api":    true,
		"content-store":  true,
	}

	lines := strings.Split(input, "\n")
	result, count := processYAML(lines, publishingApps, true, "workers", false)
	output := strings.Join(result, "\n")

	if count != 2 {
		t.Errorf("Expected 2 changes, got %d", count)
	}

	if output != expected {
		t.Errorf("Output mismatch.\nExpected:\n%s\n\nGot:\n%s", expected, output)
	}
}

func TestProcessYAML_DisableWorkers(t *testing.T) {
	input := `govukApplications:
  - name: account-api
    helmValues:
      workers:
        enabled: true
  - name: email-alert-service
    helmValues:
      workers:
        enabled: true
  - name: content-store
    helmValues:
      workers:
        enabled: true`

	expected := `govukApplications:
  - name: account-api
    helmValues:
      workers:
        enabled: false
  - name: email-alert-service
    helmValues:
      workers:
        enabled: true
  - name: content-store
    helmValues:
      workers:
        enabled: false`

	publishingApps := map[string]bool{
		"account-api":    true,
		"content-store":  true,
	}

	lines := strings.Split(input, "\n")
	result, count := processYAML(lines, publishingApps, false, "workers", false)
	output := strings.Join(result, "\n")

	if count != 2 {
		t.Errorf("Expected 2 changes, got %d", count)
	}

	if output != expected {
		t.Errorf("Output mismatch.\nExpected:\n%s\n\nGot:\n%s", expected, output)
	}
}

func TestProcessYAML_NoCSVFilter(t *testing.T) {
	input := `govukApplications:
  - name: account-api
    helmValues:
      appEnabled: false
  - name: email-alert-service
    helmValues:
      appEnabled: false`

	expected := `govukApplications:
  - name: account-api
    helmValues:
      appEnabled: true
  - name: email-alert-service
    helmValues:
      appEnabled: true`

	lines := strings.Split(input, "\n")
	result, count := processYAML(lines, nil, true, "app", false)
	output := strings.Join(result, "\n")

	if count != 2 {
		t.Errorf("Expected 2 changes, got %d", count)
	}

	if output != expected {
		t.Errorf("Output mismatch.\nExpected:\n%s\n\nGot:\n%s", expected, output)
	}
}

func TestProcessYAML_NoChangesNeeded(t *testing.T) {
	input := `govukApplications:
  - name: account-api
    helmValues:
      appEnabled: true`

	publishingApps := map[string]bool{
		"account-api": true,
	}

	lines := strings.Split(input, "\n")
	result, count := processYAML(lines, publishingApps, true, "app", false)
	output := strings.Join(result, "\n")

	if count != 0 {
		t.Errorf("Expected 0 changes, got %d", count)
	}

	if output != input {
		t.Errorf("Output should be unchanged.\nExpected:\n%s\n\nGot:\n%s", input, output)
	}
}

func TestProcessYAML_PreservesIndentation(t *testing.T) {
	input := `govukApplications:
  - name: account-api
    helmValues:
      arch: arm64
      appEnabled: false
      workers:
        enabled: false`

	publishingApps := map[string]bool{
		"account-api": true,
	}

	lines := strings.Split(input, "\n")
	result, _ := processYAML(lines, publishingApps, true, "app", false)
	output := strings.Join(result, "\n")

	// Check that indentation is preserved
	if !strings.Contains(output, "      appEnabled: true") {
		t.Errorf("Expected indentation to be preserved, got:\n%s", output)
	}
}

func TestProcessYAML_WorkersWithComplexStructure(t *testing.T) {
	input := `govukApplications:
  - name: email-alert-api
    helmValues:
      workers:
        enabled: false
        types:
          - command: ["sidekiq", "-C", "config/sidekiq.yml"]`

	expected := `govukApplications:
  - name: email-alert-api
    helmValues:
      workers:
        enabled: true
        types:
          - command: ["sidekiq", "-C", "config/sidekiq.yml"]`

	publishingApps := map[string]bool{
		"email-alert-api": true,
	}

	lines := strings.Split(input, "\n")
	result, count := processYAML(lines, publishingApps, true, "workers", false)
	output := strings.Join(result, "\n")

	if count != 1 {
		t.Errorf("Expected 1 change, got %d", count)
	}

	if output != expected {
		t.Errorf("Output mismatch.\nExpected:\n%s\n\nGot:\n%s", expected, output)
	}
}

func TestReadPublishingApps(t *testing.T) {
	// Create a temporary CSV file
	csvContent := `App,Type,Worker,cronJobs/cronTasks,,Should remove
account-api,Publishing,,,,
email-alert-service,Frontend,,,,
content-store,Publishing,,yes,,
frontend,Frontend,,,,
publisher,Publishing,,yes,,`

	// Write to a temp file
	tmpFile := "/tmp/test_apps.csv"
	err := writeFile(tmpFile, csvContent)
	if err != nil {
		t.Fatalf("Failed to create test CSV: %v", err)
	}
	defer deleteFile(tmpFile)

	apps, err := readPublishingApps(tmpFile)
	if err != nil {
		t.Fatalf("readPublishingApps failed: %v", err)
	}

	expectedCount := 3
	if len(apps) != expectedCount {
		t.Errorf("Expected %d Publishing apps, got %d", expectedCount, len(apps))
	}

	// Check specific apps
	if !apps["account-api"] {
		t.Error("Expected account-api to be in Publishing apps")
	}
	if !apps["content-store"] {
		t.Error("Expected content-store to be in Publishing apps")
	}
	if !apps["publisher"] {
		t.Error("Expected publisher to be in Publishing apps")
	}
	if apps["email-alert-service"] {
		t.Error("email-alert-service should not be in Publishing apps (it's Frontend)")
	}
	if apps["frontend"] {
		t.Error("frontend should not be in Publishing apps (it's Frontend)")
	}
}

// Helper functions for file operations in tests
func writeFile(path, content string) error {
	file, err := os.Create(path)
	if err != nil {
		return err
	}
	defer file.Close()
	_, err = file.WriteString(content)
	return err
}

func deleteFile(path string) {
	os.Remove(path)
}
