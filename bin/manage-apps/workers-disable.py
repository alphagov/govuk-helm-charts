#!/usr/bin/env -S uv run
# /// script
# requires-python = "==3.13"
# ///
"""
Script to disable workers for apps in a YAML configuration file.
Changes 'enabled: true' to 'enabled: false' within workers sections.
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
    Process the YAML file and disable workers for specified apps.

    This function reads the file line by line, tracking which app context we're in,
    and changes 'enabled: true' to 'enabled: false' when we're inside a workers
    section for an app that should have workers disabled.
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
    # Pattern to match "workers:" (track indentation)
    workers_pattern = re.compile(r'^(\s*)workers:\s*$')
    # Pattern to match "enabled: true" (with any amount of indentation)
    enabled_true_pattern = re.compile(r'^(\s*)enabled:\s+true\s*$')

    output_lines = []
    current_app = None
    in_workers_section = False
    workers_indent = None

    for i, line in enumerate(lines):
        # Check if this line defines a new app name
        name_match = name_pattern.match(line)
        if name_match:
            current_app = name_match.group(1)
            in_workers_section = False
            workers_indent = None
            output_lines.append(line)
            continue

        # Check if this line starts a workers section
        workers_match = workers_pattern.match(line)
        if workers_match:
            in_workers_section = True
            workers_indent = len(workers_match.group(1))
            output_lines.append(line)
            continue

        # Check if we've exited the workers section
        # (by encountering a line with same or less indentation that isn't just whitespace)
        if in_workers_section and workers_indent is not None:
            stripped = line.lstrip()
            if stripped and not line.startswith(' ' * (workers_indent + 1)):
                # We've exited the workers section
                in_workers_section = False
                workers_indent = None

        # Check if this line is "enabled: true" within a workers section
        enabled_match = enabled_true_pattern.match(line)
        if enabled_match and in_workers_section:
            # Only modify if we're in an app that should have workers disabled
            if current_app and current_app in apps_to_disable:
                indent = enabled_match.group(1)
                modified_line = f"{indent}enabled: false\n"
                print(f"Disabling workers for app: {current_app}", file=sys.stderr)
                output_lines.append(modified_line)
                continue

        # Keep all other lines
        output_lines.append(line)

    # Write the modified content back to the file
    with open(yaml_file_path, 'w') as f:
        f.writelines(output_lines)


def main():
    parser = argparse.ArgumentParser(
        description="Disable workers for apps in a YAML config file by changing 'enabled: true' to 'enabled: false' in workers sections."
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

    # Load the list of apps to disable workers for
    apps_to_disable = load_apps_list(args.apps_file)
    print(f"Loaded {len(apps_to_disable)} apps from {args.apps_file}", file=sys.stderr)

    # Process the YAML file
    process_yaml_file(args.yaml_file, apps_to_disable)


if __name__ == '__main__':
    main()
