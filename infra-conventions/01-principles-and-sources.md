# Infrastructure Principles and Sources of Truth

## Summary

These principles apply to every server, container and pipeline that runs a project: Linux hosts, Docker, Docker Compose, nginx, databases, CI/CD and day-to-day operations. They put the conventions of each tool ahead of local configuration, so that any engineer can read a project's infrastructure on the first day. A precedence list settles disagreements between sources. Where the sources leave a choice open, the notes record a decision with its reason, and the table near the end says where to change each one.

The set assumes a small team that runs a few Linux servers with Docker and nginx, builds in GitLab CI (the rules hold for GitHub, and a table maps them) and has no API gateway, service mesh or orchestrator. nginx at the edge does the work a gateway would do for an estate this size: TLS, routing, limits and a first filter. The notes say when a managed WAF or CDN is the next step. They add one layer at a time and say what each layer cannot do.

## Rules

### Principles

1. **Follow the conventions of the tool.** The documentation and the defaults of nginx, Docker, OpenSSH, the distribution and GitLab come first. This is "convention over configuration" applied to infrastructure. Replace a default only with a written reason, and write the reason next to the setting.
2. **Keep it in Git, and rebuild from it.** Every file that defines how a server or a service runs is in a repository: Dockerfile, Compose file, nginx configuration, units, scripts, pipeline, runbook. A change made by hand on a server is committed the same day. Git is the history, so there are no `.bak` files and no commented-out old configuration ([layout](02-repository-layout-and-tooling.md)).
3. **Expose as little as possible.** Every open port, account, capability, mount, credential and network path exists because something needs it. The default is deny, ports publish on the loopback address, one process faces the internet, and data stores are unreachable from outside ([server](03-linux-server-baseline.md#firewall), [Compose](05-compose-and-container-runtime.md#ports-and-networks)).
4. **Layer the defences, and fix the cause in the application.** A public endpoint that builds SQL from request data and is hammered by automated requests is the case several notes are written around. Infrastructure cannot repair that code. It can slow the attacker (rate limits), stop the obvious patterns (a WAF, bans), contain the damage (least-privilege accounts, an unreachable database), notice (error counters, alerts) and recover (backups, a plan). The repair is parameterised queries in the application, and the notes say so wherever the layers are described ([abuse control](07-abuse-control-and-edge-protection.md)).
5. **Build once, pin, promote.** An artefact is built once per commit, every version is pinned (a tag and a digest for images), and the same artefact moves from staging to production ([images](04-docker-images-and-dockerfiles.md), [CI/CD](10-ci-cd-and-deployment.md)).
6. **Make it observable before it is needed.** Logs leave the host, every service has a health check, an outside probe watches the site, and each alert names an action ([logging](11-logging-monitoring-and-alerting.md)).
7. **Make it recoverable, and prove it.** Backups are restored on a schedule, rollbacks are rehearsed, and a server is rebuilt from nothing once a year ([backups](12-backups-and-recovery.md)).
8. **Treat patching as routine work.** Run supported versions only, apply security updates automatically, rebuild images every week, and put end-of-support dates on a calendar. On 2026-10-14 nginx fixed five medium-severity issues, Docker Engine 29.9.3 carried several security fixes on 2026-11-03, and MySQL 8.0 left full support in April 2026 ([server](03-linux-server-baseline.md#operating-system-and-patching)).
9. **Automate the checks; write down the rest.** Linters and scanners run locally and in CI with plain commands. What cannot be automated goes in a runbook that someone else has tried to follow ([runbooks](13-incident-response-and-runbooks.md#runbooks)).
10. **Prefer the boring and the readable.** Small files, one concern per file, names that say what a thing is, comments that say why, and formatters that settle the rest.

### Order of precedence

When two sources disagree, the lower number wins.

1. What the software does: its own documentation and release notes (nginx, Docker, OpenSSH, MySQL, GitLab), checked by running it. Where a note says it was run, it was run on the version it names.
2. The notes in this folder. They record each conflict between the sources and how it is settled.
3. Security guidance from standards bodies and projects: the OWASP cheat sheets and Core Rule Set, the Mozilla guidelines, NIST and CISA publications.
4. Vendor and platform guides for style and structure: Docker's build best practices and Compose documentation, Ubuntu Server documentation, GitLab documentation.
5. Tool defaults.

### Applying the notes

- **New services and servers** follow every note in this folder.
- **Existing ones:** apply the notes to what you touch. **Exposures are the exception.** A database port published to the internet, a committed secret, a root-capable container with the Docker socket, a backup that has never been restored, and an unsupported database version are fixed when found, not at the next clean-up. [The list of red flags](14-checklists.md#red-flags-in-an-existing-project) is a way to find them.
- **Mechanical changes** (a tool upgrade, a newly enabled check, a bump of pinned images) go in their own commits, so that a review shows the change and not the noise.
- **Generated files** are exempt, for example the output of `docker compose config`.
- **Repositories owned by others:** follow the conventions that repository documents first.
- **Language sets:** scripts follow the [Bash set](../bash-conventions/01-principles-and-sources.md); the application behind a service follows its own language set. The Next.js Docker section is in [nextjs-conventions](../nextjs-conventions/12-deployment-and-self-hosting.md).
- **Agent rule:** this set has no digest in `agent-rules/` yet. Until it has one, ask the agent to read the note for the file type (Dockerfile, Compose, nginx, pipeline) before it changes it.

### Version baseline

Versions were read on 2026-11-11. Check the release notes before you start a project, because version facts go stale quickly.

| Item | Version | Where it was read |
| --- | --- | --- |
| Docker Engine | 29.9.3 (2026-11-03); the 28 line left support on 2026-05-13 | Engine 29 release notes, endoflife.date |
| Docker Compose; BuildKit; buildx | 5.6.1 (client); 0.30.0; 0.34.1 | The machine used for the checks |
| nginx | Stable 1.30.6 (2026-10-14), mainline 1.31.8 (2026-10-21) | nginx.org |
| OpenSSH; fail2ban | 10.6 (2026-10-06); 1.1.1 (2026-08-15) | OpenSSH release notes, GitHub releases |
| Ubuntu; Debian | 26.04 LTS "resolute", 24.04 LTS; 13.7 "trixie" | Ubuntu meta-release list, Debian Release file |
| MySQL | 8.4.13 and 9.7.4 (LTS); 8.0 in Oracle Sustaining Support since 2026-04-21 | mysql.com, Docker official images |
| PostgreSQL; Redis | 18.6 (14 ends 2026-11-12); 8.10.3 | endoflife.date, Docker official images |
| Go (images) | 1.27.4 | Docker official images |
| hadolint; Trivy; gitleaks | 2.15.1; 0.76.2; 8.30.1 | GitHub releases |
| ShellCheck; shfmt | 0.11.0; 3.14.1 | The machine used for the checks |
| Let's Encrypt | 45-day profile since 2026-05-13; default profile 64 days from 2027-02-10, 45 days from 2028-02-16 | Let's Encrypt |

### Examples and how they were checked

The notes hold complete examples. Each is marked with how far it was checked, and **a note says "run" only for what was run**. The checks used Docker 29.5.2 on Colima on an Apple-silicon Mac (aarch64, 2 CPUs, 2 GiB), the local images `nginx:1.27-alpine`, `mysql:8.0`, `redis:7.2-alpine`, `busybox:1.36` and `node:24-slim`, and the pulled images `nginx:1.30-alpine`, `golang:1.27-alpine`, `debian:trixie-slim` and `hadolint/hadolint:v2.15.1-debian`.

| Example | Checked | Result |
| --- | --- | --- |
| nginx configuration ([nginx](06-nginx-reverse-proxy.md)) | `nginx -t` and eleven checks (ten of them requests made with `curl`) on nginx 1.27.5 and again on 1.30.6; `add_header_inherit` on 1.30.6 | All passed on both; 146 of 146 access-log lines were valid JSON in each run |
| Rate limits, dry run, fail2ban pattern ([abuse control](07-abuse-control-and-edge-protection.md)) | 12 quick requests (six passed, six `429`); a dry-run run; the stock fail2ban `nginx-limit-req` pattern against the log lines (Perl, not fail2ban) | Passed; dry-run lines do not match the stock pattern |
| Compose file and hardening ([Compose](05-compose-and-container-runtime.md)) | `docker compose config`; `up --wait` with stand-in images; `docker inspect`; network, secret and port checks; a hardened nginx container | Passed. `up --wait` returned 1 for an unhealthy service and 0 when healthy |
| Dockerfile ([images](04-docker-images-and-dockerfiles.md)) | hadolint 2.15.1; `docker buildx build --check`; a build with BuildKit 0.30.0; a hardened run | Clean; built; healthy; `uid=10001` |
| MySQL accounts and monitoring ([databases](09-databases-and-data-stores.md)) | The SQL on `mysql:8.0`, six denied statements, `root@%` and `MYSQL_ROOT_HOST`, the dump with and without `--no-tablespaces`, the Performance Schema counters | Passed, as listed in the note |
| Backups ([backups](12-backups-and-recovery.md)) | A dump with the backup account's flags restored into a second server and compared; `bin/backup_db` under Bash 5.2.15 with stubs | Both servers agreed on every count |
| Deploy and port-check scripts ([CI/CD](10-ci-cd-and-deployment.md)) | ShellCheck 0.11.0, shfmt 3.14.1 with the Bash set's configuration, run under Bash 5.2.15 without network with stubs and a real `docker ps` fixture | Clean; behaved as described |
| GitLab pipeline ([CI/CD](10-ci-cd-and-deployment.md#reference-pipeline)) | Parsed with Ruby's YAML library; stages and `extends` checked; the lint steps run by hand | Structure only; **not run on GitLab** |
| `.gitignore` and Makefile ([layout](02-repository-layout-and-tooling.md)) | `git check-ignore` on sample paths; `make -n` | Passed |

**Not run:** the sshd drop-in, `ufw` and `DOCKER-USER` rules, the systemd units, unattended-upgrades settings, fail2ban jails, the OWASP CRS container, restic, Trivy, GitLab itself, MySQL 8.4 and 9.7, and everything about a Linux host's own networking (the test machine reaches containers through a virtual machine, which changes source addresses). The text of those examples comes from the manuals read, and a note marks each of them. Run them on a test server first.

### Decisions to review

These choices were made while writing the notes because the sources disagree or leave the choice open. Each can be reversed in the place named.

| Decision | Where to change it |
| --- | --- |
| nginx on the host by default; nginx in Compose as the accepted alternative | [nginx](06-nginx-reverse-proxy.md#where-nginx-runs-and-which-version) |
| Apply nginx security releases within seven days; run the stable line | [nginx](06-nginx-reverse-proxy.md#where-nginx-runs-and-which-version) |
| `ssl_session_tickets off` | [TLS](06-nginx-reverse-proxy.md#tls) |
| `restart: unless-stopped` instead of `always` | [Compose](05-compose-and-container-runtime.md#runtime-hardening) |
| Debian slim before Alpine for language runtimes, as in the Next.js note | [images](04-docker-images-and-dockerfiles.md#base-images-and-tags) |
| No pinned Debian package versions (base pinned by digest, weekly rebuild) | [images](04-docker-images-and-dockerfiles.md#build) |
| Secrets as files, plain configuration in environment variables | [secrets](08-secrets-and-configuration.md#delivering-secrets) |
| Rotation: static credentials yearly, CI/CD tokens every 90 days | [secrets](08-secrets-and-configuration.md#inventory-and-rotation) |
| Starting rate limits (20 a second, 30 a minute on sensitive endpoints) | [abuse control](07-abuse-control-and-edge-protection.md#rate-limiting-in-nginx) |
| WAF through the OWASP CRS container, detection-only first | [abuse control](07-abuse-control-and-edge-protection.md#web-application-firewall) |
| `local` log driver, 50 MB per container; UTC on every server | [server](03-linux-server-baseline.md#docker-daemon) |
| Log retention: 90 days searchable, 12 months archived | [logging](11-logging-monitoring-and-alerting.md#logs) |
| Alert thresholds | [logging](11-logging-monitoring-and-alerting.md#alerts) |
| restic as the backup tool; retention 14 daily, 8 weekly, 12 monthly | [backups](12-backups-and-recovery.md#where-the-copies-go) |
| Manual production deploys over SSH with a forced command | [CI/CD](10-ci-cd-and-deployment.md#deploying-over-ssh) |
| A /24 per Compose project, kept in a table | [layout](02-repository-layout-and-tooling.md#where-things-live) |

### Notes in this folder

| Note | Content |
| --- | --- |
| [02 Repository layout and tooling](02-repository-layout-and-tooling.md) | Service and infra repositories, names, environments, `.gitignore`, the Makefile and the checks |
| [03 Linux server baseline](03-linux-server-baseline.md) | Operating system and patching, accounts, SSH, firewall and Docker, the Docker daemon, time and logs, audits |
| [04 Docker images and Dockerfiles](04-docker-images-and-dockerfiles.md) | Base images, build, run, secrets and labels, scanning, the reference Dockerfile |
| [05 Docker Compose and the container runtime](05-compose-and-container-runtime.md) | The Compose file, ports and networks, hardening, health, secrets, the reference file |
| [06 nginx as the reverse proxy](06-nginx-reverse-proxy.md) | Layout, defaults, TLS, headers, proxying, logging, the reference configuration and checks |
| [07 Abuse control and edge protection](07-abuse-control-and-edge-protection.md) | Rate limits, fail2ban, the web application firewall, what the application must do |
| [08 Secrets and configuration](08-secrets-and-configuration.md) | Config against secrets, delivery, rotation, leak detection, CI/CD secrets |
| [09 Databases and data stores](09-databases-and-data-stores.md) | Versions, placement, accounts and privileges, migrations, detection, Redis |
| [10 CI/CD and deployment](10-ci-cd-and-deployment.md) | Pipeline shape, build once, security jobs, SSH deploys, the scripts, the reference pipeline |
| [11 Logging, monitoring and alerting](11-logging-monitoring-and-alerting.md) | Logs, metrics, alerts and the security signals |
| [12 Backups and recovery](12-backups-and-recovery.md) | What to back up, where, how, restore drills, the backup script |
| [13 Incident response and runbooks](13-incident-response-and-runbooks.md) | Runbooks, the incident plan, containment, investigation, recovery, review |
| [14 Checklists](14-checklists.md) | Per service, server and endpoint; weekly to yearly; red flags |

## Sources and raw notes

Pages read on 2026-11-11 for the version baseline and the principles (each other note lists the pages it was written from):

- Docker: the [Engine 29 release notes](https://docs.docker.com/engine/release-notes/29/) and [endoflife.date for Docker Engine](https://endoflife.date/api/docker-engine.json).
- nginx: the [download page](https://nginx.org/en/download.html), the [change log](https://nginx.org/en/CHANGES) and the [security advisories](https://nginx.org/en/security_advisories.html).
- [OpenSSH release notes](https://www.openssh.com/releasenotes.html); the fail2ban [latest release](https://github.com/fail2ban/fail2ban/releases/latest); the [Ubuntu LTS meta-release list](https://changelogs.ubuntu.com/meta-release-lts); the [Debian `stable` Release file](https://deb.debian.org/debian/dists/stable/Release); endoflife.date for [Ubuntu](https://endoflife.date/api/ubuntu.json), [Debian](https://endoflife.date/api/debian.json), [MySQL](https://endoflife.date/api/mysql.json), [PostgreSQL](https://endoflife.date/api/postgresql.json) and [Redis](https://endoflife.date/api/redis.json).
- MySQL: [Support EOL announcements](https://www.mysql.com/support/eol-notice.html) (8.0 in Sustaining Support from 2026-04-21).
- Docker official images, tag lists: [mysql](https://github.com/docker-library/official-images/blob/master/library/mysql), [postgres](https://github.com/docker-library/official-images/blob/master/library/postgres), [redis](https://github.com/docker-library/official-images/blob/master/library/redis), [golang](https://github.com/docker-library/official-images/blob/master/library/golang), [nginx](https://github.com/docker-library/official-images/blob/master/library/nginx) and [debian](https://github.com/docker-library/official-images/blob/master/library/debian).
- Latest releases on GitHub: [hadolint](https://github.com/hadolint/hadolint/releases/latest), [Trivy](https://github.com/aquasecurity/trivy/releases/latest) and [gitleaks](https://github.com/gitleaks/gitleaks/releases/latest). [Let's Encrypt: decreasing certificate lifetimes to 45 days](https://letsencrypt.org/2025/12/02/from-90-to-45).
- [The Twelve-Factor App](https://12factor.net/config); the [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/) pages cited in the notes; [CISA #StopRansomware Guide](https://www.cisa.gov/stopransomware/ransomware-guide); [NIST SP 800-61 Rev. 3](https://csrc.nist.gov/pubs/sp/800/61/r3/final).
- The equivalents of this set for languages: [bash-conventions](../bash-conventions/01-principles-and-sources.md), [golang-conventions](../golang-conventions/01-principles-and-sources.md) and [nextjs-conventions](../nextjs-conventions/01-principles-and-sources.md).
- Reading method: the documentation pages were read as plain text, fetched with `curl` and converted; the MySQL manual, whose site refuses `curl`, was read in a browser. Quotations in the notes are taken from those pages.
