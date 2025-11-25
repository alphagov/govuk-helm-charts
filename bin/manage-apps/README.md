# App Management

A set of Python scripts to automatically enable/disable various app components by modifying an environment's values file.

The scripts manipulate the values file as a string instead of parsing it.
This is to preserve the format of the file and features such as comments, non-essential whitespace and anchors.

## Usage

Each script takes two arguments:

* path to an environment's values file (e.g. `charts/app-config/values-staging.yaml`)
* path to a file containing a list of app names to perform the operation on

Each script updates the provided YAML file in-place.

Example:

```sh
./bin/manage-apps/apps-disable.py charts/app-config/values-integration.yaml apps-publishing.txt
```

## Testing

The script `test-script.py` can be used to validate a script is behaving correctly.
This executes the desired script, parses the output and validates that the expected change has taken place.

Example:

```sh
./bin/manage-apps/test-script.py workers-disable.py charts/app-config/values-production.yaml apps-frontend.txt
```

