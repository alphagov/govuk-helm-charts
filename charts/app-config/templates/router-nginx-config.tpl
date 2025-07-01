{{- define "app-config.router-nginx-config" -}}
error_log  /dev/stderr warn;
pid        /tmp/nginx.pid;

events {
  worker_connections  1024;
}

http {
  include       /etc/nginx/mime.types;
  default_type  application/octet-stream;

  client_body_temp_path /tmp/client_temp;
  proxy_temp_path       /tmp/proxy_temp_path;
  fastcgi_temp_path     /tmp/fastcgi_temp;
  uwsgi_temp_path       /tmp/uwsgi_temp;
  scgi_temp_path        /tmp/scgi_temp;

  proxy_buffer_size 16k;  # Max total size of response headers.
  # n * m = max response size before spooling to disk. p95 response size should
  # fit comfortably within this in order to avoid performance issues.
  proxy_buffers 24 16k;

  resolver kube-dns.kube-system.svc.cluster.local.;

  server_tokens off;

  sendfile        on;
  keepalive_timeout  65;

  # Set GOVUK-Request-Id if not set
  map $http_govuk_request_id $govuk_request_id {
    default $http_govuk_request_id;
    ''      "$pid-$msec-$remote_addr-$request_length";
  }

  # Map the passed in X-Forwarded-Host if present and default to the server host otherwise.
  map $http_x_forwarded_host $proxy_add_x_forwarded_host {
    default $http_x_forwarded_host;
    ''      $http_host;
  }

  # This map creates a $sts_default variable for later use.
  # If this header is already set by upstream, then $sts_default will
  # be an empty string, which will later lead to:
  #    add_header Strict-Transport-Security ''
  # which will be ignored according to http://serverfault.com/a/598106
  # If the header is not set by upstream, then $sts_default will be set
  # and later uses in add_header will be effective.
  map $upstream_http_strict_transport_security $sts_default {
    '' "max-age=31536000; preload";
  }

  log_format json_event escape=json '{'
    '"@timestamp":"$time_iso8601",'
    '"body_bytes_sent":$body_bytes_sent,'
    '"bytes_sent":$bytes_sent,'
    '"govuk_request_id":"$govuk_request_id",'
    '"http_host":"$http_host",'
    '"http_referer":"$http_referer",'
    '"http_user_agent":"$http_user_agent",'
    '"http_x_forwarded_for":"$http_x_forwarded_for",'
    '"remote_addr":"$remote_addr",'
    '"remote_user":"$remote_user",'
    '"request_method":"$request_method",'
    '"request_time":$request_time,'
    '"request_uri":"$request_uri",'
    '"sent_http_content_type":"$sent_http_content_type",'
    '"sent_http_location":"$sent_http_location",'
    '"server_protocol":"$server_protocol",'
    '"status":$status,'
    '"upstream_addr":"$upstream_addr",'
    '"upstream_response_time":"$upstream_response_time"'
  '}';

  upstream router {
    server 127.0.0.1:3000;
  }

  server {
    listen 8080;

    proxy_read_timeout 20s;
    proxy_intercept_errors on;

    access_log /dev/stdout json_event;
    error_log /dev/stderr;

    add_header Strict-Transport-Security $sts_default;
    proxy_set_header GOVUK-Request-Id $govuk_request_id;

    # Hide some internal headers
    proxy_hide_header X-Rack-Cache;
    proxy_hide_header X-Runtime;
    {{- if (or (ne .Values.govukEnvironment "production") (eq .Stack "draft")) }}
    add_header X-Robots-Tag "noindex";
    {{- end }}

    add_header Permissions-Policy interest-cohort=();
    add_header X-Content-Type-Options "nosniff" always;

    {{- if ne .Stack "draft" }}
    {{- if not (has $.Values.govukEnvironment (list "staging" "production")) }}
    auth_basic "Enter the GOV.UK username/password (not your personal username/password)";
    auth_basic_user_file /etc/nginx/htpasswd/htpasswd;
    {{- end }}
    {{- end }}

    # The directives in this block don't apply when one of the more specific
    # top-level location blocks (see further down) matches.
    location / {
      # Strip cookie headers by default.
      proxy_pass         http://router;
      proxy_redirect     off;
      proxy_hide_header  Set-Cookie;

      proxy_set_header   Host $http_host;
      proxy_set_header   X-Real-IP $remote_addr;
      proxy_set_header   X-Forwarded-Server $host;
      proxy_set_header   X-Forwarded-Host $proxy_add_x_forwarded_host;
      proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header   Cookie '';

      # Redirect to trim a (single) trailing slash or dot.
      rewrite ^\/(.+)[/.]$ $scheme://$host/$1 permanent;
    }

    # Allow cookie headers to pass for services that require them
    # Requests for these services will use this location as nginx will select the most
    # specific location directive for a given request
    location ~* ^/(apply-for-a-licence|email|sign-in\/callback) {
      proxy_pass         http://router;
      proxy_redirect     off;
      proxy_set_header   Host $http_host;
      proxy_set_header   X-Real-IP $remote_addr;
      proxy_set_header   X-Forwarded-Server $host;
      proxy_set_header   X-Forwarded-Host $proxy_add_x_forwarded_host;
      proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;

      # Allow large uploads to licensify-frontend
      client_max_body_size 50M;
    }

    location /assets {
      proxy_set_header   Authorization "";
      proxy_set_header   Connection "";
      proxy_set_header   X-Real-IP $remote_addr;  # TODO: pass the actual end-client address
      proxy_hide_header  x-amz-id-2;
      proxy_hide_header  x-amz-meta-server-side-encryption;
      proxy_hide_header  x-amz-request-id;
      proxy_hide_header  x-amz-server-side-encryption;
      proxy_hide_header  x-amz-version-id;
      proxy_intercept_errors on;
      proxy_pass         https://govuk-app-assets-{{ .Values.govukEnvironment }}.s3.eu-west-1.amazonaws.com;

      add_header Cache-Control "max-age=31536000, public, immutable";
      add_header "Access-Control-Allow-Origin" "*";
      add_header "Access-Control-Allow-Methods" "GET, OPTIONS";
      add_header "Access-Control-Allow-Headers" "origin, authorization";
    }

    # Uncacheable resource for use by external probers (Pingdom).
    location = /__canary__ {
      default_type application/json;
      add_header cache-control "max-age=0,no-store,no-cache";
      return 200 '{"message": "Tweet tweet"}\n';
    }

    location = /humans.txt {
      root /usr/share/nginx/html;
    }

    # Endpoint for liveness and readiness checks of the nginx container.
    location = /readyz {
      return 200 'ok\n';
    }

    location = /robots.txt {
      root /usr/share/nginx/html;
    }

    # 1st-line User Support use this URL in their Zendesk email template.
    location = /static/gov.uk_logotype_crown.png {
      absolute_redirect off;
      return 301 /media/5c810ef4ed915d43e50ce260/gov.uk_logotype_crown.png;
    }

    {{- if ne .Stack "draft" }}

    # Google Search Console (gov.uk) verification files
    # See https://gov-uk.atlassian.net/wiki/spaces/GOVUK/pages/3585441793/Google+Search+Console for ownership of these verification tokens

    location = /googlea6393a390aadfbaa.html {
      add_header Content-Type text/html;
      return 200 'google-site-verification: googlea6393a390aadfbaa.html';
    }

    location = /googlec908b3bc32386239.html {
      add_header Content-Type text/html;
      return 200 'google-site-verification: googlec908b3bc32386239.html';
    }

    # Bing (gov.uk) verification files

    location = /BingSiteAuth.xml {
      add_header Content-Type application/xml;
      return 200 '<?xml version="1.0"?><users><user>66F6ADB7C4481C94247D1E08FA04C6A4</user></users>';
    }

    {{- end }}

    # DWP YouTube Channel Verification
    location = /dla-ending/google6db9c061ce178960.html {
      add_header Content-Type text/html;
      return 200 '';
    }

    location ~ ^/apply-for-a-licence/? {
      # Set proxy timeout to 50 seconds as a quick fix for problems
      # where civica QueryPayments calls are taking too long.
      proxy_read_timeout 50s;
      proxy_pass http://router;
      proxy_set_header   Host $http_host;
      proxy_set_header   X-Real-IP $remote_addr;
      proxy_set_header   X-Forwarded-Server $host;
      proxy_set_header   X-Forwarded-Host $proxy_add_x_forwarded_host;
      proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;

      # Licensify sends custom 500 errors, and we need to send No-Fallback: true
      # to prevent the CDN from falling back to the mirror site.
      # TODO: Put this in the Licensify nginx config when
      # we have it running on EKS
      add_header No-Fallback true always;
    }

    # Error pages
    charset utf-8;

    {{- range(list 400 401 403 404 405 406 410 422 429 500 502 503 504) }}

    error_page {{ . }} /{{ . }}.html;
    location /{{ . }}.html {
      proxy_pass https://govuk-app-assets-{{ $.Values.govukEnvironment }}.s3.eu-west-1.amazonaws.com/error_pages/{{ . }}.html;
      internal;
      proxy_set_header   Authorization "";
      proxy_set_header   Connection "";
      proxy_set_header   X-Real-IP $remote_addr;  # TODO: pass the actual end-client address
      proxy_hide_header  x-amz-id-2;
      proxy_hide_header  x-amz-meta-server-side-encryption;
      proxy_hide_header  x-amz-request-id;
      proxy_hide_header  x-amz-server-side-encryption;
      proxy_hide_header  x-amz-version-id;

      {{- if eq . 404 }}
      # Set Cache-Control headers on 404 pages since we overide those set by apps.
      # So that we dont fall through to the default provided by the CDN.
      add_header Cache-Control "public, max-age=30" always;

      # Required since the `return` directive in an `if` block above
      # interferes with the 304 functionality of Fastly so this disables
      # this Fastly functionality
      proxy_hide_header  ETag;
      proxy_hide_header  Last-Modified;
      {{- end }}
    }
    {{- end }}
  }
}
{{- end -}}
