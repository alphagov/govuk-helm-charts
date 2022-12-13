# Application load tests

## Running

    k create cm chris-k6-scripts --from-file scripts && k create -f k6.yaml
    k logs -f job/chris-k6
    k delete job/chris-k6 cm/chris-k6-scripts
