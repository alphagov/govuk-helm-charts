#!/bin/bash
# set -e

ENVIRONMENTS=("integration" "staging" "production")

for env in "${ENVIRONMENTS[@]}"; do
  values_filename="./charts/app-config/values-$env.yaml";

  array_length=$(yq e ".govukApplications | length - 1" "$values_filename")

  if [ "$array_length" -le 0 ] ; then
    continue;
  fi

  echo "=================== $env ===================";

  declare -i errors=0;

  # expand all the aliases
  yq 'explode(.)' "./charts/app-config/values-$env.yaml" > "lint-tmp/$env-exploded.yaml"

  for app_index in $(seq 0 "$array_length");do
    filename="./lint-tmp/$(yq ".govukApplications[$app_index].name" "$values_filename")-chart.yaml"
    chart_path=$(yq ".govukApplications[$app_index].chartPath // \"charts/generic-govuk-app\"" "$values_filename");

    echo "$app_index/$array_length: linting $filename against $chart_path";

    yq ".govukApplications[$app_index].helmValues" "lint-tmp/$env-exploded.yaml" > "$filename";

    output=$(helm lint --quiet -f "$filename" "$chart_path");
    if [[ "$output" == *"[ERROR]"* ]]; then
      echo "$output";
      errors+=1;
    fi
  done

  if [[ errors -gt 0 ]]; then
    echo "$errors lint errors found in $env values";
    exit 1
  fi

done
