package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"os/exec"
	"regexp"
	"strings"

	"gopkg.in/yaml.v3"
)

type SanitizerConfig struct {
	SensitiveKeyPatterns   []*regexp.Regexp
	SensitiveValuePatterns []*regexp.Regexp
}

func NewSanitizerConfig() *SanitizerConfig {
	keyPatterns := []string{
		`(?i).*password.*`,
		`(?i).*secret.*`,
		`(?i).*token.*`,
		`(?i).*key.*`,
		`(?i).*cert.*`,
		`(?i).*certificate.*`,
		`(?i).*credential.*`,
		`(?i).*auth.*`,
		`(?i).*bearer.*`,
		`(?i).*api[_-]?key.*`,
		`(?i).*access[_-]?key.*`,
		`(?i).*private[_-]?key.*`,
		`(?i).*public[_-]?key.*`,
		`(?i).*ssh[_-]?key.*`,
		`(?i).*rsa[_-]?key.*`,
		`(?i).*jwt.*`,
		`(?i).*session.*`,
		`(?i).*cookie.*`,
		`(?i).*salt.*`,
		`(?i).*hash.*`,
		`(?i).*signature.*`,
		`(?i).*oauth.*`,
		`(?i).*client[_-]?secret.*`,
		`(?i).*client[_-]?id.*`,
		`(?i).*database[_-]?url.*`,
		`(?i).*db[_-]?url.*`,
		`(?i).*connection[_-]?string.*`,
		`(?i).*dsn.*`,
		`(?i).*webhook.*`,
		`(?i).*endpoint.*`,
		`(?i).*host.*`,
		`(?i).*user.*`,
		`(?i).*username.*`,
		`(?i).*passwd.*`,
		`(?i).*pass.*`,
		`(?i).*pin.*`,
		`(?i).*code.*`,
		`(?i).*license.*`,
		`(?i).*encryption.*`,
		`(?i).*decrypt.*`,
		`(?i).*cipher.*`,
		`(?i).*tls.*`,
		`(?i).*ssl.*`,
		`(?i).*ca[_-]?cert.*`,
		`(?i).*server[_-]?cert.*`,
		`(?i).*client[_-]?cert.*`,
	}

	valuePatterns := []string{
		`^[A-Za-z0-9+/]{20,}={0,2}$`,                                    // Base64
		`^eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*$`,           // JWT
		`^[a-fA-F0-9]{32,}$`,                                            // Hex-encoded (32+ chars)
		`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`, // UUID
		`^sk-[a-zA-Z0-9]{20,}$`,                                         // OpenAI API keys
		`^xoxb-[0-9]+-[0-9]+-[a-zA-Z0-9]+$`,                            // Slack bot tokens
		`^xoxp-[0-9]+-[0-9]+-[0-9]+-[a-zA-Z0-9]+$`,                     // Slack user tokens
		`^ghp_[a-zA-Z0-9]{36}$`,                                         // GitHub personal access tokens
		`^gho_[a-zA-Z0-9]{36}$`,                                         // GitHub OAuth tokens
		`^ghu_[a-zA-Z0-9]{36}$`,                                         // GitHub user-to-server tokens
		`^ghs_[a-zA-Z0-9]{36}$`,                                         // GitHub server-to-server tokens
		`^[A-Z0-9]{20}$`,                                                // AWS Access Key ID
		`^[A-Za-z0-9/+=]{40}$`,                                          // AWS Secret Access Key
		`^AKIA[0-9A-Z]{16}$`,                                            // AWS Access Key ID (specific)
		`^ya29\.[0-9A-Za-z\-_]+$`,                                       // Google OAuth2 tokens
		`^[0-9a-f]{40}$`,                                                // Git SHA/similar hashes
		`^[A-Za-z0-9]{32,}$`,                                            // Generic long alphanumeric strings
		`^-----BEGIN.*PRIVATE KEY-----`,                                 // Private keys
		`^-----BEGIN.*CERTIFICATE-----`,                                 // Certificates
		`^ssh-rsa\s+[A-Za-z0-9+/]+[=]{0,3}`,                           // SSH RSA keys
		`^ssh-ed25519\s+[A-Za-z0-9+/]+[=]{0,3}`,                       // SSH Ed25519 keys
		`^ecdsa-sha2-nistp[0-9]+\s+[A-Za-z0-9+/]+[=]{0,3}`,            // SSH ECDSA keys
	}

	config := &SanitizerConfig{
		SensitiveKeyPatterns:   make([]*regexp.Regexp, 0, len(keyPatterns)),
		SensitiveValuePatterns: make([]*regexp.Regexp, 0, len(valuePatterns)),
	}

	for _, pattern := range keyPatterns {
		if re, err := regexp.Compile(pattern); err == nil {
			config.SensitiveKeyPatterns = append(config.SensitiveKeyPatterns, re)
		}
	}

	for _, pattern := range valuePatterns {
		if re, err := regexp.Compile(pattern); err == nil {
			config.SensitiveValuePatterns = append(config.SensitiveValuePatterns, re)
		}
	}

	return config
}

func (c *SanitizerConfig) IsSensitiveKey(key string) bool {
	for _, pattern := range c.SensitiveKeyPatterns {
		if pattern.MatchString(key) {
			return true
		}
	}
	return false
}

func (c *SanitizerConfig) IsSensitiveValue(value string) bool {
	if len(value) == 0 {
		return false
	}

	for _, pattern := range c.SensitiveValuePatterns {
		if pattern.MatchString(value) {
			return true
		}
	}

	return false
}

func (c *SanitizerConfig) SanitizeValue(value string) string {
	if len(value) == 0 {
		return "[REDACTED]"
	}

	if len(value) <= 8 {
		return "[REDACTED]"
	}

	return fmt.Sprintf("[REDACTED-%d-chars]", len(value))
}

type Sanitizer struct {
	config *SanitizerConfig
}

func NewSanitizer() *Sanitizer {
	return &Sanitizer{
		config: NewSanitizerConfig(),
	}
}

func (s *Sanitizer) SanitizeYAMLNode(node *yaml.Node) {
	switch node.Kind {
	case yaml.DocumentNode:
		for _, child := range node.Content {
			s.SanitizeYAMLNode(child)
		}
	case yaml.MappingNode:
		for i := 0; i < len(node.Content); i += 2 {
			keyNode := node.Content[i]
			valueNode := node.Content[i+1]

			if keyNode.Kind == yaml.ScalarNode {
				key := keyNode.Value
				if s.config.IsSensitiveKey(key) {
					if valueNode.Kind == yaml.ScalarNode {
						valueNode.Value = s.config.SanitizeValue(valueNode.Value)
					}
				}
			}

			if valueNode.Kind == yaml.ScalarNode && s.config.IsSensitiveValue(valueNode.Value) {
				valueNode.Value = s.config.SanitizeValue(valueNode.Value)
			}

			s.SanitizeYAMLNode(valueNode)
		}
	case yaml.SequenceNode:
		for _, child := range node.Content {
			s.SanitizeYAMLNode(child)
		}
	case yaml.ScalarNode:
		if s.config.IsSensitiveValue(node.Value) {
			node.Value = s.config.SanitizeValue(node.Value)
		}
	}
}

func (s *Sanitizer) SanitizeYAMLFile(inputPath, outputPath string) error {
	inputFile, err := os.Open(inputPath)
	if err != nil {
		return fmt.Errorf("failed to open input file: %w", err)
	}
	defer inputFile.Close()

	var node yaml.Node
	decoder := yaml.NewDecoder(inputFile)
	if err := decoder.Decode(&node); err != nil {
		return fmt.Errorf("failed to decode YAML: %w", err)
	}

	s.SanitizeYAMLNode(&node)

	outputFile, err := os.Create(outputPath)
	if err != nil {
		return fmt.Errorf("failed to create output file: %w", err)
	}
	defer outputFile.Close()

	encoder := yaml.NewEncoder(outputFile)
	encoder.SetIndent(2)
	defer encoder.Close()

	if err := encoder.Encode(&node); err != nil {
		return fmt.Errorf("failed to encode sanitized YAML: %w", err)
	}

	return nil
}

func (s *Sanitizer) SanitizeDiffLine(line string) string {
	trimmed := strings.TrimSpace(line)
	
	if strings.HasPrefix(trimmed, "+") || strings.HasPrefix(trimmed, "-") {
		yamlPart := strings.TrimSpace(trimmed[1:])
		
		if strings.Contains(yamlPart, ":") {
			parts := strings.SplitN(yamlPart, ":", 2)
			if len(parts) == 2 {
				key := strings.TrimSpace(parts[0])
				value := strings.TrimSpace(parts[1])
				
				if s.config.IsSensitiveKey(key) || s.config.IsSensitiveValue(value) {
					sanitizedValue := s.config.SanitizeValue(value)
					return strings.Replace(line, value, sanitizedValue, 1)
				}
			}
		}
		
		words := strings.Fields(yamlPart)
		for i, word := range words {
			if s.config.IsSensitiveValue(word) {
				words[i] = s.config.SanitizeValue(word)
			}
		}
		
		if len(words) > 0 {
			newYamlPart := strings.Join(words, " ")
			if newYamlPart != yamlPart {
				return strings.Replace(line, yamlPart, newYamlPart, 1)
			}
		}
	}
	
	return line
}

func (s *Sanitizer) SanitizeDiffOutput(input io.Reader, output io.Writer) error {
	scanner := bufio.NewScanner(input)
	writer := bufio.NewWriter(output)
	defer writer.Flush()

	for scanner.Scan() {
		line := scanner.Text()
		sanitizedLine := s.SanitizeDiffLine(line)
		if _, err := writer.WriteString(sanitizedLine + "\n"); err != nil {
			return fmt.Errorf("failed to write sanitized line: %w", err)
		}
	}

	if err := scanner.Err(); err != nil {
		return fmt.Errorf("failed to read input: %w", err)
	}

	return nil
}

func (s *Sanitizer) RunHelmDiff(releaseName, namespace, chartPath, valuesFile string) error {
	tempFile, err := os.CreateTemp("", "helm-diff-sanitizer-*.yaml")
	if err != nil {
		return fmt.Errorf("failed to create temporary file: %w", err)
	}
	defer os.Remove(tempFile.Name())
	defer tempFile.Close()

	if err := s.SanitizeYAMLFile(valuesFile, tempFile.Name()); err != nil {
		return fmt.Errorf("failed to sanitize values file: %w", err)
	}

	args := []string{
		"diff", "upgrade", releaseName, chartPath,
		"--namespace", namespace,
		"--values", tempFile.Name(),
		"--suppress-secrets",
		"--allow-unreleased",
		"--no-hooks",
	}

	cmd := exec.Command("helm", args...)
	cmd.Stderr = os.Stderr

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return fmt.Errorf("failed to create stdout pipe: %w", err)
	}

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to start helm diff command: %w", err)
	}

	if err := s.SanitizeDiffOutput(stdout, os.Stdout); err != nil {
		return fmt.Errorf("failed to sanitize diff output: %w", err)
	}

	if err := cmd.Wait(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			os.Exit(exitErr.ExitCode())
		}
		return fmt.Errorf("helm diff command failed: %w", err)
	}

	return nil
}

func printUsage() {
	fmt.Fprintf(os.Stderr, `Usage: %s <command> [arguments]

Commands:
  sanitize-values <input-file> <output-file>    Sanitize a YAML values file
  diff <release-name> <namespace> <chart-path> <values-file>
                                                Run helm diff with sanitization
  diff-stdin                                   Read and sanitize helm diff output from stdin

Examples:
  %s sanitize-values values.yaml values-sanitized.yaml
  %s diff myapp default ./mychart values.yaml
  helm diff upgrade myapp ./mychart | %s diff-stdin

`, os.Args[0], os.Args[0], os.Args[0], os.Args[0])
}

func main() {
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	sanitizer := NewSanitizer()
	command := os.Args[1]

	switch command {
	case "sanitize-values":
		if len(os.Args) != 4 {
			fmt.Fprintf(os.Stderr, "Error: sanitize-values requires exactly 2 arguments\n")
			printUsage()
			os.Exit(1)
		}
		inputFile := os.Args[2]
		outputFile := os.Args[3]
		
		if err := sanitizer.SanitizeYAMLFile(inputFile, outputFile); err != nil {
			fmt.Fprintf(os.Stderr, "Error sanitizing values file: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("Successfully sanitized %s -> %s\n", inputFile, outputFile)

	case "diff":
		if len(os.Args) != 6 {
			fmt.Fprintf(os.Stderr, "Error: diff requires exactly 4 arguments\n")
			printUsage()
			os.Exit(1)
		}
		releaseName := os.Args[2]
		namespace := os.Args[3]
		chartPath := os.Args[4]
		valuesFile := os.Args[5]
		
		if err := sanitizer.RunHelmDiff(releaseName, namespace, chartPath, valuesFile); err != nil {
			fmt.Fprintf(os.Stderr, "Error running helm diff: %v\n", err)
			os.Exit(1)
		}

	case "diff-stdin":
		if len(os.Args) != 2 {
			fmt.Fprintf(os.Stderr, "Error: diff-stdin takes no arguments\n")
			printUsage()
			os.Exit(1)
		}
		
		if err := sanitizer.SanitizeDiffOutput(os.Stdin, os.Stdout); err != nil {
			fmt.Fprintf(os.Stderr, "Error sanitizing diff output: %v\n", err)
			os.Exit(1)
		}

	default:
		fmt.Fprintf(os.Stderr, "Error: unknown command '%s'\n", command)
		printUsage()
		os.Exit(1)
	}
}