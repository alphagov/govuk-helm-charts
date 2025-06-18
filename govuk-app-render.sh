#!/bin/bash
# set -e

mkdir -p "output/raw-charts"

# the unrendered charts are required by `helm lint`
cp -r "charts/." "output/raw-charts/"

for values_filename in ./charts/app-config/values-*.yaml; do
  env=$(yq -r ".govukEnvironment" "$values_filename")

  mkdir -p "output/rendered-charts/${env}"
  mkdir -p "output/values/${env}"

  array_length=$(yq e ".govukApplications | length - 1" "$values_filename")

  if [ "$array_length" -le 0 ] ; then
    continue;
  fi

  echo "=================== $env ===================";

  # expand all the aliases
  yq 'explode(.)' "./charts/app-config/values-$env.yaml" > "/tmp/env-values.yaml"

  yq 'del(.govukApplications)' "/tmp/env-values.yaml" > "/tmp/env-values-no-apps.yaml"

  for app_index in $(seq 0 "$array_length"); do
    app_name=$(yq ".govukApplications[$app_index].name" "$values_filename")

    chart_output="./output/rendered-charts/${env}/${app_name}"

    chart_path=$(yq ".govukApplications[$app_index].chartPath // \"charts/generic-govuk-app\"" "$values_filename");
    chart_name=$(basename "${chart_path}")

    mkdir -p "output/values/${env}/${chart_name}"

    app_values="output/values/${env}/${chart_name}/${app_name}.yaml"

    echo "$app_index/$array_length: rendering $app_name with chart $chart_path";

    yq ".govukApplications[$app_index].helmValues" "/tmp/env-values.yaml" > "$app_values";

    rm -rf /tmp/chart_out
    helm template "${app_name}" "${chart_path}" -f "/tmp/env-values-no-apps.yaml" -f "${app_values}" --output-dir "/tmp/chart_out"

    cp -r "/tmp/chart_out/${chart_name}/." "${chart_output}"
    cp "${chart_path}/Chart.yaml" "${chart_output}/"
  done

done
