package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadAppCatalog(t *testing.T) {
	// Create a temporary CSV file for testing
	tmpDir := t.TempDir()
	csvPath := filepath.Join(tmpDir, "test-apps.csv")

	csvContent := `App,App,Worker,cronJobs/cronTasks,Should remove,Integration changes,Staging variations,Production
account-api,Publishing,,,,,,
asset-manager,Publishing,,,,,,
bouncer,Frontend,,,,,,
collections,Frontend,,,,,,
content-data-api,Publishing,,yes,,,,
search-api,Frontend,yes,yes,No,,,
whitehall-admin,Publishing,,yes,,,,
Relevant Publishing apps,32,,,,,,
`

	if err := os.WriteFile(csvPath, []byte(csvContent), 0644); err != nil {
		t.Fatalf("Failed to create test CSV: %v", err)
	}

	catalog, err := LoadAppCatalog(csvPath)
	if err != nil {
		t.Fatalf("LoadAppCatalog failed: %v", err)
	}

	// Test that apps were loaded
	if len(catalog.Apps) != 7 {
		t.Errorf("Expected 7 apps, got %d", len(catalog.Apps))
	}

	// Test specific apps
	tests := []struct {
		name         string
		wantCategory AppCategory
		wantWorker   bool
		wantCronJobs bool
	}{
		{"account-api", CategoryPublishing, false, false},
		{"asset-manager", CategoryPublishing, false, false},
		{"bouncer", CategoryFrontend, false, false},
		{"content-data-api", CategoryPublishing, false, true},
		{"search-api", CategoryFrontend, true, true},
		{"whitehall-admin", CategoryPublishing, false, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			app, exists := catalog.Apps[tt.name]
			if !exists {
				t.Fatalf("App %s not found in catalog", tt.name)
			}

			if app.Category != tt.wantCategory {
				t.Errorf("App %s: category = %v, want %v", tt.name, app.Category, tt.wantCategory)
			}

			if app.HasWorker != tt.wantWorker {
				t.Errorf("App %s: HasWorker = %v, want %v", tt.name, app.HasWorker, tt.wantWorker)
			}

			if app.HasCronJobs != tt.wantCronJobs {
				t.Errorf("App %s: HasCronJobs = %v, want %v", tt.name, app.HasCronJobs, tt.wantCronJobs)
			}
		})
	}
}

func TestGetAppsByWorkload(t *testing.T) {
	catalog := &AppCatalog{
		Apps: map[string]*AppInfo{
			"app1": {Name: "app1", Category: CategoryPublishing},
			"app2": {Name: "app2", Category: CategoryPublishing},
			"app3": {Name: "app3", Category: CategoryFrontend},
			"app4": {Name: "app4", Category: CategoryFrontend},
			"app5": {Name: "app5", Category: CategoryNA},
		},
	}

	tests := []struct {
		workload string
		want     int
	}{
		{"Publishing", 2},
		{"Frontend", 2},
		{"n/a", 1},
		{"Unknown", 0},
	}

	for _, tt := range tests {
		t.Run(tt.workload, func(t *testing.T) {
			apps := catalog.GetAppsByWorkload(tt.workload)
			if len(apps) != tt.want {
				t.Errorf("GetAppsByWorkload(%s) returned %d apps, want %d", tt.workload, len(apps), tt.want)
			}
		})
	}
}

func TestGetAppsForType(t *testing.T) {
	catalog := &AppCatalog{
		Apps: map[string]*AppInfo{
			"app1": {Name: "app1", Category: CategoryPublishing, HasWorker: true},
			"app2": {Name: "app2", Category: CategoryPublishing, HasWorker: false},
			"app3": {Name: "app3", Category: CategoryFrontend, HasWorker: true},
		},
	}

	tests := []struct {
		name       string
		workload   string
		toggleType string
		wantCount  int
		wantErr    bool
	}{
		{"Publishing apps", "Publishing", "apps", 2, false},
		{"Publishing workers", "Publishing", "workers", 2, false},
		{"Frontend apps", "Frontend", "apps", 1, false},
		{"Unknown workload", "Unknown", "apps", 0, true},
		{"Invalid type", "Publishing", "invalid", 0, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			apps, err := catalog.GetAppsForType(tt.workload, tt.toggleType)

			if tt.wantErr {
				if err == nil {
					t.Errorf("GetAppsForType() expected error, got nil")
				}
				return
			}

			if err != nil {
				t.Errorf("GetAppsForType() unexpected error: %v", err)
				return
			}

			if len(apps) != tt.wantCount {
				t.Errorf("GetAppsForType() returned %d apps, want %d", len(apps), tt.wantCount)
			}
		})
	}
}
