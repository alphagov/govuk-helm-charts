{{- define "govuk-apps-conf.router-nginx-config" -}}
user nginx;

load_module /usr/lib/nginx/modules/ngx_http_perl_module.so;

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

  server_tokens off;

  sendfile        on;
  keepalive_timeout  65;

  perl_set $uri_lowercase 'sub {
    my $r = shift;
    return lc($r->uri);
  }';

  # Set GOVUK-Request-Id if not set
  # See http://nginx.org/en/docs/http/ngx_http_perl_module.html
  perl_modules perl/lib;
  perl_set $govuk_request_id '
    sub {
      my $r = shift;
      my $current_header = $r->header_in("GOVUK-Request-Id");
      if (defined $current_header && $current_header ne "") {
        return $current_header;
      } else {
        my $pid = $r->variable("pid");
        my $msec = $r->variable("msec");
        my $remote_addr = $r->variable("remote_addr");
        my $request_length = $r->variable("request_length");
        return "$pid-$msec-$remote_addr-$request_length";
      }
    }
  ';

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

  upstream router {
    server 127.0.0.1:3000;
  }

  server {
    listen 8080;

    proxy_set_header   Host $http_host;
    proxy_set_header   X-Real-IP $remote_addr;
    proxy_set_header   X-Forwarded-Server $host;
    proxy_set_header   X-Forwarded-Host $http_host;
    proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_read_timeout 20s;
    proxy_intercept_errors on;


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

    {{- if not (has $.Values.govukEnvironment (list "staging" "production")) }}
    auth_basic "Enter the GOV.UK username/password (not your personal username/password)";
    auth_basic_user_file /etc/nginx/htpasswd/htpasswd;
    {{- end }}

    location / {
      proxy_pass         http://router;
      proxy_redirect     off;
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

      add_header Cache-Control max-age=31536000;
      add_header "Access-Control-Allow-Origin" "*";
      add_header "Access-Control-Allow-Methods" "GET, OPTIONS";
      add_header "Access-Control-Allow-Headers" "origin, authorization";
    }

    # Endpoint that isn't cached, which is used to assert that an external
    # service can receive a response from GOV.UK origin on www hostname. It
    # is intended for pingdom monitoring
    location = /__canary__ {
      default_type application/json;
      add_header cache-control "max-age=0,no-store,no-cache";
      return 200 '{"message": "Tweet tweet"}\n';
    }

    # Endpoint for liveness and readiness checks of the nginx container.
    location = /readyz {
      return 200 'ok\n';
    }

    # If slug contains no lowercase letters then lowercase it
    # eg www.gov.uk/GOVERNMENT/GUIDANCE -> www.gov.uk/government/guidance
    # eg WWW.GOV.UK/GOVERNMENT/GUIDANCE -> www.gov.uk/government/guidance
    location ~ ^\/[A-Z]+[A-Z\W\d]+$ {
      rewrite ^(.*)$ $scheme://$host$uri_lowercase permanent;
    }

    # If slug contains mixed cases, then return 404
    location ~ ^\/(?=.*[A-Z])(?=.*[a-z]).*$ {
      return 404;
    }

    # If slug has trailing URL, direct after trimming
    location ~ ^\/(.+)\/$ {
      rewrite ^\/(.+)\/$ $scheme://$host/$1 permanent;
    }

    # If slug has trailing fullstop, direct after trimming
    location ~ ^\/(.+)\.$ {
      rewrite ^\/(.+)\.$ $scheme://$host/$1 permanent;
    }

    location = /robots.txt {
      root /usr/share/nginx/html;
    }

    # 1stline use this URL in their zendesk template
    location = /static/gov.uk_logotype_crown.png {
      absolute_redirect off;
      return 301 /media/5c810ef4ed915d43e50ce260/gov.uk_logotype_crown.png;
    }

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
