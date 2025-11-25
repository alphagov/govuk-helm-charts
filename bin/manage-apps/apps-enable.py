#!/usr/bin/env -S uv run
# /// script
# requires-python = "==3.13"
# ///
"""
Script to enable apps in a YAML configuration file by removing 'appEnabled: false' lines.
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


def process_yaml_file(yaml_file_path, apps_to_enable):
    """
    Process the YAML file and remove 'appEnabled: false' lines for specified apps.

    This function reads the file line by line, tracking which app context we're in,
    and removes the appEnabled: false line when we're inside an app that should be enabled.
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
    # Pattern to match "appEnabled: false" (with any amount of indentation)
    app_enabled_pattern = re.compile(r'^\s*appEnabled:\s+false\s*$')

    output_lines = []
    current_app = None

    for line in lines:
        # Check if this line defines a new app name
        name_match = name_pattern.match(line)
        if name_match:
            current_app = name_match.group(1)
            output_lines.append(line)
            continue

        # Check if this line is "appEnabled: false"
        if app_enabled_pattern.match(line):
            # Only skip this line if we're in an app that should be enabled
            if current_app and current_app in apps_to_enable:
                print(f"Enabling app: {current_app} (removing 'appEnabled: false')", file=sys.stderr)
                continue  # Skip this line

        # Keep all other lines
        output_lines.append(line)

    # Write the modified content back to the file
    with open(yaml_file_path, 'w') as f:
        f.writelines(output_lines)


def main():
    parser = argparse.ArgumentParser(
        description="Enable apps in a YAML config file by removing 'appEnabled: false' lines."
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

    # Load the list of apps to enable
    apps_to_enable = load_apps_list(args.apps_file)
    print(f"Loaded {len(apps_to_enable)} apps from {args.apps_file}", file=sys.stderr)

    # Process the YAML file
    process_yaml_file(args.yaml_file, apps_to_enable)


if __name__ == '__main__':
    main()
