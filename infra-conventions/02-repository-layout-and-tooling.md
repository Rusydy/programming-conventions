# Repository Layout and Tooling

## Summary

Infrastructure lives in Git, in two kinds of repository: each service repository holds everything that says how that service ships (Dockerfile, Compose file, its nginx site, scripts, pipeline, runbook), and one infra repository holds what belongs to a host or to every service (shared nginx files, SSH and fail2ban configuration, units, the network table, the incident plan). Files carry the name their tool expects. One entry point, a Makefile or a script in `bin/`, runs the same checks locally and in CI. Nothing secret, no backup copy and no generated dump is committed. Staging mirrors production, so that a deploy, a rollback and a restore can be rehearsed before they matter.

## Rules

### Where things live

A service repository:

```text
.
├── Dockerfile
├── .dockerignore
├── compose.yaml                  how the service runs on a server
├── compose.production.yaml       only what differs in production
├── .env.example                  every variable, fake values
├── Makefile                      make lint | up | down | logs
├── bin/                          Bash executables (see the Bash set)
│   └── deploy
├── deploy/
│   └── nginx/                    the site file for this service
├── docs/
│   └── runbook.md
└── .gitlab-ci.yml
```

The infra repository:

```text
infra/
├── docs/
│   ├── network.md                one subnet and the host ports per project
│   ├── incident-plan.md
│   └── servers/web-prod-01.md    one page per server
├── hosts/web-prod-01/            files that exist only on that host
├── nginx/                        nginx.conf, snippets/ and shared conf.d/
├── ssh/sshd_config.d/00-hardening.conf
├── fail2ban/jail.local
├── systemd/                      units and timers (backups, renewals)
├── bin/                          provisioning, check_published_ports
└── .gitlab-ci.yml
```

- **A service owns its site file.** When one repository owns the whole edge of a server, `deploy/nginx/` holds the full tree, as in the example pipeline ([CI/CD](10-ci-cd-and-deployment.md#reference-pipeline)). On a shared server, the infra repository holds `nginx.conf` and `snippets/`, and each service repository adds its own `conf.d/<host>.conf`.
- **Host files are in the repository, not only on the host.** The sshd drop-in, the fail2ban jail, the units, the logrotate policy and the `daemon.json` of every server are files in `infra/`, and the provisioning script or the configuration tool installs them ([server](03-linux-server-baseline.md#building-the-server-from-code)). A file that exists only on a server is a risk.
- **Never keep copies in the tree.** Git is the history: no `docker-compose.yml.bak`, `Dockerfile.old`, `nginx.conf.orig` or commented-out blocks of old configuration. When you want to try something, make a branch.
- **Network and port allocation is a file, `docs/network.md`.** One row per project: its Compose subnet (a /24, unique across the host), the loopback ports it publishes, and the host it runs on. Two projects with the same subnet cannot run on one host, and database accounts name the subnet ([Compose](05-compose-and-container-runtime.md#ports-and-networks)).

### Names

- **Files** carry the name the tool looks for: `compose.yaml`, `Dockerfile` (`Dockerfile.<name>` when a repository builds more than one image), `.dockerignore`, `nginx.conf`, `.gitlab-ci.yml`. Documentation is lower-case kebab-case Markdown. Executables in `bin/` follow the [Bash set](../bash-conventions/03-project-layout-and-files.md): no extension, lower-case, underscores.
- **Compose:** the project `name:` is the repository name; services are roles (`app`, `worker`, `db`, `cache`); networks are roles (`frontend`, `backend`); volumes are what they hold (`db-data`); secrets are snake_case names of what they are (`db_app_password`).
- **Variables** are `UPPER_SNAKE_CASE` with the service as prefix, and `*_FILE` for a path to a secret.
- **Environments** are `development`, `staging` and `production`. Do not invent `prod2` or `pre-prod`; create a new environment only for a reason that outlasts a week.
- **Hosts** are `<role>-<environment>-<number>` (`web-prod-01`, `db-staging-01`). A DNS name for a service is the service, not the host, so that a host can be replaced.
- **Images** are `registry/group/project[/service]:<tag>`, where the tag is the full commit SHA or a release tag (`v1.4.2`) ([CI/CD](10-ci-cd-and-deployment.md#build-once-promote-the-image)).

### Environments

- Development, staging and production use **the same Dockerfile and the same base Compose file**. The differences are in a small override file and in variables, never in a second copy of the files.
- **Staging mirrors production:** the same versions of nginx and the database, the same configuration, a smaller machine, different data and different secrets. A change goes through staging first, including a deploy, a rollback and a restore of a backup ([backups](12-backups-and-recovery.md#restore-drills)).
- Environments share nothing that matters: no database, no secret, no registry credential. A leaked staging password must not open production.

### What never goes into Git

- Secrets and local configuration (`.env`, `secrets/`, private keys, certificates), backup copies, database dumps and logs. This `.gitignore` was checked in a scratch repository: it ignored `.env`, `.env.production`, `secrets/db_password`, `*.pem`, `*.key`, `*.bak`, `*.orig`, `*.old`, `dump-*.sql`, `*.sql.gz` and `*.log`, and left `.env.example`, `compose.yaml`, `Dockerfile` and a migration `migrations/0001_init.sql` tracked.

```text
# Secrets and local configuration.
.env
.env.*
!.env.example
secrets/
*.pem
*.key

# Backup copies: Git is the history.
*.bak
*.orig
*.old
*~

# Dumps and logs. Migrations are .sql files too, so name the dumps.
dump*.sql
*.sql.gz
*.log
```

- Migrations are `.sql` files too, so the pattern names the dumps (`dump*.sql`) and does not ignore every `.sql` file.
- The Docker build context has its own list, `.dockerignore`, so that `COPY . .` cannot send these files into an image ([images](04-docker-images-and-dockerfiles.md#reference-dockerfile)).

### One entry point, the same checks everywhere

- A `Makefile` (or a script in `bin/`) gives a person one command for each job: `make lint`, `make up`, `make down`, `make logs`. CI runs the same commands, so "it passes on my machine" and "it passes in the pipeline" mean the same thing. The recipes of a Makefile need a tab at the start of each line.

```make
.PHONY: lint up down logs

lint:
	hadolint Dockerfile
	APP_TAG=lint docker compose config --quiet
	shfmt -d .
	shfmt -f=0 . | xargs -0 shellcheck
	gitleaks git

up:
	docker compose up -d --wait

down:
	docker compose down

logs:
	docker compose logs --tail=200 --follow
```

- `make -n lint` printed the five commands without running them.

| What | Tool and version (2026-11-11) | Command |
| --- | --- | --- |
| Dockerfile | hadolint 2.15.1 | `hadolint Dockerfile` |
| Dockerfile, built-in checks | BuildKit through buildx | `docker buildx build --check .` |
| Compose file | Docker Compose | `docker compose config --quiet` |
| nginx configuration | nginx 1.30 | `nginx -t`, with a throwaway certificate in CI |
| Shell scripts | ShellCheck 0.11.0, shfmt 3.14.1 | `shfmt -d .` and `shfmt -f=0 . \| xargs -0 shellcheck` |
| Secrets in the history and the tree | gitleaks 8.30.1 | `gitleaks git` |
| A built image | Trivy 0.76.2 | `trivy image IMAGE` |
| Vulnerabilities, secrets and misconfiguration in the tree | Trivy | `trivy fs --scanners vuln,secret,misconfig .` |

- Run the checks in this order, locally and in the pipeline: format and syntax first, then build, then scans. A cheap failure should come before an expensive one.
- Add gitleaks as a pre-commit hook as well ([secrets](08-secrets-and-configuration.md#detecting-leaks)). The hook catches the mistake before it reaches a remote.
- Mechanical changes (a tool upgrade, a newly enabled check, a bump of pinned images) go in their own commit, so a review shows the change and not the noise.

### Documentation

- A `README.md` says what the service is, how to run it locally and how it is deployed, and links the runbook ([runbooks](13-incident-response-and-runbooks.md#runbooks)).
- When you choose something unusual, write a paragraph about it where the next person will look: a comment next to the line, or `docs/decisions.md`. The reason is the part that cannot be recovered from the code.
- Keep the diagrams to what a reader needs: the hosts, the ports, the data flow and the trust boundaries (what is public, what is internal).

### Provisioning code

- Start with one idempotent provisioning script per server role in `infra/bin/`, written to the [Bash set](../bash-conventions/08-scripts-and-command-line.md): it checks the state before it changes anything, so that running it twice does no harm, and it supports a dry run. Move to a configuration-management tool when you run more than a handful of servers or when a rebuild takes more than an afternoon. This set does not choose the tool. It requires that a server can be rebuilt from the repository.

## Sources and raw notes

Pages read on 2026-11-11:

- Docker Compose: [Compose application model](https://docs.docker.com/compose/intro/compose-application-model/) (file names), [Version and name](https://docs.docker.com/reference/compose-file/version-and-name/) (project name) and [Use Compose in production](https://docs.docker.com/compose/how-tos/production/) (a file per environment).
- [The Twelve-Factor App: Config](https://12factor.net/config) (the same code for every deploy, config from the environment).
- The READMEs of [hadolint](https://github.com/hadolint/hadolint), [Trivy](https://github.com/aquasecurity/trivy) (`trivy image`, `trivy fs --scanners vuln,secret,misconfig`) and [gitleaks](https://github.com/gitleaks/gitleaks) (commands, pre-commit), and the latest releases of the three; [Docker build checks](https://docs.docker.com/build/checks/); the [Bash set](../bash-conventions/01-principles-and-sources.md) for ShellCheck, shfmt and the layout of `bin/`.
- Behaviour checks: the `.gitignore` was tested with `git check-ignore` on sample paths in a scratch repository; `make -n` parsed the Makefile. The directory trees, the names and the allocation table are this set's own conventions and were not applied to a real repository.
