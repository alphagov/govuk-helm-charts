package git

import (
	"fmt"
	"os/exec"
	"strings"
)

// IsWorkingTreeDirty checks if the git working tree has uncommitted changes
func IsWorkingTreeDirty(repoPath string) (bool, error) {
	cmd := exec.Command("git", "status", "--porcelain")
	cmd.Dir = repoPath

	output, err := cmd.Output()
	if err != nil {
		return false, fmt.Errorf("failed to check git status: %w", err)
	}

	// If output is not empty, working tree is dirty
	return len(strings.TrimSpace(string(output))) > 0, nil
}
