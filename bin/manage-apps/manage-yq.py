#!/usr/bin/env -S uv run
# /// script
# requires-python = "==3.13"
# ///

from argparse import ArgumentParser
from csv import reader as csv_reader
from sys import stderr
from subprocess import run

def run_yq(query, yaml):
  output = run(
    ['yq', query],
    input=yaml.encode('utf-8'),
    capture_output=True
  )

  return output.stdout.decode('utf-8')

def process_app(manifest, yaml, enable):
  for app_name in manifest:
    log_action = 'enabling' if enable else 'disabling'
    print(f"{log_action} app: {app_name}", file=stderr)

    if not enable:
      query = f'(.govukApplications[] | select(.name == "{app_name}") | .helmValues.appEnabled) = false'
    else:
      query = f'del(.govukApplications[] | select(.name == "{app_name}") | .helmValues.appEnabled)'

    yaml = run_yq(query, yaml)

  return yaml

def process_worker(manifest, yaml, enable):
  for app_name in manifest:
    log_action = 'enabling' if enable else 'disabling'
    print(f"{log_action} workers for app: {app_name}", file=stderr)

    enable_str = 'true' if enable else 'false'

    query = f'(.govukApplications[] | select(.name == "{app_name}") | .helmValues.workers.enabled) = {enable_str}'

    yaml = run_yq(query, yaml)
  return yaml

def process_cron(manifest, yaml, enable):
  for app_name in manifest:
    log_action = 'enabling' if enable else 'disabling'
    print(f"{log_action} crons for app: {app_name}", file=stderr)

    if enable:
      query = f'del(.govukApplications[] | select(.name == "{app_name}") | .helmValues.cronTasks[].suspend)'
    else:
      query = f'(.govukApplications[] | select(.name == "{app_name}") | .helmValues.cronTasks[].suspend) = true'

    yaml = run_yq(query, yaml)

  return yaml

def load_manifest(path):
  apps = {}

  with open(path, 'r') as f:
    manifest_reader = csv_reader(f)

    for row in manifest_reader:
      app_name = row[0]
      if app_name == 'App':
        continue
      apps[app_name] = {
        'name': app_name,
        'phase': row[1].lower(),
        'modify_app': row[2].lower() == 'yes',
        'modify_worker': row[3].lower() == 'yes',
        'modify_cron': row[4].lower() == 'yes',
        'set': row[5].lower()
      }

      print(f"Loaded app manifest '{app_name}': {apps[app_name]}", file=stderr)

  print(f"Loaded {len(apps)} from manifest", file=stderr)

  return apps

def load_yaml_file(path):
  try:
    with open(path, "r") as f:
      contents = f.read()
  except FileNotFoundError:
    print(f"Error: YAML file not found: {path}", file=stderr)
    exit(1)
  except Exception as e:
    print(f"Error reading YAML file: {e}", file=stderr)
    exit(1)

  return contents

def main():
  parser = ArgumentParser(
    description='GOV.UK App Manager'
  )

  parser.add_argument(
    '--action',
    choices=['enable', 'disable'],
    help='action to perform'
  )

  parser.add_argument(
    '--target',
    choices=['app', 'worker', 'cron'],
    help='kind of workload to modify'
  )

  parser.add_argument(
    '--phase', '-p',
    choices=['pre-publishing', 'publishing', 'frontend', 'all'],
    help='which phase to modify'
  )

  parser.add_argument(
    '--set',
    choices=['big20', 'small6'],
    help='which set of workloads to modify'
  )

  parser.add_argument(
    '--values',
    help='environment values yaml file path'
  )

  parser.add_argument(
    '--manifest',
    help='app manifest CSV file path'
  )

  args = parser.parse_args()

  target = args.target
  enable = args.action == 'enable'

  manifest = load_manifest(args.manifest)
  filtered_manifest = {
    k: v for k, v in manifest.items()
    if (v['phase'] == args.phase or args.phase == 'all')
    and v[f'modify_{target}']
    and v['set'] == args.set
  }

  yaml_file = load_yaml_file(args.values)

  match target:
    case 'app':
      output = process_app(filtered_manifest, yaml_file, enable)
    case 'worker':
      output = process_worker(filtered_manifest, yaml_file, enable)
    case 'cron':
      output = process_cron(filtered_manifest, yaml_file, enable)
    case _:
      print(f"invalid target: {target}", file=stderr)
      exit(1)

  open(args.values, 'w').writelines(output)

if __name__ == '__main__':
  main()
