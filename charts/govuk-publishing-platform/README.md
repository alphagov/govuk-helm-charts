## Install

These instructions assume Docker Desktop.


### Install ingress-nginx

```sh
helm upgrade -i ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.ingressClassResource.default=true \
  --set controller.service.ports.http=8080 \
  --set controller.service.ports.https=8443 \
  --set controller.extraArgs=--default-ssl-certificate=ingress-nginx/dev.local
```

The ingress load balancer will listen on localhost:8080 (plain HTTP) and localhost:8443 (TLS).

Add entries to `/etc/hosts` to make it easier to view the websites in a browser. For example:

```
127.0.0.1 signon www www-origin
```

You'll need to use https://signon:8443/ for Signon and similarly for any
other apps that use Rails session cookies. (This is because Signon specifies
the `Secure` attribute when it sets the session cookie, so without TLS the
browser won't the send the cookie back. When this happens, the first thing to
fail is the Rails CSRF token validation and the app responds with `422
Unprocessable Entity`.)


### Install or update the chart.

```sh
helm dep update && helm upgrade -i foo .
```


## Copy databases from the integration environment

```sh
brew install peak/tap/s5cmd
```

```sh
s5cmd ls s3://govuk-integration-database-backups/signon-mysql/
```

```sh
echo 'CREATE DATABASE signon_production' | kubectl exec sts/mysql -- mysql -v -uroot -phunter2
s5cmd cat s3://govuk-integration-database-backups/signon-mysql/2022-12-31T05:00:01-signon_production.gz \
  | gzip -cd \
  | sed -e '/Dumping data for table `event_logs`/,/ALTER TABLE `event_logs` ENABLE KEYS/d' \
  | kubectl exec -i sts/mysql -- mysql -v -uroot -phunter2 signon_production
```


## Set up SealedSecrets

Install the kubeseal utility.

```sh
brew install kubeseal
```

Install sealsecrets controller.

```sh
helm install sealed-secrets -n kube-system --set-string fullnameOverride=sealed-secrets-controller sealed-secrets/sealed-secrets
```

Create a sealedsecret manifest.

```sh
kubectl create secret generic frontend-elections-api --dry-run=client --from-literal url="https://api.electoralcommission.org.uk/" --from-literal "key=$(pbpaste)" -ojson | kubeseal >frontend-elections-api.json
```

Install the secret.

```sh
kubectl create -f frontend-elections-api.json
```
