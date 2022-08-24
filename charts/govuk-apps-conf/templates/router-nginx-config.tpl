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

  log_format json_event '{ "@timestamp": "$time_iso8601", '
                       '"remote_addr": "$remote_addr", '
                       '"remote_user": "$remote_user", '
                       '"body_bytes_sent": $body_bytes_sent, '
                       '"bytes_sent": $bytes_sent, '
                       '"request_time": $request_time, '
                       '"upstream_response_time": "$upstream_response_time", '
                       '"upstream_addr": "$upstream_addr", '
                       '"gzip_ratio": "$gzip_ratio", '
                       '"sent_http_x_cache": "$sent_http_x_cache", '
                       '"sent_http_location": "$sent_http_location", '
                       '"sent_http_content_type": "$sent_http_content_type", '
                       '"http_host": "$http_host", '
                       '"server_name": "$server_name", '
                       '"server_port": "$server_port", '
                       '"status": $status, '
                       '"request": "$request", '
                       '"request_method": "$request_method", '
                       '"http_referer": "$http_referer", '
                       '"http_user_agent": "$http_user_agent", '
                       '"govuk_request_id": "$http_govuk_request_id", '
                       '"govuk_original_url": "$http_govuk_original_url", '
                       '"govuk_dependency_resolution_source_content_id": "$http_govuk_dependency_resolution_source_content_id", '
                       '"varnish_id": "$http_x_varnish", '
                       '"ssl_protocol": "$ssl_protocol", '
                       '"ssl_cipher": "$ssl_cipher", '
                       '"http_x_forwarded_for": "$http_x_forwarded_for" }';

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

    {{- if not (has $.Values.govukEnvironment (list "staging" "production")) }}
    auth_basic "Enter the GOV.UK username/password (not your personal username/password)";
    auth_basic_user_file /etc/nginx/htpasswd/htpasswd;
    {{- end }}

    # The directives in this block don't apply when one of the more specific
    # top-level location blocks (see further down) matches.
    location / {
      # Strip cookie headers by default.
      proxy_pass         http://router;
      proxy_redirect     off;
      proxy_hide_header  Set-Cookie;
      proxy_set_header   Cookie '';

      # If slug is ALL CAPS then lowercase it, e.g.:
      #   /GOVERNMENT/GUIDANCE -> /government/guidance
      #   /GoVeRnMeNt/gUiDaNcE -> /GoVeRnMeNt/gUiDaNcE (but see next rule below)
      location ~ ^\/[A-Z]+[A-Z\W\d]+$ {
        rewrite ^(.*)$ $scheme://$host$uri_lowercase permanent;
      }

      # If slug contains mIxEd CaSe, then return 404.
      location ~ ^\/(?=.*[A-Z])(?=.*[a-z]).*$ {
        return 404;
      }

      # If slug has trailing URL, direct after trimming.
      location ~ ^\/(.+)\/$ {
        rewrite ^\/(.+)\/$ $scheme://$host/$1 permanent;
      }

      # If slug has trailing fullstop, direct after trimming.
      location ~ ^\/(.+)\.$ {
        rewrite ^\/(.+)\.$ $scheme://$host/$1 permanent;
      }
    }

    # Allow cookie headers to pass for services that require them
    # Requests for these services will use this location as nginx will select the most
    # specific location directive for a given request
    location ~* ^/(apply-for-a-licence|email|sign-in\/callback) {
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

      add_header Cache-Control "max-age=31536000, public, immutable";
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
