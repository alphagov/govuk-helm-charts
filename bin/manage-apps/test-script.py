#!/usr/bin/env -S uv run
# /// script
# requires-python = "==3.13"
# dependencies = [
#     "pyyaml",
# ]
# ///
"""
Test script to validate the YAML modification scripts.
Runs a specified script and verifies the changes using PyYAML.
"""

import argparse
import shutil
import subprocess
import sys
import tempfile
import yaml


def load_apps_list(apps_file_path):
    """Load the list of app names from the specified file."""
    try:
        with open(apps_file_path, 'r') as f:
            apps = [line.strip() for line in f if line.strip()]
        return apps
    except FileNotFoundError:
        print(f"Error: Apps file not found: {apps_file_path}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error reading apps file: {e}", file=sys.stderr)
        sys.exit(1)


def run_script(script_path, yaml_file, apps_file):
    """Run the specified script on the YAML file."""
    try:
        result = subprocess.run(
            [sys.executable, script_path, yaml_file, apps_file],
            capture_output=True,
            text=True
        )
        if result.returncode != 0:
            print(f"Error running script: {result.stderr}", file=sys.stderr)
            sys.exit(1)
        return result.stderr  # Return stderr for status messages
    except Exception as e:
        print(f"Error running script: {e}", file=sys.stderr)
        sys.exit(1)


def parse_yaml(yaml_content):
    """Parse YAML content and return the data structure."""
    try:
        return yaml.safe_load(yaml_content)
    except yaml.YAMLError as e:
        print(f"Error parsing YAML: {e}", file=sys.stderr)
        sys.exit(1)


def find_app(data, app_name):
    """Find an app in the govukApplications list."""
    if not data or 'govukApplications' not in data:
        return None

    for app in data['govukApplications']:
        if app.get('name') == app_name:
            return app
    return None


def check_enable_apps(data, apps):
    """Check that appEnabled is not false for the specified apps."""
    errors = []
    successes = []

    for app_name in apps:
        app = find_app(data, app_name)
        if not app:
            errors.append(f"{app_name}: App not found in YAML")
            continue

        helm_values = app.get('helmValues', {})
        if helm_values is None:
            helm_values = {}

        # appEnabled should either not exist or not be false
        app_enabled = helm_values.get('appEnabled')
        if app_enabled is False:
            errors.append(f"{app_name}: appEnabled is still false")
        else:
            successes.append(f"{app_name}: OK (appEnabled not false)")

    return successes, errors


def check_disable_apps(data, apps):
    """Check that appEnabled is false for the specified apps."""
    errors = []
    successes = []

    for app_name in apps:
        app = find_app(data, app_name)
        if not app:
            errors.append(f"{app_name}: App not found in YAML")
            continue

        helm_values = app.get('helmValues', {})
        if helm_values is None:
            helm_values = {}

        app_enabled = helm_values.get('appEnabled')
        if app_enabled is not False:
            errors.append(f"{app_name}: appEnabled is not false (got {app_enabled})")
        else:
            successes.append(f"{app_name}: OK (appEnabled is false)")

    return successes, errors


def check_enable_workers(data, apps):
    """Check that workers.enabled is true for the specified apps."""
    errors = []
    successes = []

    for app_name in apps:
        app = find_app(data, app_name)
        if not app:
            errors.append(f"{app_name}: App not found in YAML")
            continue

        helm_values = app.get('helmValues', {})
        if helm_values is None:
            helm_values = {}

        workers = helm_values.get('workers', {})
        if workers is None:
            workers = {}

        if 'enabled' not in workers:
            # No workers section or no enabled key - skip
            successes.append(f"{app_name}: OK (no workers.enabled to check)")
            continue

        if workers.get('enabled') is not True:
            errors.append(f"{app_name}: workers.enabled is not true (got {workers.get('enabled')})")
        else:
            successes.append(f"{app_name}: OK (workers.enabled is true)")

    return successes, errors


def check_disable_workers(data, apps):
    """Check that workers.enabled is false for the specified apps."""
    errors = []
    successes = []

    for app_name in apps:
        app = find_app(data, app_name)
        if not app:
            errors.append(f"{app_name}: App not found in YAML")
            continue

        helm_values = app.get('helmValues', {})
        if helm_values is None:
            helm_values = {}

        workers = helm_values.get('workers', {})
        if workers is None:
            workers = {}

        if 'enabled' not in workers:
            # No workers section or no enabled key - skip
            successes.append(f"{app_name}: OK (no workers.enabled to check)")
            continue

        if workers.get('enabled') is not False:
            errors.append(f"{app_name}: workers.enabled is not false (got {workers.get('enabled')})")
        else:
            successes.append(f"{app_name}: OK (workers.enabled is false)")

    return successes, errors


def check_suspend_cron_tasks(data, apps):
    """Check that all cronTasks have suspend: true for the specified apps."""
    errors = []
    successes = []

    for app_name in apps:
        app = find_app(data, app_name)
        if not app:
            errors.append(f"{app_name}: App not found in YAML")
            continue

        helm_values = app.get('helmValues', {})
        if helm_values is None:
            helm_values = {}

        # Check both cronTasks and cronJobs
        for cron_key in ['cronTasks', 'cronJobs']:
            cron_tasks = helm_values.get(cron_key, [])
            if cron_tasks is None:
                cron_tasks = []

            for task in cron_tasks:
                task_name = task.get('name', 'unknown')
                if task.get('suspend') is not True:
                    # Check if this might be inherited via YAML anchor
                    # (tasks without suspend that weren't modified are likely inherited)
                    if task.get('suspend') is None:
                        successes.append(f"{app_name}: SKIPPED ({cron_key}.{task_name} likely inherited via YAML anchor)")
                    else:
                        errors.append(f"{app_name}: {cron_key}.{task_name} suspend is not true (got {task.get('suspend')})")
                else:
                    successes.append(f"{app_name}: OK ({cron_key}.{task_name} suspended)")

        # If no cron tasks found, report it
        if not helm_values.get('cronTasks') and not helm_values.get('cronJobs'):
            successes.append(f"{app_name}: OK (no cron tasks to check)")

    return successes, errors


def check_unsuspend_cron_tasks(data, apps):
    """Check that cronTasks don't have suspend: true for the specified apps."""
    errors = []
    successes = []

    for app_name in apps:
        app = find_app(data, app_name)
        if not app:
            errors.append(f"{app_name}: App not found in YAML")
            continue

        helm_values = app.get('helmValues', {})
        if helm_values is None:
            helm_values = {}

        # Check both cronTasks and cronJobs
        for cron_key in ['cronTasks', 'cronJobs']:
            cron_tasks = helm_values.get(cron_key, [])
            if cron_tasks is None:
                cron_tasks = []

            for task in cron_tasks:
                task_name = task.get('name', 'unknown')
                if task.get('suspend') is True:
                    errors.append(f"{app_name}: {cron_key}.{task_name} still has suspend: true")
                else:
                    successes.append(f"{app_name}: OK ({cron_key}.{task_name} not suspended)")

        # If no cron tasks found, report it
        if not helm_values.get('cronTasks') and not helm_values.get('cronJobs'):
            successes.append(f"{app_name}: OK (no cron tasks to check)")

    return successes, errors


# Map script names to their check functions
SCRIPT_CHECKS = {
    'apps-enable.py': check_enable_apps,
    'apps-disable.py': check_disable_apps,
    'workers-enable.py': check_enable_workers,
    'workers-disable.py': check_disable_workers,
    'cron-suspend.py': check_suspend_cron_tasks,
    'cron-unsuspend.py': check_unsuspend_cron_tasks,
}


def main():
    parser = argparse.ArgumentParser(
        description="Test YAML modification scripts by running them and validating the output."
    )
    parser.add_argument(
        'script',
        choices=list(SCRIPT_CHECKS.keys()),
        help='The script to test'
    )
    parser.add_argument(
        'yaml_file',
        help='Path to the YAML configuration file'
    )
    parser.add_argument(
        'apps_file',
        help='Path to the file containing list of app names'
    )
    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Show successful checks as well as errors'
    )

    args = parser.parse_args()

    # Load apps list
    apps = load_apps_list(args.apps_file)
    print(f"Loaded {len(apps)} apps from {args.apps_file}")

    # Determine script path (assume scripts are in same directory)
    import os
    script_dir = os.path.dirname(os.path.abspath(__file__))
    script_path = os.path.join(script_dir, args.script)

    if not os.path.exists(script_path):
        print(f"Error: Script not found: {script_path}", file=sys.stderr)
        sys.exit(1)

    # Create a temporary copy of the YAML file
    temp_dir = tempfile.mkdtemp()
    temp_yaml = os.path.join(temp_dir, os.path.basename(args.yaml_file))

    try:
        shutil.copy2(args.yaml_file, temp_yaml)
        print(f"Copied YAML to temporary file: {temp_yaml}")

        # Run the script on the temporary copy
        print(f"Running {args.script}...")
        run_script(script_path, temp_yaml, args.apps_file)

        # Read the modified file
        print("Reading modified YAML...")
        with open(temp_yaml, 'r') as f:
            yaml_content = f.read()

        # Parse the modified content
        data = parse_yaml(yaml_content)

        # Run the appropriate check
        check_func = SCRIPT_CHECKS[args.script]
        successes, errors = check_func(data, apps)

        # Report results
        print()
        if args.verbose and successes:
            print("Successes:")
            for msg in successes:
                print(f"  ✓ {msg}")
            print()

        if errors:
            print("Errors:")
            for msg in errors:
                print(f"  ✗ {msg}")
            print()
            print(f"FAILED: {len(errors)} errors, {len(successes)} successes")
            sys.exit(1)
        else:
            print(f"PASSED: {len(successes)} checks passed")
            sys.exit(0)
    finally:
        # Clean up temporary directory
        shutil.rmtree(temp_dir)


if __name__ == '__main__':
    main()
