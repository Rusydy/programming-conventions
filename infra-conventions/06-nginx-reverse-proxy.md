# nginx as the Reverse Proxy

## Summary

nginx is the only public listener in front of every HTTP service. Give each site its own file in `conf.d/`, keep the shared settings in `snippets/`, accept TLS 1.2 and 1.3 only, drop requests for host names you do not serve, set limits and timeouts explicitly, write one JSON object per request to the access log, and run `nginx -t` before every reload. Run nginx on the host by default; run it in Compose when the whole stack is containerised. The rate limits and the web application firewall that sit on top of this layer are in the [abuse-control note](07-abuse-control-and-edge-protection.md).

## Rules

### Where nginx runs and which version

- **Default: nginx on the host**, installed from the distribution or from the nginx.org packages and run by systemd. It proxies to containers that publish on `127.0.0.1` ([Compose](05-compose-and-container-runtime.md#ports-and-networks)). The access and error logs are host files that fail2ban and logrotate can read, `ufw` covers its two ports, `certbot` needs no container, and a Docker problem does not take the edge down. This is a recorded decision ([decisions](01-principles-and-sources.md#decisions-to-review)).
- **Alternative: nginx as a Compose service**, when the stack is fully containerised and moves between hosts. It is then the only service that publishes ports (80 and 443), it reaches the applications by service name on a shared network, and it runs with the hardened recipe in [the container section](#nginx-in-a-container).
- **Run the stable line.** On 2026-11-11 stable was 1.30.6 (2026-10-14) and mainline 1.31.8 (2026-10-21). Both lines received the security fixes of 2026-10-14: the nginx advisories list five medium-severity issues fixed in 1.30.6 and 1.31.7, among them two buffer overflows, a flaw in TLS session tickets and a request-body injection in HTTP/3. Apply a nginx security release within seven days, and read the [advisory page](https://nginx.org/en/security_advisories.html) as part of the monthly routine ([checklists](14-checklists.md)).
- Leave HTTP/3 off until a client needs it. It is the newest and least exercised part of the server.

### File layout

- `/etc/nginx/nginx.conf` holds global settings only and changes rarely. Each site is one file in `conf.d/`, named after its host (`app.example.com.conf`). Reusable blocks live in `snippets/` (`tls.conf`, `security-headers.conf`, `proxy.conf`, `real-ip.conf`). The catch-all server is `conf.d/00-default.conf`, so it loads first.
- Include a snippet with `include snippets/name.conf;`. A relative path resolves against the directory of the main configuration file: a copy of `nginx.conf` placed in `/tmp` failed with `open() "/tmp/snippets/tls.conf" failed`.
- The Debian and Ubuntu packages ship `sites-available` and `sites-enabled`. Use that layout only if you start from such a package, and then use it for every site. Do not mix the two.
- No `root` directive inside a `location`; set it at the `server` level. No `if` inside a `location` except with `return` or `rewrite ... last`, the two uses the nginx wiki calls safe. Use `map` for the rest. Both are among the [pitfalls](https://github.com/nginxinc/nginx-wiki/blob/master/source/start/topics/tutorials/config_pitfalls.rst) the maintainers list.

### Defaults to set in `nginx.conf`

- `server_tokens off;` The default is `on`, which prints the version in the `Server` header and on error pages.
- Set the timeouts and the body limit instead of inheriting the defaults (`client_header_timeout` 60s, `client_body_timeout` 60s, `send_timeout` 60s, `keepalive_timeout` 75s, `client_max_body_size` 1m). The starting values in the reference are 10s, 10s, 30s, 30s and 1m. Raise `client_max_body_size` on the one location that takes uploads, not globally.
- `reset_timedout_connection on;` frees the socket of a timed-out client at once.
- The access log is JSON (see [logging](#logging)). The error log level is `warn`.

### Unknown host names

- A server block with `listen 80 default_server;` and `return 444;` answers any host name you do not serve by closing the connection without a response, which is what scanners that probe the bare IP address get. Add `listen 443 ssl default_server;` with `ssl_reject_handshake on;`, the pattern in the nginx documentation, so that a TLS client that asks for an unknown name fails the handshake.
- This also stops your certificates from answering for names you did not intend.

### TLS

- **Protocols and ciphers:** the Mozilla "intermediate" profile, version 6.0: `TLSv1.2 TLSv1.3` and its six ECDHE cipher suites, with `ssl_prefer_server_ciphers off;`. Use the "modern" profile (TLS 1.3 only) when no client you support needs 1.2. Take the lists from the [Mozilla JSON](https://ssl-config.mozilla.org/guidelines/latest.json) when it changes; do not edit them by hand.
- **Sessions:** `ssl_session_cache shared:SSL:10m;` and `ssl_session_timeout 1d;`. Set `ssl_session_tickets off;`. The nginx default is `on`, and the October 2026 advisories include a session-forgery flaw in the ticket code. With tickets off, a returning client resumes from the server-side session cache or does a full handshake. This is a recorded decision.
- **Certificates** come from Let's Encrypt through `certbot` or another ACME client, renewed by a timer, never by hand. Let's Encrypt is shortening certificate lifetimes: its 45-day `tlsserver` profile has been available since 2026-05-13, the default `classic` profile moves from 90 to 64 days on 2027-02-10 and to 45 days on 2028-02-16. Renew at about two thirds of the lifetime (a hard-coded 60-day interval stops working), use ACME Renewal Information where the client supports it, and alert on days to expiry ([monitoring](11-logging-monitoring-and-alerting.md#alerts)).
- The webroot method fits a host nginx: `certbot certonly --webroot -w /var/www/certbot -d app.example.com` writes its challenge files under `/.well-known/acme-challenge/`, which port 80 must serve (see the reference site).
- **No OCSP stapling** for Let's Encrypt certificates. Let's Encrypt announced that it would turn off its OCSP responders on 2025-08-06 and give revocation data through CRLs only, so `ssl_stapling on;` has nothing to staple.
- **HTTP to HTTPS:** every port-80 server redirects with `return 301 https://$host$request_uri;`, except the ACME path.
- **HSTS:** `Strict-Transport-Security: max-age=63072000` (two years, the Mozilla value). Add `includeSubDomains` and `preload` only after every subdomain serves HTTPS, because a preloaded domain is hard to take back.
- Enable HTTP/2 with the `http2 on;` directive (nginx 1.25.1 and later). The change log of 1.25.1 deprecates the `http2` parameter of `listen`.

### Security headers

- Put the headers in `snippets/security-headers.conf` and add `always`, so that they are also sent on error responses: `Strict-Transport-Security`, `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY` and `Referrer-Policy: strict-origin-when-cross-origin` (one of the values Mozilla lists).
- **A block that defines any `add_header` does not inherit the ones above it.** The nginx documentation says they are inherited only if the current level defines none. Include the snippet again in every `location` that adds its own header. From nginx 1.29.3 the directive `add_header_inherit merge;` appends instead of replacing; it is available in the stable line from 1.30.
- `Content-Security-Policy` belongs to the application, because only the application knows its scripts and origins. Roll it out with `Content-Security-Policy-Report-Only` first, as Mozilla recommends.
- Check the result with `curl -I`; the reference below lists the headers a response must have.

### Proxying

- Use `proxy_http_version 1.1;` and `proxy_set_header Connection "";` together with an `upstream` block that has `keepalive`, so that nginx reuses connections to the application.
- Forward the host and the real client address: `Host $host`, `X-Real-IP $remote_addr`, `X-Forwarded-Proto $scheme`, and `X-Forwarded-For $remote_addr`. **Overwrite** `X-Forwarded-For` at the edge; do not append `$proxy_add_x_forwarded_for`, or the application will read an address that the client chose.
- Forward `X-Request-ID $request_id`. The application logs it, and one identifier then joins the nginx line and the application line ([logging](11-logging-monitoring-and-alerting.md#logs)).
- Set `proxy_connect_timeout 5s`, `proxy_send_timeout` and `proxy_read_timeout` explicitly (the defaults are 60s each), to the slowest legitimate response plus a margin.
- nginx does not pass a `POST`, `PATCH` or `LOCK` request to the next upstream server once it has been sent to one, unless `non_idempotent` is set in `proxy_next_upstream`. Leave that off, so that a retry never submits a form twice.

### Real client address

- Behind a CDN or another proxy, `set_real_ip_from` lists the address ranges you trust, `real_ip_header X-Forwarded-For;` names the header and `real_ip_recursive on;` skips trusted hops (`snippets/real-ip.conf`). Without a trusted list the address is the proxy's; with a list that is too wide, any client can choose its own address and defeat rate limits.
- **Verify the address after every change.** Request the site from a machine whose address you know and look for it in `remote_addr` of the access log. If every line shows one address (a Docker gateway such as `172.17.0.1`, a load balancer), then the rate limits and fail2ban act on that one address and throttle everybody together. This happened in the test setup: a port published through a virtual machine showed the gateway address, not the client.

### Locations, methods and files

- Allow only the methods a location needs, with `limit_except GET POST { deny all; }`. A refused method gets 403. Allowing `GET` allows `HEAD`.
- Never serve hidden files: `location ~ /\.(?!well-known) { return 404; }` covers `.git`, `.env` and `.htpasswd`, and leaves `/.well-known/` alone.
- Give the one location that takes uploads its own `client_max_body_size`. A body over the limit is refused with 413 before it reaches the application.

### Logging

- The format is `log_format json escape=json '...'`, which escapes the values so that a quote in a header cannot break the line. Log `$time_iso8601`, `$request_id`, `$remote_addr`, `$host`, `$request_method`, `$request_uri`, `$status`, `$body_bytes_sent`, `$request_time`, `$upstream_response_time`, `$http_referer` and `$http_user_agent`.
- `$request_uri` includes the query string, which is what an investigation needs. It also means that nothing secret may travel in a URL ([secrets](08-secrets-and-configuration.md)). Never log request bodies.
- On a host, rotate `/var/log/nginx/*.log` with logrotate and keep the files where fail2ban reads them. In a container, the official image links `access.log` and `error.log` to stdout and stderr (observed with 1.27.5), so the Docker log driver rotates them ([logging](11-logging-monitoring-and-alerting.md#logs)).

### Changing the configuration

- Always `sudo nginx -t` (`-t` tests the configuration file) and, only if it passes, `sudo nginx -s reload` (or `systemctl reload nginx`). Run the reference checks below after a change to a site, and keep the previous file in Git, not as `.bak`.
- A configuration that includes certificate files cannot pass `nginx -t` in CI without them. Generate a throwaway certificate in the lint job, as the example pipeline does ([CI/CD](10-ci-cd-and-deployment.md)).

### nginx in a container

- Use the official image, a pinned tag and the stable line (`nginx:1.30-alpine`). Mount the configuration read-only. To change settings by environment, the image renders `/etc/nginx/templates/*.template` with `envsubst` into `conf.d/`.
- Run it with a read-only root file system and almost no capabilities. This combination was run and works with nginx 1.27.5:

```yaml
    read_only: true
    tmpfs:
      - /var/cache/nginx
      - /run
      - /tmp
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - SETGID
      - SETUID
      - NET_BIND_SERVICE
    security_opt:
      - no-new-privileges:true
```

- With every capability dropped and none added back, the start fails with `chown("/var/cache/nginx/client_temp", 101) failed (1: Operation not permitted)`. The master process starts as root, creates its temporary directories, changes their owner and then drops to the `nginx` user. `NET_BIND_SERVICE` lets it bind ports 80 and 443.
- fail2ban then has to read the logs through the Docker log files and ban in the `DOCKER-USER` chain ([abuse control](07-abuse-control-and-edge-protection.md#fail2ban)). That extra work is the reason this note prefers nginx on the host.

## Reference configuration

The files below were run with nginx 1.27.5 (`nginx -t` passed) and checked with the requests in the table that follows. The site proxies to an application on `127.0.0.1:8080`; `app.example.com` is a placeholder.

```nginx
# /etc/nginx/nginx.conf
# Global settings only. Sites live in conf.d/, shared pieces in snippets/.
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log  warn;
pid        /run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    server_tokens  off;

    # One JSON object per line, so the log pipeline needs no regular expressions.
    log_format  json  escape=json
        '{"time":"$time_iso8601","request_id":"$request_id",'
        '"remote_addr":"$remote_addr","host":"$host",'
        '"method":"$request_method","uri":"$request_uri",'
        '"status":$status,"bytes_sent":$body_bytes_sent,'
        '"request_time":$request_time,'
        '"upstream_time":"$upstream_response_time",'
        '"referer":"$http_referer","user_agent":"$http_user_agent"}';
    access_log  /var/log/nginx/access.log  json;

    # Set timeouts and sizes explicitly instead of relying on the defaults.
    client_header_timeout  10s;
    client_body_timeout    10s;
    send_timeout           30s;
    keepalive_timeout      30s;
    client_max_body_size   1m;
    reset_timedout_connection  on;

    # Request-rate and connection limits. A 10 MB zone holds about 80,000 client
    # addresses on a 64-bit build.
    limit_req_zone   $binary_remote_addr  zone=general:10m    rate=20r/s;
    limit_req_zone   $binary_remote_addr  zone=sensitive:10m  rate=30r/m;
    limit_conn_zone  $binary_remote_addr  zone=perip:10m;
    limit_req_status      429;
    limit_conn_status     429;
    limit_req_log_level   warn;
    limit_conn_log_level  warn;

    include  /etc/nginx/conf.d/*.conf;
}
```

```nginx
# /etc/nginx/conf.d/00-default.conf
# Catch-all for any host name we do not serve: scanners that hit the bare IP
# address, stale DNS records. Close the connection without an answer.
server {
    listen       80 default_server;
    listen       [::]:80 default_server;
    server_name  _;
    return       444;
}

server {
    listen       443 ssl default_server;
    listen       [::]:443 ssl default_server;
    server_name  _;
    ssl_reject_handshake  on;
}
```

```nginx
# /etc/nginx/conf.d/app.example.com.conf
upstream app_backend {
    server 127.0.0.1:8080;
    keepalive 16;
}

server {
    listen       80;
    listen       [::]:80;
    server_name  app.example.com;

    # Certificate renewal (HTTP-01 challenge); everything else goes to HTTPS.
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen       443 ssl;
    listen       [::]:443 ssl;
    http2        on;
    server_name  app.example.com;

    ssl_certificate      /etc/letsencrypt/live/app.example.com/fullchain.pem;
    ssl_certificate_key  /etc/letsencrypt/live/app.example.com/privkey.pem;
    include              snippets/tls.conf;
    include              snippets/security-headers.conf;

    limit_req   zone=general burst=40 nodelay;
    limit_conn  perip 30;

    # Pages and API reads. Other methods are refused with 403.
    location / {
        limit_except GET POST {
            deny all;
        }
        include     snippets/proxy.conf;
        proxy_pass  http://app_backend;
    }

    # The public submit endpoint. A limit_req here replaces the server-level one,
    # so the stricter zone is the only one that applies.
    location = /api/v1/submit {
        limit_except POST {
            deny all;
        }
        client_max_body_size  256k;
        limit_req             zone=sensitive burst=5 nodelay;
        include               snippets/proxy.conf;
        proxy_pass            http://app_backend;
    }

    # Hidden files and directories (.git, .env) are never served.
    location ~ /\.(?!well-known) {
        return 404;
    }
}
```

```nginx
# /etc/nginx/snippets/tls.conf
# TLS settings: Mozilla "intermediate" profile (TLS 1.2 and 1.3).
ssl_protocols              TLSv1.2 TLSv1.3;
ssl_ciphers                ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305;
ssl_prefer_server_ciphers  off;
ssl_session_timeout        1d;
ssl_session_cache          shared:SSL:10m;
ssl_session_tickets        off;
```

```nginx
# /etc/nginx/snippets/security-headers.conf
# Include this in every block that defines its own add_header, because a block
# that sets any add_header does not inherit the ones from the level above.
add_header  Strict-Transport-Security  "max-age=63072000"  always;
add_header  X-Content-Type-Options     "nosniff"           always;
add_header  X-Frame-Options            "DENY"              always;
add_header  Referrer-Policy            "strict-origin-when-cross-origin"  always;
```

```nginx
# /etc/nginx/snippets/proxy.conf
proxy_http_version  1.1;
proxy_set_header    Connection         "";
proxy_set_header    Host               $host;
proxy_set_header    X-Real-IP          $remote_addr;
proxy_set_header    X-Forwarded-For    $remote_addr;
proxy_set_header    X-Forwarded-Proto  $scheme;
proxy_set_header    X-Request-ID       $request_id;
proxy_connect_timeout  5s;
proxy_send_timeout     30s;
proxy_read_timeout     30s;
```

```nginx
# /etc/nginx/snippets/real-ip.conf
# Include only behind a proxy or CDN that we trust, and list its address ranges.
# Without this, the client address is the proxy's, and any header is spoofable.
set_real_ip_from   192.0.2.0/24;
real_ip_header     X-Forwarded-For;
real_ip_recursive  on;
```

### Checks after a change

Run these from another machine. The results are those of the test run (curl, with `--resolve` for the host name and a throwaway certificate).

| Request | Expected result |
| --- | --- |
| `GET http://app.example.com/path?x=1` | `301` to `https://app.example.com/path?x=1` |
| `GET http://other.example/` (an unserved name, port 80) | Connection closed, no response (curl exit 52) |
| TLS handshake for an unserved name | Handshake refused (curl exit 35) |
| `HEAD https://app.example.com/` | `200` over HTTP/2; `server: nginx` without a version; the four security headers |
| `DELETE /` and `PUT /` | `403` |
| `GET /.git/config` and `GET /.env` | `404`; `/.well-known/x` is not blocked |
| `GET /api/v1/submit` | `403`; only `POST` is allowed |
| 12 quick `POST /api/v1/submit` | Six answered, then six `429` (one request plus a burst of five) |
| `POST /api/v1/submit` with a 300 kB body | `413` |
| 120 parallel `GET /` (20 requests a second, burst 40) | Some `200`, the rest `429` (46 and 74 in the run) |
| Every access-log line | Valid JSON (146 of 146 in the run, checked with `jq`) |

## Sources and raw notes

Pages read on 2026-11-11:

- nginx documentation: [core module](https://nginx.org/en/docs/http/ngx_http_core_module.html) (defaults of the timeouts and `client_max_body_size`, `server_tokens`, `limit_except`, `listen`, `reset_timedout_connection`), [proxy module](https://nginx.org/en/docs/http/ngx_http_proxy_module.html) (`proxy_next_upstream` and `non_idempotent`, timeout defaults), [realip module](https://nginx.org/en/docs/http/ngx_http_realip_module.html), [ssl module](https://nginx.org/en/docs/http/ngx_http_ssl_module.html) (`ssl_reject_handshake`, tickets, protocols, session cache), [v2 module](https://nginx.org/en/docs/http/ngx_http_v2_module.html) (`http2` directive), [headers module](https://nginx.org/en/docs/http/ngx_http_headers_module.html) (`add_header` inheritance, `add_header_inherit`), [log module](https://nginx.org/en/docs/http/ngx_http_log_module.html) (`escape=json`), [rewrite module](https://nginx.org/en/docs/http/ngx_http_rewrite_module.html) (`return 444`), [command-line switches](https://nginx.org/en/docs/switches.html) (`-t`) and the [beginner's guide](https://nginx.org/en/docs/beginners_guide.html) (`-s reload`).
- nginx releases: the [download page](https://nginx.org/en/download.html), the [change log](https://nginx.org/en/CHANGES) and the [security advisories](https://nginx.org/en/security_advisories.html) (five issues fixed in 1.30.6 and 1.31.7).
- nginx wiki: [If is Evil](https://github.com/nginxinc/nginx-wiki/blob/master/source/start/topics/depth/ifisevil.rst) and [Pitfalls and Common Mistakes](https://github.com/nginxinc/nginx-wiki/blob/master/source/start/topics/tutorials/config_pitfalls.rst).
- [Mozilla Server Side TLS guidelines, version 6.0 (JSON)](https://ssl-config.mozilla.org/guidelines/latest.json): the intermediate and modern profiles, HSTS age, curves. [Mozilla Web Security guidelines](https://infosec.mozilla.org/guidelines/web_security.html): HSTS, Referrer-Policy, nosniff, Content-Security-Policy and its report-only mode.
- Let's Encrypt: [Decreasing Certificate Lifetimes to 45 Days](https://letsencrypt.org/2025/12/02/from-90-to-45) (timeline, renewal at two thirds, ARI), [Ending OCSP Support in 2025](https://letsencrypt.org/2024/12/05/ending-ocsp) (2025-08-06) and [certificate profiles](https://letsencrypt.org/docs/profiles/). [Certbot user guide](https://eff-certbot.readthedocs.io/en/stable/using.html): the webroot plugin and its challenge path.
- Docker official image README for [nginx](https://github.com/docker-library/docs/blob/master/nginx/README.md): templates and `envsubst`, read-only mode.
- Behaviour checks used the local image `nginx:1.27-alpine` (nginx 1.27.5) in Docker 29.5.2 on Colima, with a throwaway self-signed certificate, `curl` 8.7.1 and `jq`. The requests in the table were run against it. How the examples were checked, and on which versions, is in the [principles note](01-principles-and-sources.md#examples-and-how-they-were-checked).
