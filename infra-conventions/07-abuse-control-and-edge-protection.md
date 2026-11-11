# Abuse Control and Edge Protection

## Summary

A public endpoint is attacked by scripts at machine speed, often from many addresses. Defend it in layers: nginx limits the request rate and the open connections of each client address, fail2ban bans addresses that keep tripping those limits, a web application firewall (the OWASP Core Rule Set) flags known attack patterns, the application throttles per account, and the database account limits what a successful injection can do. No layer repairs a SQL injection bug. The repair is parameterised queries in the application, and the layers here buy time, shrink the damage and make the attack visible. Roll every control out in an observe-only mode first, so that it never blocks real customers by surprise.

## Rules

### What each layer can and cannot do

| Layer | What it does | What it cannot do |
| --- | --- | --- |
| nginx `limit_req` and `limit_conn` | Caps the request rate and the open connections per client address; slows a brute-force script | Does not read the content of a request. Many addresses, or one address shared by many users, defeat a per-address key |
| Method, size and timeout rules | Refuses methods, bodies and slow senders the endpoint never needs | Does not tell a good request from a bad one of the right shape |
| fail2ban | Bans an address that keeps hitting the limits or probing for files | Reacts after the fact, and bans addresses, not people |
| WAF with the OWASP CRS | Scores each request against known attack patterns, SQL injection included | Misses what it has no rule for, produces false positives that need tuning, and is not a substitute for parameterised queries |
| The application | Parameterised queries, per-account throttling and lockout, CAPTCHA, multi-factor authentication | |
| The database account | Limits what injected SQL can read or change ([databases](09-databases-and-data-stores.md#accounts-and-privileges)) | Does not stop the injection |
| Network and host | Keeps the database unreachable and the exposed ports few ([server](03-linux-server-baseline.md#firewall)) | |
| Logs and alerts | Make the attack visible while it happens ([monitoring](11-logging-monitoring-and-alerting.md#security-signals)) | |

- OWASP's SQL injection cheat sheet names parameterised queries as the primary defence and least privilege as hardening: "do not assign DBA or admin type access to your application accounts". Treat every report of injection as an application defect first, and use the layers below to contain it while the fix ships.
- OWASP's authentication cheat sheet ties the failed-login counter to the account, not to the source address, "to prevent an attacker from making login attempts from a large number of different IP addresses". A limit in nginx is therefore a first brake. The lockout or throttle per account belongs to the application, which also needs a way to stop a lockout from becoming a denial of service against the victim.

### Rate limiting in nginx

- Define the zones once in `http {}` and apply them in the `location`: a general zone for the site and a stricter zone for each sensitive endpoint (login, one-time password, password reset, public submit forms, search). The [reference configuration](06-nginx-reverse-proxy.md#reference-configuration) has both.
- Key the zones on `$binary_remote_addr`, which takes 4 bytes for IPv4 and 16 for IPv6. A 10 MB zone holds about 80,000 states on a 64-bit build (the module documentation counts 8 thousand per megabyte). When the zone is full, the oldest state is dropped, and if a new one still does not fit the request is refused.
- Set the rate in requests per second (`rate=20r/s`) or per minute below one a second (`rate=30r/m`). `burst=N nodelay` lets N requests above the rate through at once and refuses the rest; without `nodelay` the excess is delayed instead. Starting values:

| Zone | Applied to | Rate | Burst | Reasoning |
| --- | --- | --- | --- | --- |
| `general` | the whole site | 20 requests a second | 40 | A page load fetches many assets at once |
| `sensitive` | login, OTP, reset, submit | 30 requests a minute | 5 | A person submits a form rarely; a script submits it constantly |
| `perip` (connections) | the whole site | 30 open connections | | One browser opens a handful |

- These numbers are starting values and a recorded decision. Measure first (see the next rule), then set the rate above the legitimate peak.
- **Run each limit in dry-run mode before enforcing it.** `limit_req_dry_run on;` (nginx 1.17.1 and later) does not refuse anything, but counts the excess and logs `limiting requests, dry run, excess: ...` lines at the configured level. In a test, 12 quick requests all passed to the upstream and the error log carried the dry-run lines. Run it for a week of real traffic, find the legitimate peak per address in the log, set the rate above it, then remove the directive. `limit_conn_dry_run` exists too.
- Return `429` instead of the default `503` (`limit_req_status 429;`, `limit_conn_status 429;`), and log at `warn` (`limit_req_log_level warn;`, default `error`), so that a refusal is distinguishable from a failing server.
- A `limit_req` in a `location` replaces the ones of the level above; they are inherited only when the current level has none. If a location needs both zones, repeat the general one there.
- **Many users can share one address.** Mobile networks that use carrier-grade NAT, offices and schools put hundreds of people behind one address. A per-address limit set too low blocks them all, and a botnet with thousands of addresses passes under it. Keep the limit above the legitimate peak, and rely on the application for per-account limits.
- The address must be the client's. Behind a CDN or a Docker network, check that `remote_addr` in the access log is the real client ([real client address](06-nginx-reverse-proxy.md#real-client-address)).

### Request hygiene on sensitive endpoints

- Allow only the methods the endpoint uses (`limit_except POST { deny all; }` for a submit endpoint) and set `client_max_body_size` to the size the form needs, not to the global default.
- Keep `client_header_timeout`, `client_body_timeout` and `send_timeout` at seconds, not minutes. OWASP's denial-of-service cheat sheet recommends a minimum ingress data rate with request-read timeouts against slow-sending attacks, and an absolute connection timeout. nginx offers timeouts rather than a minimum rate; read the logs for the genuine slow senders before you shorten them.
- Never expose the application server's port directly, or an admin interface, on a public address. Everything reaches the application through nginx ([Compose](05-compose-and-container-runtime.md#ports-and-networks)).

### fail2ban

- fail2ban runs on the host and bans an address in the firewall after a number of matching log lines. It fits nginx on the host. Install it from the distribution; the latest upstream release on 2026-11-11 was 1.1.1.
- **Never edit `jail.conf`.** Its header says it will probably be overwritten in a distribution update and asks for `jail.local` or files in `jail.d/`. The stock filters and jails for nginx are already there: `nginx-limit-req` (reads the `limit_req` lines in the error log), `nginx-botsearch` (repeated requests for files that do not exist) and `nginx-http-auth`.
- The stock `nginx-limit-req` filter matched the real refusal lines of the test run and does not match the dry-run lines, so a trial never bans anybody.

```ini
# /etc/fail2ban/jail.local
[DEFAULT]
bantime           = 1h
findtime          = 10m
maxretry          = 5
bantime.increment = true
bantime.maxtime   = 1w
ignoreip          = 127.0.0.1/8 ::1 203.0.113.10

[nginx-limit-req]
enabled  = true
maxretry = 10
findtime = 1m

[nginx-botsearch]
enabled  = true
```

- `bantime.increment = true` makes the ban longer for each repeat (the formula doubles it by default, up to `bantime.maxtime`). Put the addresses of your offices and monitors in `ignoreip`, or you will ban yourself.
- A ban acts on the address that appears in the log. Behind a CDN the packets come from the CDN, so a ban in the host firewall would block the CDN. Use the CDN's own rules there.
- With nginx in a container, published traffic does not pass the firewall chain that fail2ban uses by default. Docker documents `DOCKER-USER` as the chain for your own rules, and the `chain` parameter of the fail2ban jail names the chain its actions use. The container's log files also have to be readable by fail2ban. This was not run; it is the reason nginx runs on the host by default.
- Check the jails with `sudo fail2ban-client status nginx-limit-req`, and lift a ban with `sudo fail2ban-client set nginx-limit-req unbanip ADDRESS`.
- Do not write your own fail2ban filters for SQL keywords in URLs. The patterns change faster than a filter, and a rule set exists for that ([next section](#web-application-firewall)).

### Web application firewall

- A WAF is the second line for injection, never the first. Put one in front of every public application that accepts user data, once the rate limits work.
- **Choose how to get one:**
  - A managed WAF or CDN in front of the server is the least work. Check where it routes traffic against your data-protection duties: OWASP notes that many providers route traffic through other countries.
  - ModSecurity or Coraza as an nginx module needs a library and a connector, built as a dynamic module (`--with-compat`) or installed from a third-party package. Both connector READMEs describe a build step. Avoid this unless you already maintain nginx builds.
  - **The OWASP CRS container image (`owasp/modsecurity-crs`, the nginx variant) is the default for a self-hosted stack.** In its default configuration it is a reverse proxy: it needs a `BACKEND`, and you place it between nginx and the application. No module to build.
- Use a **stable tag**, never a rolling tag; the image documentation says rolling tags should not be used in production. A stable tag is `<CRS version>-<web server>-<date>`.
- The settings are environment variables of the image: `BACKEND`, `MODSEC_RULE_ENGINE` (`On`, `Off` or `DetectionOnly`), `BLOCKING_PARANOIA` (default 1), `ANOMALY_INBOUND` (default 5) and `ANOMALY_OUTBOUND` (default 4). This snippet was not run:

```yaml
  waf:
    image: owasp/modsecurity-crs:${CRS_TAG:?set CRS_TAG to a stable tag}
    restart: unless-stopped
    ports:
      - "127.0.0.1:8081:8080"
    environment:
      BACKEND: http://app:8080
      MODSEC_RULE_ENGINE: DetectionOnly
      BLOCKING_PARANOIA: "1"
      ANOMALY_INBOUND: "5"
      ANOMALY_OUTBOUND: "4"
    networks:
      - backend
```

- nginx on the host then proxies to `http://127.0.0.1:8081` instead of the application. Unless you configure the image to trust the forwarded headers, the WAF sees the address of the connecting nginx, not the client; match its audit entries to the access log by `X-Request-ID`.
- **Roll it out in stages:** `DetectionOnly` for one to two weeks of real traffic, read the audit log, write exclusions for the false positives, then set `MODSEC_RULE_ENGINE` to `On` at paranoia level 1. The CRS project describes level 1 as the baseline with few false alarms, level 2 as adequate "when real user data is involved", and level 3 as "online banking level security with lots of false positives". Raise the level per endpoint and only with a person to tune the exclusions. The project also describes a second route, blocking from the start with a very high anomaly threshold that you lower in steps; this note chooses `DetectionOnly` first. That is a recorded decision.
- **Keep the default anomaly thresholds** (5 for requests, 4 for responses) in production. The CRS documentation warns that raising them "will allow a substantial number of attacks to bypass CRS".

### What to ask of the application

- Parameterised queries everywhere, and a fixed list for identifiers such as sort columns ([OWASP](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)).
- A per-account failed-login counter, an exponential or timed lockout with a way around it for the owner, CAPTCHA as defence in depth and multi-factor authentication where users can use it.
- One generic error for the user, with the detail in the log. No SQL text, stack trace or driver message in a response.
- Log `X-Request-ID` on every line, return `429` with a `Retry-After` header when it throttles, and expose a health endpoint that does not touch the database more than necessary.

### Checking that it works

- Run the loop from a machine outside the host, and from two addresses, because the limits are per address:

```bash
for ((i = 1; i <= 12; i++)); do
  curl -s -o /dev/null -w '%{http_code} ' -X POST -d 'a=1' \
    https://app.example.com/api/v1/submit
done
echo
```

- With the reference configuration the first six answers are the application's and the rest are `429`. Then confirm that the refusals appear in `error.log`, that fail2ban counts them (`fail2ban-client status nginx-limit-req`) and that your own address is in `ignoreip`.
- Re-run the loop after every change to a limit or a location, and after an nginx upgrade.

## Sources and raw notes

Pages read on 2026-11-11:

- nginx: [limit_req module](https://nginx.org/en/docs/http/ngx_http_limit_req_module.html) (leaky bucket, `burst`, `nodelay`, `limit_req_dry_run`, `limit_req_status`, `limit_req_log_level`, zone size and inheritance), [limit_conn module](https://nginx.org/en/docs/http/ngx_http_limit_conn_module.html), [core module](https://nginx.org/en/docs/http/ngx_http_core_module.html) (timeouts, `limit_except`).
- [OWASP SQL Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html) (primary defences, least privilege), [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html) (login throttling, account lockout, CAPTCHA, multi-factor authentication), [OWASP Denial of Service Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Denial_of_Service_Cheat_Sheet.html) (rate limiting, timeouts, cloud filter services).
- fail2ban: the [`jail.conf`](https://github.com/fail2ban/fail2ban/blob/master/config/jail.conf) shipped with 1.1.1 (header, `bantime.increment` options, stock `nginx-*` jails, `chain`), the [`nginx-limit-req`](https://github.com/fail2ban/fail2ban/blob/master/config/filter.d/nginx-limit-req.conf) and [`nginx-botsearch`](https://github.com/fail2ban/fail2ban/blob/master/config/filter.d/nginx-botsearch.conf) filters, the [`jail.conf` manual](https://manpages.debian.org/trixie/fail2ban/jail.conf.5.en.html) and the [latest release](https://github.com/fail2ban/fail2ban/releases/latest).
- OWASP Core Rule Set: [paranoia levels](https://coreruleset.org/docs/2-how-crs-works/2-2-paranoia_levels/) and [anomaly scoring](https://coreruleset.org/docs/2-how-crs-works/2-1-anomaly_scoring/); the [`modsecurity-crs-docker` README](https://github.com/coreruleset/modsecurity-crs-docker) (tags, rolling tags, `BACKEND`, `MODSEC_RULE_ENGINE`, `BLOCKING_PARANOIA`, `ANOMALY_INBOUND`); the READMEs of the [ModSecurity-nginx](https://github.com/owasp-modsecurity/ModSecurity-nginx) and [coraza-nginx](https://github.com/corazawaf/coraza-nginx) connectors.
- [Docker with iptables](https://docs.docker.com/engine/network/firewall-iptables/): the `DOCKER-USER` chain.
- Behaviour checks: the rate-limit, body-size and method checks of the [nginx note](06-nginx-reverse-proxy.md#checks-after-a-change), the dry-run run (nginx 1.27.5, 12 requests all passed, dry-run lines in the error log) and a check of the stock fail2ban `nginx-limit-req` pattern against the log lines of both runs, done with Perl, not with fail2ban itself. The `jail.local`, the container-chain remark and the CRS snippet were not run.
