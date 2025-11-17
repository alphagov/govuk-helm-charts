package main

import (
	"bufio"
	"encoding/csv"
	"flag"
	"fmt"
	"os"
	"regexp"
	"strings"
)

func main() {
	inputFile := flag.String("file", "", "Path to the YAML file to modify")
	csvFile := flag.String("csv", "", "Path to the CSV file with app list (optional)")
	action := flag.String("action", "enable", "Action to perform: 'enable' or 'disable' (default: enable)")
	target := flag.String("target", "app", "Target field: 'app' for appEnabled or 'workers' for workers.enabled (default: app)")
	dryRun := flag.Bool("dry-run", false, "Show what would be changed without modifying the file")
	flag.Parse()

	if *inputFile == "" {
		fmt.Println("Error: -file flag is required")
		flag.Usage()
		os.Exit(1)
	}

	enabledValue := true
	if *action == "disable" {
		enabledValue = false
	} else if *action != "enable" {
		fmt.Printf("Error: -action must be 'enable' or 'disable', got '%s'\n", *action)
		os.Exit(1)
	}

	if *target != "app" && *target != "workers" {
		fmt.Printf("Error: -target must be 'app' or 'workers', got '%s'\n", *target)
		os.Exit(1)
	}

	var publishingApps map[string]bool
	if *csvFile != "" {
		var err error
		publishingApps, err = readPublishingApps(*csvFile)
		if err != nil {
			fmt.Printf("Error reading CSV file: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("Found %d Publishing apps in CSV\n", len(publishingApps))
	}

	file, err := os.Open(*inputFile)
	if err != nil {
		fmt.Printf("Error opening file: %v\n", err)
		os.Exit(1)
	}
	defer file.Close()

	var lines []string
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
	}

	if err := scanner.Err(); err != nil {
		fmt.Printf("Error reading file: %v\n", err)
		os.Exit(1)
	}

	modifiedLines, changeCount := processYAML(lines, publishingApps, enabledValue, *target, *dryRun)

	if changeCount == 0 {
		if *csvFile != "" {
			fmt.Println("No changes needed - no matching Publishing apps found with appEnabled to toggle")
		} else {
			fmt.Println("No changes needed - no 'appEnabled: false' found in govukApplications")
		}
		return
	}

	if *dryRun {
		fmt.Printf("\nDry run complete. Would change %d occurrence(s)\n", changeCount)
		return
	}

	err = os.WriteFile(*inputFile, []byte(strings.Join(modifiedLines, "\n")+"\n"), 0644)
	if err != nil {
		fmt.Printf("Error writing file: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Successfully updated %d occurrence(s)\n", changeCount)
}

func readPublishingApps(csvPath string) (map[string]bool, error) {
	file, err := os.Open(csvPath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	reader := csv.NewReader(file)
	records, err := reader.ReadAll()
	if err != nil {
		return nil, err
	}

	publishingApps := make(map[string]bool)

	for i, record := range records {
		if i == 0 || len(record) < 2 {
			continue
		}

		appName := strings.TrimSpace(record[0])
		appType := strings.TrimSpace(record[1])

		// Only include apps with Type "Publishing"
		if appType == "Publishing" && appName != "" {
			publishingApps[appName] = true
		}
	}

	return publishingApps, nil
}

func processYAML(lines []string, publishingApps map[string]bool, enabledValue bool, target string, dryRun bool) ([]string, int) {
	modifiedLines := make([]string, len(lines))
	copy(modifiedLines, lines)

	changeCount := 0
	inGovukApplications := false
	currentIndent := 0
	currentAppName := ""
	inMatchingApp := false
	inWorkers := false
	workersIndent := 0

	appEnabledRegex := regexp.MustCompile(`^(\s*)appEnabled:\s*(true|false)\s*$`)
	enabledRegex := regexp.MustCompile(`^(\s*)enabled:\s*(true|false)\s*$`)
	workersRegex := regexp.MustCompile(`^\s*workers:\s*$`)
	appNameRegex := regexp.MustCompile(`^\s*-\s*name:\s*(.+?)\s*$`)

	for i, line := range lines {
		// Check if we're entering govukApplications section
		if strings.HasPrefix(strings.TrimSpace(line), "govukApplications:") {
			inGovukApplications = true
			currentIndent = len(line) - len(strings.TrimLeft(line, " \t"))
			modifiedLines[i] = line
			continue
		}

		if inGovukApplications && strings.TrimSpace(line) != "" && !strings.HasPrefix(strings.TrimSpace(line), "#") {
			lineIndent := len(line) - len(strings.TrimLeft(line, " \t"))
			if lineIndent <= currentIndent {
				inGovukApplications = false
				currentAppName = ""
				inMatchingApp = false
				inWorkers = false
			}
		}

		if inGovukApplications {
			nameMatches := appNameRegex.FindStringSubmatch(line)
			if len(nameMatches) >= 2 {
				currentAppName = strings.TrimSpace(nameMatches[1])
				inWorkers = false
				if publishingApps == nil {
					inMatchingApp = true
				} else {
					inMatchingApp = publishingApps[currentAppName]
				}
			}
		}

		// Check if we've exited workers section (must check BEFORE entering new section)
		if inWorkers && strings.TrimSpace(line) != "" && !strings.HasPrefix(strings.TrimSpace(line), "#") {
			lineIndent := len(line) - len(strings.TrimLeft(line, " \t"))
			if lineIndent <= workersIndent {
				inWorkers = false
			}
		}

		// Check if we're entering a workers section (for workers target)
		if target == "workers" && inGovukApplications && inMatchingApp && workersRegex.MatchString(line) {
			inWorkers = true
			workersIndent = len(line) - len(strings.TrimLeft(line, " \t"))
		}

		// Handle appEnabled toggle (target == "app")
		if target == "app" && inGovukApplications && inMatchingApp && appEnabledRegex.MatchString(line) {
			matches := appEnabledRegex.FindStringSubmatch(line)
			if len(matches) >= 3 {
				whitespace := matches[1]
				currentValue := matches[2]
				targetValue := "true"
				if !enabledValue {
					targetValue = "false"
				}

				if currentValue != targetValue {
					newLine := whitespace + "appEnabled: " + targetValue
					modifiedLines[i] = newLine
					changeCount++

					if dryRun {
						appInfo := ""
						if currentAppName != "" {
							appInfo = fmt.Sprintf(" [%s]", currentAppName)
						}
						fmt.Printf("Line %d%s: '%s' -> '%s'\n", i+1, appInfo, strings.TrimSpace(line), strings.TrimSpace(newLine))
					}
				}
			}
		}

		// Handle workers.enabled toggle (target == "workers")
		if target == "workers" && inGovukApplications && inMatchingApp && inWorkers && enabledRegex.MatchString(line) {
			matches := enabledRegex.FindStringSubmatch(line)
			if len(matches) >= 3 {
				whitespace := matches[1]
				currentValue := matches[2]
				targetValue := "true"
				if !enabledValue {
					targetValue = "false"
				}

				if currentValue != targetValue {
					newLine := whitespace + "enabled: " + targetValue
					modifiedLines[i] = newLine
					changeCount++

					if dryRun {
						appInfo := ""
						if currentAppName != "" {
							appInfo = fmt.Sprintf(" [%s]", currentAppName)
						}
						fmt.Printf("Line %d%s (workers): '%s' -> '%s'\n", i+1, appInfo, strings.TrimSpace(line), strings.TrimSpace(newLine))
					}
				}
			}
		}
	}

	return modifiedLines, changeCount
}
