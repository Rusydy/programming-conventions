---
paths:
  - "**/Dockerfile"
  - "Dockerfile"
  - "**/Dockerfile.*"
  - "Dockerfile.*"
  - "**/*.dockerfile"
  - "**/.dockerignore"
  - ".dockerignore"
  - "**/compose.yaml"
  - "compose.yaml"
  - "**/compose.yml"
  - "compose.yml"
  - "**/compose.*.yaml"
  - "compose.*.yaml"
  - "**/compose.*.yml"
  - "compose.*.yml"
  - "**/docker-compose*.yaml"
  - "docker-compose*.yaml"
  - "**/docker-compose*.yml"
  - "docker-compose*.yml"
  - "**/nginx.conf"
  - "nginx.conf"
  - "**/nginx/**/*.conf"
  - "nginx/**/*.conf"
  - "**/.gitlab-ci.yml"
  - ".gitlab-ci.yml"
  - "**/.github/workflows/*.yml"
  - "**/.github/workflows/*.yaml"
  - "**/sshd_config.d/*.conf"
  - "**/jail.local"
  - "**/fail2ban/**/*.local"
  - "**/daemon.json"
  - "**/*.service"
  - "**/*.timer"
  - "**/.env.example"
  - ".env.example"
  - "**/runbook.md"
---
# Infrastructure conventions (every project)

Write idiomatic, readable infrastructure. Follow the conventions of each tool (nginx, Docker, OpenSSH, the distribution, GitLab) instead of inventing configuration ("convention over configuration"). This file is a digest of the notes in the `infra-conventions` folder of the programming-conventions repository, which hold the reasons, sources and checked examples. Read the matching note before a large change or when a rule here is unclear. The digest was synced with the notes on 2026-11-11; update it by hand whenever a note changes. The paths above match Dockerfiles, Compose files, nginx configuration, CI files, systemd units, SSH, fail2ban and Docker daemon configuration, `.env.example` and runbooks; for any other file (a deploy script, an `authorized_keys` line), read this file first.

## How to apply

- New and edited files follow this file. Leave untouched files alone unless asked, and keep diffs small. **Exposures are the exception:** a database or cache port published to the internet, a committed secret, a container that mounts the Docker socket or runs `privileged`, a backup never restored, an unsupported database version. Fix them when found, or report them at once.
- If the repository documents its own conventions, follow them first. Generated output (`docker compose config`) is exempt. Scripts follow `bash.md`; the application behind a service follows its language rule.
- The set assumes one or a few Linux servers with Docker, Compose, nginx and GitLab CI (GitHub equivalents are in the CI note), and no API gateway, mesh or orchestrator.
- Never run `docker compose down -v` or `docker system prune --volumes` on a server, and never change firewall, SSH or daemon settings, or restart Docker, nginx or a database, on a real host unasked. Try risky changes on staging or in a throwaway container.
- Before you report infra changes as done, run the checks that apply and fix new findings: `hadolint Dockerfile`, `docker buildx build --check .`, `docker compose config --quiet` (with the required variables set), `nginx -t` before any reload, `shfmt -d .` and ShellCheck for scripts, `gitleaks git`. Newest on 2026-11-11: hadolint 2.15.1, Trivy 0.76.2, gitleaks 8.30.1.
- The notes mark what was run. Never run: the sshd drop-in, `ufw` and `DOCKER-USER` rules, systemd units, unattended-upgrades settings, fail2ban jails, the CRS container, restic, Trivy, the GitLab pipeline itself, MySQL 8.4 and 9.7. Say so, and test them on a throwaway host first.
- When sources disagree, the order is: what the software does (its documentation, checked by running it), this file and the notes, OWASP, Mozilla, NIST and CISA guidance, vendor guides, tool defaults.

## Principles

- Follow the tool's default; replace it only with a written reason next to the setting.
- Everything that defines a server or service is in Git, and a server can be rebuilt from it. No `.bak`, `.old` or commented-out old configuration. A hand change on a server is committed the same day.
- Expose as little as possible: default deny, ports on `127.0.0.1`, nginx the only public listener, data stores unreachable from outside.
- Layer the defences and fix the cause in the application. Limits, a WAF and bans slow an attacker, least-privilege accounts and an unreachable database contain the damage, alerts notice, backups recover. The repair for SQL injection is parameterised queries.
- Build once, pin, promote: one image per commit, tag and digest pins, the same image in every environment.
- Observable (logs off the host, health checks, an outside probe), recoverable (restored backups, rehearsed rollback, a yearly rebuild) and patched (supported versions, automatic security updates, weekly image rebuilds).

## Layout, names and tooling

- A service repository holds `Dockerfile`, `.dockerignore`, `compose.yaml` (plus `compose.production.yaml` with only the differences), `.env.example`, a `Makefile` or `bin/` entry points, its nginx site in `deploy/nginx/`, `docs/runbook.md` and `.gitlab-ci.yml`. The infra repository holds shared nginx files, `ssh/sshd_config.d/00-hardening.conf`, `fail2ban/jail.local`, `systemd/`, `docs/network.md` (one unique /24 and the loopback ports per project), `docs/servers/<host>.md` and `docs/incident-plan.md`.
- Names: `compose.yaml`, not `docker-compose.yml`; services by role (`app`, `worker`, `db`, `cache`); networks `frontend` and `backend`; volumes by content (`db-data`); variables `UPPER_SNAKE_CASE` with a service prefix and `*_FILE` for a secret's path; environments `development`, `staging`, `production`; hosts `<role>-<env>-<nn>`; images tagged with the full commit SHA or `vX.Y.Z`.
- `.gitignore`: `.env`, `.env.*` (not `.env.example`), `secrets/`, `*.pem`, `*.key`, `*.bak`, `*.orig`, `*.old`, `*~`, `dump*.sql`, `*.sql.gz`, `*.log`. Never ignore all `.sql` files; migrations are `.sql`.
- One entry point (`make lint`) runs the checks that CI runs. Staging mirrors production; environments share no database, secret or registry credential.

## Linux server

- Ubuntu Server LTS (26.04, 24.04) or Debian stable (13), one family, minimal install. `unattended-upgrades` for security updates (`20auto-upgrades`: `APT::Periodic::Update-Package-Lists "1";` and `APT::Periodic::Unattended-Upgrade "1";`) and a written reboot policy (`Unattended-Upgrade::Automatic-Reboot` is `false` by default; `Automatic-Reboot-Time "hh:mm"`). Docker Engine and nginx updates are a monthly task; apply an nginx security release within seven days.
- One account per person, keys only, `sudo` for administrators, no root login. The `docker` group is root access: administrators and the restricted deploy user only. Never expose the Docker daemon on TCP; never mount the socket into a container.
- SSH hardening goes in `/etc/ssh/sshd_config.d/00-hardening.conf`, named to be read first because the first obtained value wins: `PasswordAuthentication no`, `KbdInteractiveAuthentication no`, `PermitRootLogin no`, `PubkeyAuthentication yes`, `AuthenticationMethods publickey`, `AllowGroups ssh-users`, `MaxAuthTries 3`, `LoginGraceTime 30`, `X11Forwarding no`, `ClientAliveInterval 300`, `ClientAliveCountMax 2`. Keep a second session open, run `sudo sshd -t`, then `sudo systemctl reload ssh`. Ed25519 keys with a passphrase.
- Firewall in three layers: the provider's security group, `ufw` with default deny incoming, and Docker's own rules. **`ufw` does not filter published container ports; Docker routes them around it.** Publish on `127.0.0.1`, restrict a published port by source in the `DOCKER-USER` chain, stay on the iptables backend (nftables is experimental in Docker 29), and after every provisioning or port change run the published-ports check and scan from outside over IPv4 and IPv6.
- `/etc/docker/daemon.json`: `"log-driver": "local"`, `"log-opts": {"max-size": "10m", "max-file": "5"}`, `"live-restore": true`. Stay on a supported Engine line (29.x on 2026-11-11; 28 left support on 2026-05-13).
- The clock is UTC and synchronised; the journal is persistent and capped (`Storage=persistent`, `SystemMaxUse=1G`); disk alerts at 80 percent; logs shipped off the host. Each quarter: `ss -tulpn`, an outside port scan and Lynis. One page per server; rebuild from the repository once a year.

## Dockerfile

- Begin with `# syntax=docker/dockerfile:1`. Multi-stage. Official or verified base images, the smallest that works, pinned by tag and digest (`golang:1.27-alpine@sha256:...`) and bumped weekly by a scheduled job. Debian slim before Alpine for language runtimes (Alpine for static builds and nginx). Never `latest`.
- Dependency files before source, cache mounts, a `.dockerignore`, `COPY` not `ADD`. A build does not change the dependencies: no `go mod tidy` or `npm install` in an image build. One `RUN apt-get update && apt-get install -y --no-install-recommends ... && rm -rf /var/lib/apt/lists/*` without version pins, with `# hadolint ignore=DL3008` and the reason. `set -o pipefail` before a pipe. No `curl | sh`.
- A numeric non-root user (`groupadd --gid 10001`, `useradd --uid 10001 --no-log-init`, `USER 10001:10001`), a service that works with a read-only root, a `HEALTHCHECK` that needs nothing extra in the image (an own `-healthcheck` flag), exec-form `ENTRYPOINT` and `CMD`, and the OCI labels `source`, `revision` and `version`.
- No secret in `ARG`, `ENV` or `COPY`; a build secret goes through `RUN --mount=type=secret`. Lint with hadolint and `docker buildx build --check`, scan the image, rebuild weekly with `docker build --pull`.

## Compose

- `compose.yaml` without `version:`, with a top-level `name:`. `image:` with an immutable tag from the registry, required through `${APP_TAG:?message}`. No `build:` or `latest` on a server, no `container_name`.
- **Only the edge publishes ports, always as `127.0.0.1:HOST:CONTAINER`.** Databases, caches and queues publish nothing and sit on a `backend` network with `internal: true`; the application joins `frontend` and `backend`. A fixed /24 per project from `docs/network.md`. Never `network_mode: host`, never `iptables: false`.
- Every service: `restart: unless-stopped`, `init: true`, `read_only: true` with `tmpfs: [/tmp]`, a numeric `user`, `cap_drop: [ALL]` (add back only what a failure names), `security_opt: [no-new-privileges:true]`, `deploy.resources.limits` (`memory`, `cpus`, `pids`), a `healthcheck` and `stop_grace_period`. Never `privileged`, the Docker socket, `cap_add: ALL` or the host's PID or IPC namespace. Run recipes: nginx needs `CHOWN`, `SETGID`, `SETUID` and `NET_BIND_SERVICE` with `tmpfs` on `/var/cache/nginx` and `/run`; MySQL needs `CHOWN`, `DAC_OVERRIDE`, `SETGID` and `SETUID`.
- `depends_on` with `condition: service_healthy`. Deploy with `docker compose up -d --wait --wait-timeout 180 --remove-orphans`; it exits 1 when a service stays unhealthy.
- Secrets are `secrets:` files read through `*_FILE`; for a `file:` source the host file's owner and mode count, and `uid`, `gid` and `mode` are ignored. `.env` only feeds `${VARIABLE}`. Named volumes for data; never `down -v` in a script.

## nginx

- nginx is the only public listener: on the host by default (stable line, 1.30.6 on 2026-11-11), in Compose with the recipe above. `nginx.conf` holds globals only; one `conf.d/<host>.conf` per site; `00-default.conf` is the catch-all; shared pieces are `snippets/tls.conf`, `security-headers.conf`, `proxy.conf` and `real-ip.conf`. No `root` or `if` inside a `location`, except `if` with `return` or `rewrite ... last`. `sudo nginx -t` before every reload.
- Globals: `server_tokens off`, `client_header_timeout 10s`, `client_body_timeout 10s`, `send_timeout 30s`, `keepalive_timeout 30s`, `client_max_body_size 1m` (raise it only on an upload location), `reset_timedout_connection on`, a JSON `log_format ... escape=json` with `$request_id`, `$request_uri`, `$status` and `$request_time`.
- Unknown hosts: `listen 80 default_server; return 444;` and `listen 443 ssl default_server; ssl_reject_handshake on;`.
- TLS: the Mozilla intermediate profile (`TLSv1.2 TLSv1.3`, its six ECDHE suites, `ssl_prefer_server_ciphers off`), `ssl_session_tickets off`, `ssl_session_cache shared:SSL:10m`, `http2 on;`, no OCSP stapling for Let's Encrypt. certbot renews from a timer at about two thirds of the lifetime (Let's Encrypt moves to 64 days on 2027-02-10 and 45 on 2028-02-16); alert on days to expiry. Port 80 answers `return 301 https://$host$request_uri;` except `/.well-known/acme-challenge/`. HSTS `max-age=63072000`; add `includeSubDomains` and `preload` only when every subdomain serves HTTPS.
- Headers, each with `always`: `Strict-Transport-Security`, `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`. **A block that sets any `add_header` does not inherit the ones above it:** include the snippet again, or use `add_header_inherit merge;` (1.29.3 and later). Content-Security-Policy belongs to the application, report-only first.
- Proxy: `proxy_http_version 1.1`, `Connection ""`, an upstream with `keepalive`, `Host $host`, `X-Real-IP $remote_addr`, `X-Forwarded-For $remote_addr` (overwrite at the edge, never append), `X-Forwarded-Proto`, `X-Request-ID $request_id`, explicit `proxy_*_timeout`; leave `non_idempotent` off. Behind a CDN: `set_real_ip_from` the trusted ranges only, `real_ip_header X-Forwarded-For`, `real_ip_recursive on`. Check that `remote_addr` is the real client.
- Per location: `limit_except GET POST { deny all; }`, and `location ~ /\.(?!well-known) { return 404; }`.

## Abuse control

- Layers: nginx limits, fail2ban, a WAF, per-account throttling in the application, a least-privilege database account, logs and alerts. **None of them repairs a SQL injection; parameterised queries do.** Many users can share one address behind NAT, so keep limits above the legitimate peak.
- Zones in `http {}`: `general` at 20r/s with burst 40, `sensitive` at 30r/m with burst 5 and `nodelay` for login, OTP, reset and submit endpoints, `limit_conn perip 30`, `limit_req_status 429`, `limit_req_log_level warn`. A `limit_req` in a `location` replaces the one above it. **Run each limit with `limit_req_dry_run on;` against a week of real traffic before enforcing it.**
- fail2ban: customise only in `jail.local` or `jail.d/`; enable the stock `nginx-limit-req` and `nginx-botsearch` jails; `bantime.increment = true`; `ignoreip` with your own addresses. It cannot ban behind a CDN, and with nginx in Docker its bans need the `DOCKER-USER` chain.
- WAF: the OWASP CRS container (`owasp/modsecurity-crs`, nginx variant, a stable tag, never a rolling one) between nginx and the application. `MODSEC_RULE_ENGINE=DetectionOnly` first, paranoia level 1, default thresholds (5 and 4), exclusions tuned, then `On`. A managed WAF or CDN is the alternative.
- Ask of the application: parameterised queries, per-account throttling or lockout, CAPTCHA and multi-factor authentication as defence in depth, generic errors without SQL text, `X-Request-ID` on every log line, `429` with `Retry-After`.

## Secrets and configuration

- Plain configuration in environment variables, secrets as files (`secrets:` and `*_FILE`). Never in Git, an image layer, a command line, a URL or a log. `.env.example` carries fake values. Generate secrets (`openssl rand -base64 32`), one per service and environment, in an inventory without values, rotated yearly (CI/CD tokens every 90 days) and at once on a departure, a suspected leak or an incident.
- Scan with gitleaks in a pre-commit hook and in CI. **A pushed secret is compromised: rotate first, then clean the history.**
- GitLab variables are masked, protected, hidden (new ones) and scoped to the production environment. Masking is not a guarantee: prefer file-type variables, an external secret manager and OIDC `id_tokens`. Review every change to `.gitlab-ci.yml`, forks included.
- TLS private keys are `0600` and root-only, SSH keys Ed25519, and the backup encryption key is kept apart from the backups and the server.

## Databases

- Supported LTS only: MySQL 8.4 or 9.7 (8.0 is in Oracle Sustaining Support since 2026-04-21), PostgreSQL 18 (14 ends 2026-11-12), Redis 8. The same major and minor in CI, staging and production; never `latest` (`mysql:latest` is the 26.10 innovation release). End-of-support dates go in the runbook.
- No published port, an `internal` network, administration through `docker compose exec`, a port scan from outside to prove it.
- One account per role, each `'user'@'<project subnet>'`, never `'%'`: runtime (`SELECT, INSERT, UPDATE, DELETE` only), migration (`ALL` on its schema, used only by the migration job), reporting (`SELECT`), backup (`SELECT, SHOW VIEW, TRIGGER, EVENT` plus global `SHOW_ROUTINE`, with `mysqldump --single-transaction --routines --triggers --events --no-tablespaces`) and monitor (`SELECT` on `performance_schema.events_errors_summary_global_by_error`). No `FILE`, no administrative privilege, and the application does not own the schema. **The official MySQL image creates `root@%`; set `MYSQL_ROOT_HOST: localhost`.**
- MySQL does not write client syntax errors to its error log. Count `ER_PARSE_ERROR`, `ER_BAD_FIELD_ERROR` and `ER_NO_SUCH_TABLE` in that Performance Schema table, and have the application log database errors with the request ID.
- Migrations are a separate step with the migration account, before the new version, forward-only and compatible with the previous version. The application never alters the schema. TLS between hosts. Redis: never published, ACL users or `requirepass`. PostgreSQL: never `trust`.

## CI/CD (GitLab)

- Stages `lint`, `build`, `test`, `release`, `deploy`. `workflow:rules`, `rules:` (not `only` and `except`), `default: interruptible: true`, and `resource_group` with `interruptible: false` on deploy. Pin every job image and service (`docker:29.9.3-cli`, `hadolint/hadolint:v2.15.1-debian`, `mysql:8.4`, `alpine:3.24`); no bare `golang`, `mysql:latest` or `docker:19.03.12`.
- Lint the Dockerfile, nginx (`nginx -t` with a throwaway certificate), Compose and scripts. Build once per commit and tag `$CI_COMMIT_SHA`. A release tag retags that image and rebuilds nothing, so the `build` job skips tag pipelines. Protect or make release tags immutable; set a registry cleanup policy.
- Docker-in-Docker over TLS on a runner that is not a production server; socket binding exposes the host. `docker login --password-stdin`.
- Security templates `Jobs/SAST`, `Jobs/Secret-Detection` and `Jobs/Container-Scanning` (the `Security/` names are stubs). They run in `test`, need `CS_IMAGE` and default to `allow_failure: true`: decide who reads the reports, and add a failing gate where a severity must stop a release.
- Production deploys come from a release tag with `when: manual`, in a protected `environment`, over SSH as a `deploy` user whose `authorized_keys` line is `restrict,from="...",command="/srv/app/bin/deploy \"$SSH_ORIGINAL_COMMAND\""`, with the host key pinned (`StrictHostKeyChecking=yes`). `bin/deploy TAG` validates the tag, pulls, runs `up -d --wait` and starts the previous tag when the new one is unhealthy. Migrations run first, rollback is the previous tag, rehearsed each quarter. On GitHub: pin actions to a full commit SHA, restrict `GITHUB_TOKEN`, use OIDC.

## Logging, monitoring and alerting

- Applications log JSON lines to stdout (`time` in UTC, `level`, `msg`, `request_id`); nginx logs the same way. Nothing secret or personal. Ship logs off the host. Keep 90 days searchable and 12 months archived unless a rule demands more. Alert when shipping stops.
- Measure latency, traffic, errors and saturation, plus host, container, nginx, database, certificate and backup basics. Alert on symptoms and on silence; each alert has a severity, a threshold with a duration, a first action and a runbook link. Starting set: site down (outside probe), 5xx above 2 percent for 5 minutes, disk at 80 and 90 percent, container restarts, certificate under 14 days, no backup heartbeat for 26 hours, no log lines for 10 minutes. Send a test alert monthly; delete alerts nobody acts on.
- Security signals, against a two-week baseline: rises in 429, 403, 404, 400 and 413; POST volume on submit and login endpoints; fail2ban bans; WAF detections; the database error counters; new accounts or privileges; failed SSH logins; a new listening port; a port published on all interfaces.

## Backups and recovery

- Back up databases (a nightly `mysqldump` with the flags above, plus binary logs when the recovery point objective is under a day), user files and the secret store; configuration is in Git. Copies are encrypted, off the server, in another account or region, written with credentials that cannot delete; pruning runs elsewhere.
- restic: `restic backup --stdin-from-command --stdin-filename shop.sql -- COMMAND` (no snapshot when the command fails), `forget --keep-daily 14 --keep-weekly 8 --keep-monthly 12 --prune`, a weekly `restic check` with `--read-data-subset`. A systemd timer (`OnCalendar`, `Persistent=true`, `RandomizedDelaySec`) runs the script, which sends a heartbeat after success.
- **Restore the newest snapshot into a scratch server every month and compare it** (rows, routines, triggers, views, newest timestamp). Rebuild a whole server yearly. Write the recovery point and time objectives per service.

## Incidents and runbooks

- Every service has `docs/runbook.md` (owner, hosts, logs, deploy, rollback, restore, secret rotation, alert actions, objectives, end-of-support dates), tested by someone who did not write it. Keep an incident plan with roles, an out-of-band channel, contacts, an evidence store and the authority to act, and exercise it twice a year.
- Containment, in order: declare and start a UTC timeline; preserve evidence before changing anything (logs, `docker inspect`, `ss -tulpn`, a volume snapshot; no reboot, prune, `down -v` or restore over data); block the traffic; rotate the application's database credentials and sessions; isolate rather than power off. Then find the first and last malicious request, what the account could do and any persistence; fix the cause; restore from before the first bad statement; rotate what the path could reach; notify as the plan says; hold a blameless review within five working days.

## Notes index

Each file is in the `infra-conventions` folder of the programming-conventions repository.

- `01-principles-and-sources.md`: principles, precedence, version baseline, how the examples were checked, decisions to review
- `02-repository-layout-and-tooling.md`: repositories, names, environments, `.gitignore`, the Makefile and the checks
- `03-linux-server-baseline.md`: patching, accounts, SSH, firewall, Docker daemon, time and logs
- `04-docker-images-and-dockerfiles.md`: base images, build, run, secrets, scanning, the reference Dockerfile
- `05-compose-and-container-runtime.md`: the Compose file, ports and networks, hardening, health, the reference file
- `06-nginx-reverse-proxy.md`: layout, TLS, headers, proxying, logging, the reference configuration
- `07-abuse-control-and-edge-protection.md`: rate limits, fail2ban, the WAF, what the application must do
- `08-secrets-and-configuration.md`: delivery, rotation, leak detection, CI/CD secrets
- `09-databases-and-data-stores.md`: versions, placement, accounts, migrations, detection, Redis
- `10-ci-cd-and-deployment.md`: pipeline shape, build once, security jobs, SSH deploys, the scripts
- `11-logging-monitoring-and-alerting.md`: logs, metrics, alerts, security signals
- `12-backups-and-recovery.md`: what to back up, where, restore drills, the backup script
- `13-incident-response-and-runbooks.md`: runbooks, the incident plan, containment, review
- `14-checklists.md`: per service, server and endpoint; weekly to yearly; red flags
