## Run Prometheus alert tests

- Install `promtool` on your machine: `brew install prometheus`
- Run the following command

    ```bash
    (GLOBIGNORE='*_tests.*' && promtool check rules *.yaml) &&
      promtool test rules *_tests.yaml
    ```
