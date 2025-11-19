package helm

import (
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// ValuesFile represents a Helm values file
type ValuesFile struct {
	Path    string
	Content *yaml.Node
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
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read values file: %w", err)
	}

	var node yaml.Node
	if err := yaml.Unmarshal(data, &node); err != nil {
		return nil, fmt.Errorf("failed to parse YAML: %w", err)
	}

	return &ValuesFile{
		Path:    path,
		Content: &node,
	}, nil
}

// SaveValuesFile writes the values file back to disk
func (vf *ValuesFile) SaveValuesFile() error {
	data, err := yaml.Marshal(vf.Content)
	if err != nil {
		return fmt.Errorf("failed to marshal YAML: %w", err)
	}

	if err := os.WriteFile(vf.Path, data, 0644); err != nil {
		return fmt.Errorf("failed to write file: %w", err)
	}

	return nil
}

// findApp searches for an app in the govukApplications list
func (vf *ValuesFile) findApp(appName string) *yaml.Node {
	if vf.Content.Kind != yaml.DocumentNode || len(vf.Content.Content) == 0 {
		return nil
	}

	root := vf.Content.Content[0]
	if root.Kind != yaml.MappingNode {
		return nil
	}

	// Find govukApplications
	for i := 0; i < len(root.Content); i += 2 {
		keyNode := root.Content[i]
		valueNode := root.Content[i+1]

		if keyNode.Value == "govukApplications" && valueNode.Kind == yaml.SequenceNode {
			// Search through the sequence for the app
			for _, appNode := range valueNode.Content {
				if appNode.Kind != yaml.MappingNode {
					continue
				}

				// Look for the "name" field
				for j := 0; j < len(appNode.Content); j += 2 {
					nameKey := appNode.Content[j]
					nameValue := appNode.Content[j+1]

					if nameKey.Value == "name" && nameValue.Value == appName {
						return appNode
					}
				}
			}
		}
	}

	return nil
}

// getOrCreateNestedValue gets or creates a nested value in a YAML mapping
func getOrCreateNestedValue(parent *yaml.Node, path []string) *yaml.Node {
	if len(path) == 0 {
		return parent
	}

	if parent.Kind != yaml.MappingNode {
		return nil
	}

	key := path[0]

	// Search for existing key
	for i := 0; i < len(parent.Content); i += 2 {
		keyNode := parent.Content[i]
		if keyNode.Value == key {
			valueNode := parent.Content[i+1]
			if len(path) == 1 {
				return valueNode
			}
			return getOrCreateNestedValue(valueNode, path[1:])
		}
	}

	// Key doesn't exist, create it
	keyNode := &yaml.Node{
		Kind:  yaml.ScalarNode,
		Value: key,
	}

	var valueNode *yaml.Node
	if len(path) == 1 {
		// This is the final key, create a scalar value
		valueNode = &yaml.Node{
			Kind:  yaml.ScalarNode,
			Value: "",
		}
	} else {
		// Create a mapping for nested keys
		valueNode = &yaml.Node{
			Kind:    yaml.MappingNode,
			Content: []*yaml.Node{},
		}
	}

	parent.Content = append(parent.Content, keyNode, valueNode)

	if len(path) == 1 {
		return valueNode
	}
	return getOrCreateNestedValue(valueNode, path[1:])
}

// SetWorkerEnabled sets the workers.enabled value for an app
func (vf *ValuesFile) SetWorkerEnabled(appName string, enabled bool) (*Change, error) {
	appNode := vf.findApp(appName)
	if appNode == nil {
		return nil, fmt.Errorf("app %s not found in values file", appName)
	}

	// Find or create helmValues -> workers -> enabled
	var helmValuesNode *yaml.Node
	for i := 0; i < len(appNode.Content); i += 2 {
		keyNode := appNode.Content[i]
		if keyNode.Value == "helmValues" {
			helmValuesNode = appNode.Content[i+1]
			break
		}
	}

	if helmValuesNode == nil {
		// Create helmValues node
		helmValuesKey := &yaml.Node{Kind: yaml.ScalarNode, Value: "helmValues"}
		helmValuesNode = &yaml.Node{Kind: yaml.MappingNode, Content: []*yaml.Node{}}
		appNode.Content = append(appNode.Content, helmValuesKey, helmValuesNode)
	}

	// Get or create workers.enabled
	enabledNode := getOrCreateNestedValue(helmValuesNode, []string{"workers", "enabled"})
	if enabledNode == nil {
		return nil, fmt.Errorf("failed to find or create workers.enabled for app %s", appName)
	}

	oldValue := enabledNode.Value
	newValue := "false"
	if enabled {
		newValue = "true"
	}

	enabledNode.Value = newValue
	enabledNode.Tag = "!!bool"

	return &Change{
		AppName:  appName,
		Path:     "workers.enabled",
		OldValue: oldValue,
		NewValue: newValue,
	}, nil
}

// SetAppEnabled sets the appEnabled value for an app
func (vf *ValuesFile) SetAppEnabled(appName string, enabled bool) (*Change, error) {
	appNode := vf.findApp(appName)
	if appNode == nil {
		return nil, fmt.Errorf("app %s not found in values file", appName)
	}

	// Find or create helmValues -> appEnabled
	var helmValuesNode *yaml.Node
	for i := 0; i < len(appNode.Content); i += 2 {
		keyNode := appNode.Content[i]
		if keyNode.Value == "helmValues" {
			helmValuesNode = appNode.Content[i+1]
			break
		}
	}

	if helmValuesNode == nil {
		// Create helmValues node
		helmValuesKey := &yaml.Node{Kind: yaml.ScalarNode, Value: "helmValues"}
		helmValuesNode = &yaml.Node{Kind: yaml.MappingNode, Content: []*yaml.Node{}}
		appNode.Content = append(appNode.Content, helmValuesKey, helmValuesNode)
	}

	// Get or create appEnabled
	enabledNode := getOrCreateNestedValue(helmValuesNode, []string{"appEnabled"})
	if enabledNode == nil {
		return nil, fmt.Errorf("failed to find or create appEnabled for app %s", appName)
	}

	oldValue := enabledNode.Value
	newValue := "false"
	if enabled {
		newValue = "true"
	}

	enabledNode.Value = newValue
	enabledNode.Tag = "!!bool"

	return &Change{
		AppName:  appName,
		Path:     "appEnabled",
		OldValue: oldValue,
		NewValue: newValue,
	}, nil
}

// GetValuesFilePath returns the path to the values file for a given environment
func GetValuesFilePath(repoRoot, environment string) string {
	return filepath.Join(repoRoot, "charts", "app-config", fmt.Sprintf("values-%s.yaml", environment))
}
