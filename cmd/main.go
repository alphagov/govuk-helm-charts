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
	// Parse command-line arguments
	inputFile := flag.String("file", "", "Path to the YAML file to modify")
	csvFile := flag.String("csv", "", "Path to the CSV file with app list (optional)")
	enabledValue := flag.Bool("enabled", true, "Set appEnabled to true or false (default: true)")
	dryRun := flag.Bool("dry-run", false, "Show what would be changed without modifying the file")
	flag.Parse()

	if *inputFile == "" {
		fmt.Println("Error: -file flag is required")
		flag.Usage()
		os.Exit(1)
	}

	// Read publishing apps from CSV if provided
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

	// Read the file
	file, err := os.Open(*inputFile)
	if err != nil {
		fmt.Printf("Error opening file: %v\n", err)
		os.Exit(1)
	}
	defer file.Close()

	// Read all lines
	var lines []string
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
	}

	if err := scanner.Err(); err != nil {
		fmt.Printf("Error reading file: %v\n", err)
		os.Exit(1)
	}

	// Process the file
	modifiedLines, changeCount := processYAML(lines, publishingApps, *enabledValue, *dryRun)

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

	// Write the modified content back to the file
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

	// Skip header row, iterate through records
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

func processYAML(lines []string, publishingApps map[string]bool, enabledValue bool, dryRun bool) ([]string, int) {
	modifiedLines := make([]string, len(lines))
	copy(modifiedLines, lines)

	changeCount := 0
	inGovukApplications := false
	currentIndent := 0
	currentAppName := ""
	inMatchingApp := false

	// Regex to match 'appEnabled: true/false' (with any amount of whitespace)
	appEnabledRegex := regexp.MustCompile(`^(\s*)appEnabled:\s*(true|false)\s*$`)
	// Regex to match app name in govukApplications
	appNameRegex := regexp.MustCompile(`^\s*-\s*name:\s*(.+?)\s*$`)

	for i, line := range lines {
		// Check if we're entering govukApplications section
		if strings.HasPrefix(strings.TrimSpace(line), "govukApplications:") {
			inGovukApplications = true
			currentIndent = len(line) - len(strings.TrimLeft(line, " \t"))
			modifiedLines[i] = line
			continue
		}

		// Check if we've exited govukApplications section
		// (a line at the same or lesser indentation level that's not empty and not a comment)
		if inGovukApplications && strings.TrimSpace(line) != "" && !strings.HasPrefix(strings.TrimSpace(line), "#") {
			lineIndent := len(line) - len(strings.TrimLeft(line, " \t"))
			if lineIndent <= currentIndent {
				inGovukApplications = false
				currentAppName = ""
				inMatchingApp = false
			}
		}

		// Check for app name in govukApplications
		if inGovukApplications {
			nameMatches := appNameRegex.FindStringSubmatch(line)
			if len(nameMatches) >= 2 {
				currentAppName = strings.TrimSpace(nameMatches[1])
				// Check if this app should be modified
				if publishingApps == nil {
					// No CSV filter, process all apps
					inMatchingApp = true
				} else {
					// Check if app is in publishing apps list
					inMatchingApp = publishingApps[currentAppName]
				}
			}
		}

		// If we're in govukApplications section and in a matching app, check appEnabled
		if inGovukApplications && inMatchingApp && appEnabledRegex.MatchString(line) {
			matches := appEnabledRegex.FindStringSubmatch(line)
			if len(matches) >= 3 {
				whitespace := matches[1]
				currentValue := matches[2]
				targetValue := "true"
				if !enabledValue {
					targetValue = "false"
				}

				// Only modify if the value is different from target
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
	}

	return modifiedLines, changeCount
}
