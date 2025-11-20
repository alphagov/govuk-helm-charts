#!/usr/bin/env python3
"""CLI tool to toggle automatic_deploys_enabled for GOV.UK Helm charts."""

import argparse
import sys
from pathlib import Path
from typing import Optional

import git
import yaml

__version__ = "0.1.0"


def parse_args(args: Optional[list[str]] = None) -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        prog="toggle-deployment",
        description="Toggle automatic_deploys_enabled for GOV.UK Helm charts",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    parser.add_argument(
        "--version",
        action="version",
        version=f"%(prog)s {__version__}",
    )

    # Action group: enable or disable (mutually exclusive, required)
    action_group = parser.add_mutually_exclusive_group(required=True)
    action_group.add_argument(
        "--enable",
        action="store_true",
        help="Enable automatic deployments",
    )
    action_group.add_argument(
        "--disable",
        action="store_true",
        help="Disable automatic deployments",
    )

    # Environment group: integration, staging, or production (mutually exclusive, required)
    env_group = parser.add_mutually_exclusive_group(required=True)
    env_group.add_argument(
        "--integration",
        action="store_true",
        help="Target integration environment",
    )
    env_group.add_argument(
        "--staging",
        action="store_true",
        help="Target staging environment",
    )
    env_group.add_argument(
        "--production",
        action="store_true",
        help="Target production environment",
    )

    # Optional arguments
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be changed without making modifications",
    )

    parser.add_argument(
        "--force",
        action="store_true",
        help="Allow running with a dirty working tree (not recommended)",
    )

    return parser.parse_args(args)


def check_git_status(repo_path: Path, force: bool = False) -> None:
    """Check if the git working tree is clean.

    Args:
        repo_path: Path to the git repository
        force: If True, skip the check

    Raises:
        SystemExit: If the working tree is dirty and force is False
    """
    if force:
        return

    try:
        repo = git.Repo(repo_path)
    except git.InvalidGitRepositoryError:
        print(f"Error: {repo_path} is not a git repository", file=sys.stderr)
        sys.exit(1)

    if repo.is_dirty(untracked_files=True):
        print("Error: Working tree is dirty. Commit or stash changes first.", file=sys.stderr)
        print("Use --force to override (not recommended).", file=sys.stderr)
        sys.exit(1)


def find_image_tag_files(repo_path: Path, environment: str) -> list[Path]:
    """Find all image-tag files for a given environment.

    Args:
        repo_path: Path to the repository root
        environment: Environment name (integration, staging, production)

    Returns:
        List of Path objects for image-tag files
    """
    image_tags_dir = repo_path / "charts" / "app-config" / "image-tags" / environment

    if not image_tags_dir.exists():
        print(f"Error: Directory not found: {image_tags_dir}", file=sys.stderr)
        sys.exit(1)

    # Find all files in the environment directory (excluding subdirectories)
    files = [f for f in image_tags_dir.iterdir() if f.is_file()]

    return sorted(files)


def update_yaml_file(file_path: Path, target_value: bool, dry_run: bool = False) -> bool:
    """Update or add automatic_deploys_enabled in a YAML file.

    Args:
        file_path: Path to the YAML file
        target_value: Target value for automatic_deploys_enabled
        dry_run: If True, don't actually modify the file

    Returns:
        True if file was (would be) modified, False otherwise
    """
    # Read the file
    try:
        with open(file_path) as f:
            content = f.read()
    except Exception as e:
        print(f"Warning: Could not read {file_path}: {e}", file=sys.stderr)
        return False

    # Handle empty files
    if not content.strip():
        print(f"Skipping empty file: {file_path.name}")
        return False

    # Parse YAML
    try:
        data = yaml.safe_load(content)
    except yaml.YAMLError as e:
        print(f"Warning: Could not parse YAML in {file_path}: {e}", file=sys.stderr)
        return False

    # Handle None or non-dict data
    if data is None:
        data = {}
    elif not isinstance(data, dict):
        print(f"Warning: {file_path} does not contain a YAML dictionary", file=sys.stderr)
        return False

    # Check if we need to make changes
    current_value = data.get("automatic_deploys_enabled")
    if current_value == target_value:
        return False

    # Update the value
    data["automatic_deploys_enabled"] = target_value

    if dry_run:
        return True

    # Write back to file
    try:
        with open(file_path, "w") as f:
            yaml.safe_dump(data, f, default_flow_style=False, sort_keys=False)
        return True
    except Exception as e:
        print(f"Error: Could not write to {file_path}: {e}", file=sys.stderr)
        return False


def main() -> int:
    """Main entry point for the CLI."""
    args = parse_args()

    # Repo path is always relative to this script location
    script_dir = Path(__file__).parent
    repo_path = script_dir / ".." / ".."
    repo_path = repo_path.resolve()

    # Determine the target value and environment
    target_value = args.enable
    if args.integration:
        environment = "integration"
    elif args.staging:
        environment = "staging"
    else:
        environment = "production"

    # Display what we're about to do
    action = "Enabling" if target_value else "Disabling"
    mode = " (DRY RUN)" if args.dry_run else ""
    print(f"{action} automatic deployments for {environment}{mode}")
    print()

    # Check git status
    check_git_status(repo_path, args.force)

    # Find all image-tag files
    files = find_image_tag_files(repo_path, environment)

    if not files:
        print(f"No files found in {environment} environment")
        return 0

    print(f"Found {len(files)} files to process")
    print()

    # Process each file
    modified_count = 0
    skipped_count = 0

    for file_path in files:
        if update_yaml_file(file_path, target_value, args.dry_run):
            status = "Would modify" if args.dry_run else "Modified"
            print(f"  {status}: {file_path.name}")
            modified_count += 1
        else:
            print(f"  Skipped: {file_path.name}")
            skipped_count += 1

    # Summary
    print()
    print(f"Summary: {modified_count} modified, {skipped_count} skipped")

    if args.dry_run and modified_count > 0:
        print()
        print("This was a dry run. Run without --dry-run to apply changes.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
