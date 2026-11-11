# Checklists

## Summary

These lists repeat the rules of the other notes in the order in which you need them: before a service goes live, when a server is built, before a public endpoint opens, on a weekly, monthly, quarterly and yearly rhythm, after an incident, and as a scan for red flags in a project that already exists. Each item links to the note that explains it. A checklist replaces memory, not understanding: if an item is unclear, read its note.

## Rules

### A new service, before its first deployment

- [ ] The repository has `Dockerfile`, `.dockerignore`, `compose.yaml`, `.env.example`, a `Makefile`, `.gitlab-ci.yml` and `docs/runbook.md` ([layout](02-repository-layout-and-tooling.md#where-things-live)).
- [ ] The image is built from a base pinned by tag and digest, in stages, with a numeric non-root user, a `HEALTHCHECK` and OCI labels, and holds no secret. hadolint and `docker buildx build --check` are clean ([images](04-docker-images-and-dockerfiles.md)).
- [ ] The Compose file has no `version`, sets `name:`, requires an immutable tag, publishes only on `127.0.0.1`, puts data stores on an `internal` network, and gives each service a restart policy, `init`, a read-only root, `cap_drop: ALL`, `no-new-privileges`, limits and a health check ([Compose](05-compose-and-container-runtime.md)).
- [ ] The nginx site redirects to HTTPS, includes the TLS and header snippets, sets limits and a method allow-list, and passes `nginx -t` ([nginx](06-nginx-reverse-proxy.md)).
- [ ] The database has its own accounts per role, restricted by host, with data-only privileges for the application; `root` is local; the version is supported ([databases](09-databases-and-data-stores.md)).
- [ ] Every secret is generated, unique to this service and environment, listed in the inventory and delivered as a file; the scanners run in a pre-commit hook and in CI ([secrets](08-secrets-and-configuration.md)).
- [ ] The pipeline lints, builds once, scans, releases by retagging and deploys production by hand with a key that can run only the deploy script ([CI/CD](10-ci-cd-and-deployment.md)).
- [ ] The service logs JSON to stdout with a request ID, the logs leave the host, alerts and an outside probe exist ([logging](11-logging-monitoring-and-alerting.md)).
- [ ] A backup runs on a timer, sends a heartbeat, has been restored once, and the recovery objectives are written ([backups](12-backups-and-recovery.md)).
- [ ] Someone who did not write the runbook has followed it on staging ([runbooks](13-incident-response-and-runbooks.md#runbooks)).

### A new server

- [ ] A supported LTS release, minimal install, one distribution family; unattended security updates are on and the reboot policy is written ([server](03-linux-server-baseline.md#operating-system-and-patching)).
- [ ] Accounts are personal, keys only, `sudo` for administrators, no root login; the `docker` group is limited; the SSH drop-in was tested with a second session open ([SSH](03-linux-server-baseline.md#ssh)).
- [ ] The provider's security group and `ufw` default to deny; published ports are on loopback; `bin/check_published_ports` and a scan from outside (IPv4 and IPv6) show only what you intended ([firewall](03-linux-server-baseline.md#firewall)).
- [ ] `daemon.json` sets the `local` log driver and `live-restore`; the Engine is on a supported line; the socket is not exposed ([Docker daemon](03-linux-server-baseline.md#docker-daemon)).
- [ ] The clock is UTC and synchronised; the journal is persistent and capped; disk alerts exist ([disk, time and logs](03-linux-server-baseline.md#disk-time-and-logs)).
- [ ] nginx is the stable line, configured from the repository; certificate renewal runs from a timer and an expiry alert exists ([TLS](06-nginx-reverse-proxy.md#tls)).
- [ ] Monitoring, log shipping and the backup timer are on.
- [ ] Lynis was run and its findings fixed or explained; the one-page server record is written ([checking the server](03-linux-server-baseline.md#checking-the-server)).

### Before a public endpoint opens

- [ ] Every query is parameterised and identifiers come from fixed lists; there are tests with injection strings (the application's work, [abuse control](07-abuse-control-and-edge-protection.md#what-to-ask-of-the-application)).
- [ ] The database account is least-privilege, and the statements that must fail were run and failed (`CREATE`, `DROP`, `ALTER`, `GRANT`, `INTO OUTFILE`) ([accounts](09-databases-and-data-stores.md#accounts-and-privileges)).
- [ ] The endpoint has its own rate limit, which ran in dry-run mode for a week and is now enforced; you saw `429` in a test; the access log shows real client addresses ([rate limiting](07-abuse-control-and-edge-protection.md#rate-limiting-in-nginx)).
- [ ] Per-account throttling or lockout, and the choice about CAPTCHA and multi-factor authentication, are decided and implemented.
- [ ] fail2ban jails are on; a WAF runs in detection-only mode with a date to enforce, or a managed WAF is in front ([WAF](07-abuse-control-and-edge-protection.md#web-application-firewall)).
- [ ] Method, body-size and timeout limits are set; unknown host names are dropped.
- [ ] Error responses are generic; no SQL, stack trace or driver message reaches a client.
- [ ] Alerts exist for refusals, bans, WAF detections and the database error counters, and a named person reads them ([security signals](11-logging-monitoring-and-alerting.md#security-signals)).
- [ ] A backup was restored recently; the incident plan covers this endpoint; the owner and the on-call contact are named.

### Weekly (fifteen minutes)

- [ ] Read the security signals: refusals, bans, WAF detections, database error counters, failed SSH logins.
- [ ] Check the backup heartbeats and the size of the newest snapshots.
- [ ] Apply pending security updates and the reboot if the window is due; check the pending-reboot alert.
- [ ] Review open alerts and silences, and give any silence without an end date one.
- [ ] Check that the scheduled image rebuild passed and review the merge requests that bump base-image digests ([images](04-docker-images-and-dockerfiles.md#lint-scan-and-rebuild)).

### Monthly

- [ ] Restore the newest backup into a scratch server and compare it with production ([restore drills](12-backups-and-recovery.md#restore-drills)).
- [ ] Update Docker Engine and nginx; read the [nginx security advisories](https://nginx.org/en/security_advisories.html) and the Docker release notes for security entries; apply within seven days if there is one.
- [ ] Run `bin/check_published_ports` and a port scan from outside, on IPv4 and IPv6.
- [ ] Send a test alert through the whole path.
- [ ] Check certificate expiry and renewal logs, and the domain registration dates.
- [ ] Look at disk growth of volumes, logs and the registry; check that the registry cleanup policy ran.

### Quarterly

- [ ] Review accounts, groups, `authorized_keys`, CI/CD variables and deploy keys; remove what is unused ([secrets](08-secrets-and-configuration.md#inventory-and-rotation)).
- [ ] Rotate CI/CD tokens and anything else due in the inventory.
- [ ] Rehearse a rollback on staging.
- [ ] Run Lynis on every server.
- [ ] Delete the alerts nobody acted on and review the thresholds.
- [ ] List the end-of-support dates of the operating system, the databases, Docker, nginx and the language runtimes, six months ahead.
- [ ] Hold a tabletop exercise of the incident plan in every second quarter ([incident plan](13-incident-response-and-runbooks.md#the-incident-plan)).

### Yearly

- [ ] Rebuild a server from the repository, the secret store and the backups, in a clean account; time it and update the recovery time objective.
- [ ] Rotate static credentials and review the encryption keys of backups.
- [ ] Review the retention of logs and backups against the rules that apply to the business.
- [ ] Read these notes against the current versions and change what has aged.

### After an incident

- [ ] The blameless review was held within five working days, with a UTC timeline and actions that have owners and dates ([after an incident](13-incident-response-and-runbooks.md#after-an-incident)).
- [ ] The alert that should have fired exists; the limit or rule that was missing exists; the runbook and the plan are updated.
- [ ] Every secret the path could reach was rotated; accounts and keys were reviewed; the evidence is in the store.
- [ ] A backup from before the incident is kept, and a restore from it was proven.

### Red flags in an existing project

Look for these when you open a project you did not write. Fix a flag that exposes something (a published port, a secret, a missing backup) as soon as you find it, even if the rest of the project waits for a clean-up.

| Red flag | Why it matters | Fix |
| --- | --- | --- |
| `network_mode: host` | No Docker isolation or port rules | [Compose](05-compose-and-container-runtime.md#ports-and-networks) |
| `ports: "8080:8080"`, or any port without `127.0.0.1` | Open to the world and around `ufw` | [Firewall](03-linux-server-baseline.md#firewall) |
| A database or cache with `ports:` | Reachable from the internet | [Placement](09-databases-and-data-stores.md#placement) |
| `FROM golang`, `image: x:latest`, `mysql:latest` in CI | Builds change by themselves | [Base images](04-docker-images-and-dockerfiles.md#base-images-and-tags) |
| Old tool images in CI (`docker:19.03.12`) or `docker-compose` 1.x | Unmaintained tooling in the pipeline | [Pipeline shape](10-ci-cd-and-deployment.md#pipeline-shape) |
| The container runs as root (no `USER`) | A flaw gives root in the container | [Run](04-docker-images-and-dockerfiles.md#run) |
| The application connects as `root`, or an account with host `%` | An injection gets everything | [Accounts](09-databases-and-data-stores.md#accounts-and-privileges) |
| `go mod tidy` or `npm install` in the image build | The build changes the dependencies | [Build](04-docker-images-and-dockerfiles.md#build) |
| `build:` in the Compose file used on the server | The server compiles; nothing is promoted | [Images](05-compose-and-container-runtime.md#images) |
| `.bak`, `.old` or commented-out configuration in Git | Git is the history | [Layout](02-repository-layout-and-tooling.md#where-things-live) |
| Passwords in a Compose or pipeline file | They leak, and they get reused | [Secrets](08-secrets-and-configuration.md#delivering-secrets) |
| `only:` and `except:` in `.gitlab-ci.yml` | Deprecated keywords | [Pipeline shape](10-ci-cd-and-deployment.md#pipeline-shape) |
| `/var/run/docker.sock` mounted into a container | Root on the host | [Hardening](05-compose-and-container-runtime.md#runtime-hardening) |
| `server_tokens` on, no catch-all server | The server names itself and answers any host | [nginx](06-nginx-reverse-proxy.md#defaults-to-set-in-nginxconf) |
| Unlimited `json-file` logs | The disk fills | [Docker daemon](03-linux-server-baseline.md#docker-daemon) |
| No outside probe, no backup alert | Failures nobody sees | [Alerts](11-logging-monitoring-and-alerting.md#alerts) |
| A backup that was never restored | A hope, not a backup | [Restore drills](12-backups-and-recovery.md#restore-drills) |

## Sources and raw notes

These lists contain no new rules. Each item is explained, and sourced, in the note it links to. The list of red flags is a summary of those notes written from the kinds of mistakes the rules were made to prevent.
