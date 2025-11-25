#!/usr/bin/env -S uv run
# /// script
# requires-python = "==3.13"
# ///
"""
Script to unsuspend cron tasks for apps in a YAML configuration file.
Removes 'suspend: true' lines from all cronTasks items for apps in the provided list.
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


def process_yaml_file(yaml_file_path, apps_to_unsuspend):
    """
    Process the YAML file and unsuspend cron tasks for specified apps.

    This function reads the file line by line, tracking which app context we're in,
    and removes 'suspend: true' lines from cron task items for apps that should have tasks unsuspended.
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
    # Pattern to match "cronTasks:" or "cronJobs:" (track indentation)
    cron_section_pattern = re.compile(r'^(\s*)(cronTasks|cronJobs):\s*$')
    # Pattern to match a task item "- name: <task-name>"
    task_item_pattern = re.compile(r'^(\s*)-\s+name:\s+(.+?)\s*$')
    # Pattern to match "suspend: true" line
    suspend_true_pattern = re.compile(r'^\s*suspend:\s+true\s*$')

    output_lines = []
    current_app = None
    in_cron_section = False
    cron_section_indent = None
    in_task_item = False
    task_item_indent = None
    current_task_name = None

    for i, line in enumerate(lines):
        # Check if this line defines a new app name
        name_match = name_pattern.match(line)
        if name_match:
            current_app = name_match.group(1)
            in_cron_section = False
            cron_section_indent = None
            in_task_item = False
            task_item_indent = None
            current_task_name = None
            output_lines.append(line)
            continue

        # Check if this line starts a cronTasks or cronJobs section
        cron_match = cron_section_pattern.match(line)
        if cron_match:
            in_cron_section = True
            cron_section_indent = len(cron_match.group(1))
            in_task_item = False
            task_item_indent = None
            current_task_name = None
            output_lines.append(line)
            continue

        # Check if we've exited the cron section
        if in_cron_section and cron_section_indent is not None:
            stripped = line.lstrip()
            current_indent = len(line) - len(stripped) if stripped else None
            # Exit if we see a line with LESS indentation (not equal) and it's not a blank line
            if current_indent is not None and current_indent < cron_section_indent:
                # We've exited the cron section
                in_cron_section = False
                cron_section_indent = None
                in_task_item = False
                task_item_indent = None
                current_task_name = None

        # Check if this line is a task item within a cron section
        if in_cron_section:
            task_match = task_item_pattern.match(line)
            if task_match:
                in_task_item = True
                task_item_indent = len(task_match.group(1))
                current_task_name = task_match.group(2)
                output_lines.append(line)
                continue

            # Check if we're still in a task item
            if in_task_item and task_item_indent is not None:
                stripped = line.lstrip()
                if stripped and len(line) - len(stripped) <= task_item_indent:
                    # We've exited the task item
                    in_task_item = False
                    task_item_indent = None
                    current_task_name = None

            # Check if this is a "suspend: true" line within a task item
            if suspend_true_pattern.match(line) and in_task_item:
                # Only remove if we're in an app that should have tasks unsuspended
                if current_app and current_app in apps_to_unsuspend:
                    print(f"Unsuspending cron task '{current_task_name}' for app: {current_app}", file=sys.stderr)
                    continue  # Skip this line (don't add it to output)

        # Keep all other lines
        output_lines.append(line)

    # Write the modified content back to the file
    with open(yaml_file_path, 'w') as f:
        f.writelines(output_lines)


def main():
    parser = argparse.ArgumentParser(
        description="Unsuspend cron tasks for apps in a YAML config file by removing 'suspend: true' from cronTasks items."
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

    # Load the list of apps to unsuspend cron tasks for
    apps_to_unsuspend = load_apps_list(args.apps_file)
    print(f"Loaded {len(apps_to_unsuspend)} apps from {args.apps_file}", file=sys.stderr)

    # Process the YAML file
    process_yaml_file(args.yaml_file, apps_to_unsuspend)


if __name__ == '__main__':
    main()
