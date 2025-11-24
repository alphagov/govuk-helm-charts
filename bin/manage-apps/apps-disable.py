#!/usr/bin/env -S uv run
# /// script
# requires-python = "==3.13"
# ///
"""
Script to disable apps in a YAML configuration file by adding 'appEnabled: false' lines.
Preserves the original formatting of the YAML file by processing it line by line.
"""

import argparse
import re
import sys


def load_apps_list(apps_file_path):
    """Load the list of app names from the specified file."""
    try:
        with open(apps_file_path, 'r') as f:
            # Read lines, strip whitespace, and filter out empty lines
            apps = [line.strip() for line in f if line.strip()]
        return set(apps)
    except FileNotFoundError:
        print(f"Error: Apps file not found: {apps_file_path}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error reading apps file: {e}", file=sys.stderr)
        sys.exit(1)


def process_yaml_file(yaml_file_path, apps_to_disable):
    """
    Process the YAML file and disable apps by adding 'appEnabled: false' lines.

    This function reads the file line by line, tracking which app context we're in,
    and adds the appEnabled: false line when we're inside an app that should be disabled.
    Outputs the modified content to stdout.
    """
    try:
        with open(yaml_file_path, 'r') as f:
            lines = f.readlines()
    except FileNotFoundError:
        print(f"Error: YAML file not found: {yaml_file_path}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error reading YAML file: {e}", file=sys.stderr)
        sys.exit(1)

    # Pattern to match "- name: <app-name>" at top level (minimal indentation, typically 2 spaces)
    name_pattern = re.compile(r'^  -\s+name:\s+(.+?)\s*$')
    # Pattern to match "helmValues:" (where appEnabled should be added)
    helmvalues_pattern = re.compile(r'^(\s+)helmValues:\s*')
    # Pattern to match "appEnabled:" line (to avoid adding duplicates)
    app_enabled_pattern = re.compile(r'^\s*appEnabled:\s+')

    output_lines = []
    current_app = None
    waiting_for_helmvalues = False
    helmvalues_indent = None

    for i, line in enumerate(lines):
        # Check if this line defines a new app name
        name_match = name_pattern.match(line)
        if name_match:
            current_app = name_match.group(1)
            waiting_for_helmvalues = True
            output_lines.append(line)
            continue

        # Check if this line is helmValues: or repoName:
        helmvalues_match = helmvalues_pattern.match(line)
        if helmvalues_match and waiting_for_helmvalues:
            helmvalues_indent = helmvalues_match.group(1)
            output_lines.append(line)

            # Check if we should disable this app
            if current_app and current_app in apps_to_disable:
                # Look ahead to see if there's already an appEnabled line
                has_app_enabled = False
                # Check next few lines (typically within first 5 lines after helmValues)
                for j in range(i + 1, min(i + 10, len(lines))):
                    next_line = lines[j]
                    # Stop checking if we hit another top-level key at same or less indentation
                    stripped = next_line.lstrip()
                    if stripped:
                        current_indent = len(next_line) - len(stripped)
                        if current_indent <= len(helmvalues_indent):
                            break
                    if app_enabled_pattern.match(next_line):
                        has_app_enabled = True
                        break

                if not has_app_enabled:
                    # Add appEnabled: false line with proper indentation
                    # Should be indented 2 more spaces than helmValues
                    app_enabled_line = f"{helmvalues_indent}  appEnabled: false\n"
                    output_lines.append(app_enabled_line)
                    print(f"Disabling app: {current_app}", file=sys.stderr)

            waiting_for_helmvalues = False
            continue

        # Keep all other lines
        output_lines.append(line)

    # Write the modified content back to the file
    with open(yaml_file_path, 'w') as f:
        f.writelines(output_lines)


def main():
    parser = argparse.ArgumentParser(
        description="Disable apps in a YAML config file by adding 'appEnabled: false' lines."
    )
    parser.add_argument(
        'yaml_file',
        help='Path to the YAML configuration file (e.g., charts/app-config/values-integration.yaml)'
    )
    parser.add_argument(
        'apps_file',
        help='Path to the file containing list of app names (one per line)'
    )

    args = parser.parse_args()

    # Load the list of apps to disable
    apps_to_disable = load_apps_list(args.apps_file)
    print(f"Loaded {len(apps_to_disable)} apps from {args.apps_file}", file=sys.stderr)

    # Process the YAML file
    process_yaml_file(args.yaml_file, apps_to_disable)


if __name__ == '__main__':
    main()
