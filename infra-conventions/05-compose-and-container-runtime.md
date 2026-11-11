# Docker Compose and the Container Runtime

## Summary

One `compose.yaml` describes how a project runs on a server. Services pull an immutable image tag, publish ports only on the loopback address (and only the edge publishes at all), reach the database over an `internal` network, read secrets from files, and run read-only, as a non-root user, without capabilities, with resource limits and a health check. Deployment waits for health with `docker compose up --wait`, so an unhealthy release fails the deploy instead of going unnoticed. The Dockerfile that builds the image is in the [previous note](04-docker-images-and-dockerfiles.md).

## Rules

### File, project and services

- Name the file `compose.yaml`. Compose reads `compose.yaml` first and `compose.yml` next, and accepts `docker-compose.yaml` and `docker-compose.yml` only for backward compatibility; if both forms exist it prefers `compose.yaml`.
- No top-level `version:` key. Compose validates against the latest schema regardless of it and warns that it is obsolete.
- Set the project name with a top-level `name:` (`name: shop`). Compose otherwise derives it from the folder, and a folder rename would then create a second project with new volumes.
- Put the differences between environments in a small file per environment (`compose.production.yaml`) and apply it with `docker compose -f compose.yaml -f compose.production.yaml up -d`. The override holds only what differs. The Compose documentation suggests this for production.
- Name services after their role, in lower-case kebab case: `app`, `worker`, `db`, `cache`. Do not set `container_name`: Compose cannot scale a service that has one, and it collides with a second copy of the project.
- Use the Compose plugin (`docker compose`; version 5.6.1 in the Docker 29.9.2 client used for these notes).

### Images

- Every application service has `image:` with an immutable tag from the registry (a commit SHA or a release tag). Never `build:` on the production host and never `latest`; CI builds once and the host only pulls ([CI/CD](10-ci-cd-and-deployment.md#build-once-promote-the-image)).
- Make the tag required, so that a missing value fails at once: `image: registry.example.com/shop/app:${APP_TAG:?set APP_TAG to a commit SHA or release tag}`. Compose stops with `required variable APP_TAG is missing a value: set APP_TAG ...`.
- Pin third-party images the same way (`mysql:8.4.13`), and rebuild or bump them on a schedule ([images](04-docker-images-and-dockerfiles.md#base-images-and-tags)).

### Ports and networks

- **Only the edge publishes ports.** Publishing a container port opens it to the outside world by default, and it ignores `ufw`: Docker routes the traffic in the `nat` table before the chains that `ufw` uses. Publish on the loopback address (`"127.0.0.1:8080:8080"`) so that only the host, and the nginx on it, can reach the port. In Docker releases older than 28.0.0, hosts on the same layer-2 segment could still reach a port published to loopback. Stay on a supported Engine line: 29.9.3 was current on 2026-11-11, and endoflife.date lists the end of support of 28 as 2026-05-13.
- **Databases, caches and queues never publish a port.** Administrators reach them with `docker compose exec db mysql ...` or a short-lived client container on the network, not through a port or an SSH tunnel to a published port.
- **Create networks by role.** `frontend` carries what talks to the edge and to the outside, and `backend` is `internal: true`, which gives it no external connectivity. The application joins both; the database joins only `backend`. In the test run the database container had no route out and the application could reach it by name.
- Give each project a fixed subnet from a table kept in the infra repository (`docs/network.md`, one /24 per project, such as `172.30.10.0/24`), so that database accounts can name the client network ([databases](09-databases-and-data-stores.md#accounts-and-privileges)) and two projects on one host never overlap.
- **No `network_mode: host`.** Docker creates no firewall rules for host networking, so the container's ports become the host's ports and neither Docker's port publishing nor its network isolation applies. If a service cannot work without it, say why in a comment and bind its listener to the loopback address in its own configuration.
- After every deployment run `bin/check_published_ports` ([script](#checking-the-result)) and a scan from outside the network. The MySQL manual makes the same point for database ports: try to reach them from a machine on the internet.
- Leave Docker's firewall alone. Do not set `iptables: false`; Docker's documentation says it will likely break container networking and opens every container port to the local network. To restrict a published port by source address, add a rule to the `DOCKER-USER` chain. The nftables backend introduced in Docker 29.0 is still marked experimental in the documentation, so stay on iptables for now.

### Runtime hardening

Apply these to every service unless a failure message shows that a service cannot run with one. Put the shared ones in an `x-` extension field and merge them with a YAML anchor, as the reference file does.

| Option | Value | Reason |
| --- | --- | --- |
| `restart` | `unless-stopped` | Restarts after a crash and after a reboot, but not after you stop the service on purpose. `always` restarts "until its removal" |
| `init` | `true` | Runs an init process as PID 1 that forwards signals and reaps processes |
| `read_only` | `true` | The root file system is read-only; write to `tmpfs` or to a named volume |
| `tmpfs` | `/tmp` | Writable scratch space in memory |
| `user` | a numeric `UID:GID`, not root | A compromised process is not root inside the container |
| `cap_drop` | `ALL` | Docker grants a default subset of capabilities; add back only what a service proves it needs |
| `security_opt` | `no-new-privileges:true` | A process cannot gain privileges through setuid or setgid binaries |
| `deploy.resources.limits` | `memory`, `cpus`, `pids` | One runaway service cannot starve the host |
| `healthcheck` | per service | Lets Compose wait for health and the monitor see it |
| `stop_grace_period` | `30s` and more for databases | Time to finish in-flight work before SIGKILL |

- `unless-stopped` against `always` is a recorded decision ([decisions](01-principles-and-sources.md#decisions-to-review)).
- **Never** set `privileged: true`, mount `/var/run/docker.sock` into a container, add `cap_add: ALL`, share the host's PID or IPC namespace, or map devices without a written reason. Access to the Docker socket is root access to the host, and mounting it read-only does not make the API read-only (OWASP).
- When an image cannot run read-only or without capabilities, start from `cap_drop: ALL` and add back what its error message names. Two recipes were run: the official MySQL image started and was healthy with `CHOWN`, `DAC_OVERRIDE`, `SETGID` and `SETUID` (tested with `mysql:8.0`; the data lives in a volume), and the official nginx image needs `CHOWN`, `SETGID`, `SETUID` and `NET_BIND_SERVICE` with `tmpfs` on `/var/cache/nginx` and `/run` ([nginx](06-nginx-reverse-proxy.md#nginx-in-a-container)).

### Health and start order

- Give every long-running service a `healthcheck`. If the image has no `curl`, use the application's own flag (`/app/server -healthcheck`) or a tool the image carries (`mysqladmin ping`). A check that needs a tool the image does not have reports unhealthy forever.
- Compose does not wait for readiness unless you ask: on startup it waits only until a container is running. `depends_on` with `condition: service_healthy` waits for the dependency's health check instead. Give slow services a `start_period`.
- **Deploy with `docker compose up -d --wait --wait-timeout 180 --remove-orphans`.** `--wait` returns when the services are running and healthy and fails otherwise. In the test run it returned exit code 1 for a service that stayed unhealthy and 0 once the fixture was fixed. The [deploy script](10-ci-cd-and-deployment.md#the-deploy-script) uses that exit code to roll back.

### Configuration and secrets

- `environment:` holds non-secret settings. Secrets are `secrets:` entries whose source is a file outside the repository; Compose mounts each as `/run/secrets/NAME`, and the application reads the path from a `*_FILE` variable. The official MySQL and PostgreSQL images read `MYSQL_ROOT_PASSWORD_FILE` and its siblings this way; in the test run the root login worked with the password from the file.
- **A file-backed secret is a bind mount.** Compose does not encrypt it. Its documentation says that for a `file:` source the `uid`, `gid` and `mode` options of the long syntax are silently ignored, because a bind mount cannot remap them, so the owner and mode of the host file decide who can read it ([secrets](08-secrets-and-configuration.md#delivering-secrets)). Check that the container user can read it: `docker compose exec app cat /run/secrets/NAME`.
- The `.env` file beside `compose.yaml` feeds the `${VARIABLE}` substitutions (`APP_TAG`). It holds no secrets and is not committed; commit `.env.example` instead.

### Data

- Data lives in named volumes declared at the top level, one per data set (`db-data`). The container's writable layer is for nothing you want to keep. Use bind mounts only for configuration, read-only.
- Never put `docker compose down -v` in a script that runs on a server: it deletes the volumes. `down` alone keeps them. Back up volumes before any change to a database image ([backups](12-backups-and-recovery.md)).

### Logging

- Rely on the daemon's default log driver (`local`, set in `daemon.json`, [server](03-linux-server-baseline.md#docker-daemon)). Override the driver per service only with a reason. Applications write to stdout and stderr.

### Checking the result

- Run `docker compose config --quiet` in CI and before a deploy; it validates the file and the required variables without a daemon. `docker compose config` prints the merged result, which is the way to review an override. `docker compose config --format json | jq` reads it from a script.
- After `up --wait`, list what is published and compare it with the plan:

```bash
bin/check_published_ports --allow 80 --allow 443
```

## Reference file

The file below passed `docker compose config`, and it ran with stand-in images on a local daemon (Docker 29.5.2): `mysql:8.0` for the database and `busybox:1.36` serving a page on port 8080 for the application, because the registry image does not exist. The run showed `up --wait` exiting with 0 once both services were healthy; the application answering on `127.0.0.1:8080`; the database unpublished and without a route out; the application reaching it by name; `/run/secrets/db_app_password` mounted; the root login working with the password from `db_root_password`; and, in `docker inspect`, `ReadonlyRootfs`, `CapDrop: ALL`, `no-new-privileges`, `Init`, a 256-process limit, 512 MB of memory and `unless-stopped`.

```yaml
name: shop

x-service-defaults: &service-defaults
  restart: unless-stopped
  init: true
  read_only: true
  cap_drop:
    - ALL
  security_opt:
    - no-new-privileges:true
  tmpfs:
    - /tmp

services:
  app:
    <<: *service-defaults
    image: registry.example.com/shop/app:${APP_TAG:?set APP_TAG to a commit SHA or release tag}
    user: "10001:10001"
    ports:
      - "127.0.0.1:8080:8080"
    environment:
      APP_ENV: production
      DB_HOST: db
      DB_NAME: shop
      DB_USER: shop_app
      DB_PASSWORD_FILE: /run/secrets/db_app_password
    secrets:
      - db_app_password
    networks:
      - frontend
      - backend
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "/app/server", "-healthcheck"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 20s
    stop_grace_period: 30s
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
          pids: 256

  db:
    image: mysql:8.4.13
    restart: unless-stopped
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - DAC_OVERRIDE
      - SETGID
      - SETUID
    security_opt:
      - no-new-privileges:true
    environment:
      MYSQL_ROOT_PASSWORD_FILE: /run/secrets/db_root_password
      MYSQL_ROOT_HOST: localhost
      MYSQL_DATABASE: shop
    secrets:
      - db_root_password
    volumes:
      - db-data:/var/lib/mysql
    networks:
      - backend
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "--host=127.0.0.1", "--silent"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 60s
    stop_grace_period: 60s
    deploy:
      resources:
        limits:
          memory: 1G

networks:
  frontend: {}
  backend:
    internal: true
    ipam:
      config:
        - subnet: 172.30.10.0/24

volumes:
  db-data: {}

secrets:
  db_root_password:
    file: ./secrets/db_root_password
  db_app_password:
    file: ./secrets/db_app_password
```

- Not run: the `mysql:8.4.13` tag, a registry pull and the application's real `-healthcheck` flag. The capabilities for the MySQL image were found with 8.0 and should be checked again on 8.4.
- The check script (`bin/check_published_ports`) is listed in full in [CI/CD and deployment](10-ci-cd-and-deployment.md#helper-scripts).

## Sources and raw notes

Pages read on 2026-11-11:

- Docker Compose: [Compose application model](https://docs.docker.com/compose/intro/compose-application-model/) (file names), [Version and name](https://docs.docker.com/reference/compose-file/version-and-name/), [Services reference](https://docs.docker.com/reference/compose-file/services/) (`container_name`, `healthcheck`, `init`, `restart`, `security_opt`, `pids_limit`), [Deploy specification](https://docs.docker.com/reference/compose-file/deploy/) (resource limits), [Networks reference](https://docs.docker.com/reference/compose-file/networks/) (`internal`), [Control startup and shutdown order](https://docs.docker.com/compose/how-tos/startup-order/), [Use Compose in production](https://docs.docker.com/compose/how-tos/production/), [Secrets in Compose](https://docs.docker.com/compose/how-tos/use-secrets/) and [`docker compose up`](https://docs.docker.com/reference/cli/docker/compose/up/) (`--wait`, `--wait-timeout`, `--remove-orphans`).
- Docker networking: [Packet filtering and firewalls](https://docs.docker.com/engine/network/packet-filtering-firewalls/) (`ufw`, host networking, `iptables: false`), [Docker with iptables](https://docs.docker.com/engine/network/firewall-iptables/) (`DOCKER-USER`), [Docker with nftables](https://docs.docker.com/engine/network/firewall-nftables/) (experimental since 29.0.0) and [Port publishing and mapping](https://docs.docker.com/engine/network/port-publishing/) (publishing is insecure by default, loopback binding, the 28.0.0 note).
- [Docker Engine 29 release notes](https://docs.docker.com/engine/release-notes/29/): 29.9.3 of 2026-11-03. [endoflife.date: Docker Engine](https://endoflife.date/api/docker-engine.json): support dates of the 28 and 29 lines.
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html): rules 1 (the socket), 3 (capabilities), 4 (no-new-privileges), 5a (`ufw`), 7 (resource limits), 8 (read-only), 12 (secrets).
- The [MySQL](https://github.com/docker-library/docs/blob/master/mysql/README.md) and [nginx](https://github.com/docker-library/docs/blob/master/nginx/README.md) Docker official image READMEs (`*_FILE` variables, read-only mode) and the [MySQL 8.4 Security Guidelines](https://dev.mysql.com/doc/refman/8.4/en/security-guidelines.html) (checking the database port from outside).
- Runs: Docker 29.5.2 on Colima, Compose 5.6.1 client, images `mysql:8.0`, `busybox:1.36` and `nginx:1.27-alpine`.
