package config

import (
	"encoding/csv"
	"fmt"
	"os"
	"strings"
)

// AppCategory represents the category of an application (Publishing, Frontend, etc.)
type AppCategory string

const (
	CategoryPublishing AppCategory = "Publishing"
	CategoryFrontend   AppCategory = "Frontend"
	CategoryNA         AppCategory = "n/a"
)

// AppInfo represents information about an application from the CSV
type AppInfo struct {
	Name         string
	Category     AppCategory
	HasWorker    bool
	HasCronJobs  bool
	ShouldRemove bool
}

// AppCatalog holds all application information from the CSV
type AppCatalog struct {
	Apps map[string]*AppInfo // key is app name
}

// LoadAppCatalog loads and parses the apps.csv file
func LoadAppCatalog(csvPath string) (*AppCatalog, error) {
	file, err := os.Open(csvPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open CSV file: %w", err)
	}
	defer file.Close()

	reader := csv.NewReader(file)
	records, err := reader.ReadAll()
	if err != nil {
		return nil, fmt.Errorf("failed to read CSV: %w", err)
	}

	if len(records) < 2 {
		return nil, fmt.Errorf("CSV file is empty or has no data rows")
	}

	// Parse header to find column indices
	_ = records[0]       // header row
	categoryIdx := 1     // Second column is the category
	workerIdx := 2       // Third column is Worker
	cronJobsIdx := 3     // Fourth column is cronJobs/cronTasks
	shouldRemoveIdx := 4 // Fifth column is Should remove

	catalog := &AppCatalog{
		Apps: make(map[string]*AppInfo),
	}

	// Parse each row (skip header)
	for _, record := range records[1:] {
		if len(record) < 2 {
			continue // Skip incomplete rows
		}

		appName := strings.TrimSpace(record[0])
		if appName == "" || strings.Contains(appName, "Relevant") {
			continue // Skip empty rows and summary rows
		}

		category := strings.TrimSpace(record[categoryIdx])

		appInfo := &AppInfo{
			Name:         appName,
			Category:     AppCategory(category),
			HasWorker:    false,
			HasCronJobs:  false,
			ShouldRemove: false,
		}

		// Check if app has worker
		if workerIdx < len(record) {
			workerValue := strings.TrimSpace(record[workerIdx])
			appInfo.HasWorker = workerValue == "yes" || strings.Contains(strings.ToLower(workerValue), "yes")
		}

		// Check if app has cron jobs
		if cronJobsIdx < len(record) {
			cronJobsValue := strings.TrimSpace(record[cronJobsIdx])
			appInfo.HasCronJobs = cronJobsValue == "yes" || strings.Contains(strings.ToLower(cronJobsValue), "yes")
		}

		// Check if app should be removed
		if shouldRemoveIdx < len(record) {
			shouldRemoveValue := strings.TrimSpace(record[shouldRemoveIdx])
			appInfo.ShouldRemove = shouldRemoveValue == "yes" || strings.Contains(strings.ToLower(shouldRemoveValue), "yes")
		}

		catalog.Apps[appName] = appInfo
	}

	if len(catalog.Apps) == 0 {
		return nil, fmt.Errorf("no valid applications found in CSV")
	}

	return catalog, nil
}

// GetAppsByWorkload returns all apps that match the given workload category
func (c *AppCatalog) GetAppsByWorkload(workload string) []*AppInfo {
	var apps []*AppInfo

	// Normalize workload to match category
	workloadCategory := AppCategory(workload)

	for _, app := range c.Apps {
		if app.Category == workloadCategory {
			apps = append(apps, app)
		}
	}

	return apps
}

// GetAppsForType returns apps that match the type filter (workers, apps, etc.)
func (c *AppCatalog) GetAppsForType(workload string, toggleType string) ([]*AppInfo, error) {
	workloadApps := c.GetAppsByWorkload(workload)

	if len(workloadApps) == 0 {
		return nil, fmt.Errorf("no apps found for workload: %s", workload)
	}

	// Validate type
	switch toggleType {
	case "workers", "apps":
		// Valid types
	default:
		return nil, fmt.Errorf("unknown type: %s (supported: workers, apps)", toggleType)
	}

	// For both workers and apps types, return all apps in the workload
	// The YAML mutation layer will handle apps that don't have the specific
	// field (workers.enabled or appEnabled) with appropriate warnings
	return workloadApps, nil
}
