package helm

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// ValuesFile represents a Helm values file
type ValuesFile struct {
	Path  string
	Lines []string
}

// Change represents a single YAML change
type Change struct {
	AppName  string
	Path     string // YAML path like "workers.enabled"
	OldValue interface{}
	NewValue interface{}
}

// LoadValuesFile loads a Helm values YAML file
func LoadValuesFile(path string) (*ValuesFile, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read values file: %w", err)
	}
	defer file.Close()

	var lines []string
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("failed to read file: %w", err)
	}

	return &ValuesFile{
		Path:  path,
		Lines: lines,
	}, nil
}

// SaveValuesFile writes the values file back to disk
func (vf *ValuesFile) SaveValuesFile() error {
	content := strings.Join(vf.Lines, "\n") + "\n"
	if err := os.WriteFile(vf.Path, []byte(content), 0644); err != nil {
		return fmt.Errorf("failed to write file: %w", err)
	}
	return nil
}

// SetWorkerEnabled sets the workers.enabled value for an app
func (vf *ValuesFile) SetWorkerEnabled(appName string, enabled bool) (*Change, error) {
	targetValue := "true"
	if !enabled {
		targetValue = "false"
	}

	changes, oldValue, changeCount := processYAMLForApp(vf.Lines, appName, "workers", targetValue)
	if changeCount == 0 {
		return nil, nil // No change needed - already at target value or app not found
	}

	vf.Lines = changes
	return &Change{
		AppName:  appName,
		Path:     "workers.enabled",
		OldValue: oldValue,
		NewValue: targetValue,
	}, nil
}

// SetAppEnabled sets the appEnabled value for an app
func (vf *ValuesFile) SetAppEnabled(appName string, enabled bool) (*Change, error) {
	targetValue := "true"
	if !enabled {
		targetValue = "false"
	}

	changes, oldValue, changeCount := processYAMLForApp(vf.Lines, appName, "app", targetValue)
	if changeCount == 0 {
		return nil, nil // No change needed - already at target value or app not found
	}

	vf.Lines = changes
	return &Change{
		AppName:  appName,
		Path:     "appEnabled",
		OldValue: oldValue,
		NewValue: targetValue,
	}, nil
}

// processYAMLForApp processes YAML lines for a specific app and target field
func processYAMLForApp(lines []string, appName string, target string, targetValue string) ([]string, string, int) {
	changeCount := 0
	oldValue := ""
	inGovukApplications := false
	currentIndent := 0
	currentAppName := ""
	inMatchingApp := false
	inHelmValues := false
	helmValuesIndent := 0
	inWorkers := false
	workersIndent := 0
	foundField := false

	appEnabledRegex := regexp.MustCompile(`^(\s*)appEnabled:\s*(true|false)\s*$`)
	enabledRegex := regexp.MustCompile(`^(\s*)enabled:\s*(true|false)\s*$`)
	helmValuesRegex := regexp.MustCompile(`^\s*helmValues:\s*$`)
	workersRegex := regexp.MustCompile(`^\s*workers:\s*$`)
	appNameRegex := regexp.MustCompile(`^\s*-\s*name:\s*(.+?)\s*$`)

	result := []string{}

	for _, line := range lines {
		// Check if we're entering govukApplications section
		if strings.HasPrefix(strings.TrimSpace(line), "govukApplications:") {
			inGovukApplications = true
			currentIndent = len(line) - len(strings.TrimLeft(line, " \t"))
			result = append(result, line)
			continue
		}

		if inGovukApplications && strings.TrimSpace(line) != "" && !strings.HasPrefix(strings.TrimSpace(line), "#") {
			lineIndent := len(line) - len(strings.TrimLeft(line, " \t"))
			if lineIndent <= currentIndent {
				inGovukApplications = false
				currentAppName = ""
				inMatchingApp = false
				inHelmValues = false
				inWorkers = false
			}
		}

		if inGovukApplications {
			nameMatches := appNameRegex.FindStringSubmatch(line)
			if len(nameMatches) >= 2 {
				currentAppName = strings.TrimSpace(nameMatches[1])
				inHelmValues = false
				inWorkers = false
				foundField = false
				inMatchingApp = (currentAppName == appName)
			}
		}

		// Check if we're entering helmValues section (for app target)
		if target == "app" && inGovukApplications && inMatchingApp && helmValuesRegex.MatchString(line) {
			inHelmValues = true
			helmValuesIndent = len(line) - len(strings.TrimLeft(line, " \t"))
			foundField = false
		}

		// Check if we've exited helmValues section
		if inHelmValues && strings.TrimSpace(line) != "" && !strings.HasPrefix(strings.TrimSpace(line), "#") {
			lineIndent := len(line) - len(strings.TrimLeft(line, " \t"))
			if lineIndent <= helmValuesIndent {
				// Exiting helmValues - insert appEnabled if not found
				if !foundField && target == "app" {
					indent := strings.Repeat(" ", helmValuesIndent+2)
					newLine := indent + "appEnabled: " + targetValue
					result = append(result, newLine)
					changeCount++
					oldValue = "" // didn't exist before
				}
				inHelmValues = false
			}
		}

		// Check if we've exited workers section (must check BEFORE entering new section)
		if inWorkers && strings.TrimSpace(line) != "" && !strings.HasPrefix(strings.TrimSpace(line), "#") {
			lineIndent := len(line) - len(strings.TrimLeft(line, " \t"))
			if lineIndent <= workersIndent {
				// Exiting workers - insert enabled if not found
				if !foundField && target == "workers" {
					indent := strings.Repeat(" ", workersIndent+2)
					newLine := indent + "enabled: " + targetValue
					result = append(result, newLine)
					changeCount++
					oldValue = "" // didn't exist before
				}
				inWorkers = false
				foundField = false
			}
		}

		// Check if we're entering a workers section (for workers target)
		if target == "workers" && inGovukApplications && inMatchingApp && workersRegex.MatchString(line) {
			inWorkers = true
			workersIndent = len(line) - len(strings.TrimLeft(line, " \t"))
			foundField = false
		}

		// Handle appEnabled toggle (target == "app")
		if target == "app" && inGovukApplications && inMatchingApp && inHelmValues && appEnabledRegex.MatchString(line) {
			matches := appEnabledRegex.FindStringSubmatch(line)
			if len(matches) >= 3 {
				whitespace := matches[1]
				currentValue := matches[2]
				foundField = true

				if currentValue != targetValue {
					oldValue = currentValue
					newLine := whitespace + "appEnabled: " + targetValue
					result = append(result, newLine)
					changeCount++
					continue
				}
			}
		}

		// Handle workers.enabled toggle (target == "workers")
		if target == "workers" && inGovukApplications && inMatchingApp && inWorkers && enabledRegex.MatchString(line) {
			matches := enabledRegex.FindStringSubmatch(line)
			if len(matches) >= 3 {
				whitespace := matches[1]
				currentValue := matches[2]
				foundField = true

				if currentValue != targetValue {
					oldValue = currentValue
					newLine := whitespace + "enabled: " + targetValue
					result = append(result, newLine)
					changeCount++
					continue
				}
			}
		}

		result = append(result, line)
	}

	// Handle case where we reached end of file while in helmValues or workers
	if inHelmValues && !foundField && target == "app" {
		indent := strings.Repeat(" ", helmValuesIndent+2)
		newLine := indent + "appEnabled: " + targetValue
		result = append(result, newLine)
		changeCount++
		oldValue = ""
	}

	if inWorkers && !foundField && target == "workers" {
		indent := strings.Repeat(" ", workersIndent+2)
		newLine := indent + "enabled: " + targetValue
		result = append(result, newLine)
		changeCount++
		oldValue = ""
	}

	return result, oldValue, changeCount
}

// GetValuesFilePath returns the path to the values file for a given environment
func GetValuesFilePath(repoRoot, environment string) string {
	return filepath.Join(repoRoot, "charts", "app-config", fmt.Sprintf("values-%s.yaml", environment))
}
