# Docker Images and Dockerfiles

## Summary

An image is built once, in CI, from a small trusted base that is pinned by tag and digest. It uses a multi-stage build, installs only what the service runs on, creates a numeric non-root user, carries a health check and OCI labels, and holds no secret. It is rebuilt every week with `--pull` so that security fixes of the base arrive, and it is linted (hadolint, BuildKit checks) and scanned before it is pushed. The way containers are run is in the [Compose note](05-compose-and-container-runtime.md); for a Next.js service, the Docker section of the [Next.js deployment note](../nextjs-conventions/12-deployment-and-self-hosting.md) has the matching Dockerfile.

## Rules

### Base images and tags

- Start from an image you can trust: a Docker Official Image, a Verified Publisher image or a Docker-Sponsored Open Source image, as the Docker documentation lists them. Docker Hardened Images, which have a free Community subscription, are an option for services that want a smaller attack surface; none of the examples here depends on them.
- Choose the smallest image that has what the service needs. A smaller image has fewer packages and so fewer vulnerabilities. Use one image to build and another, slimmer one to run.

| Stack | Build image | Run image |
| --- | --- | --- |
| Go service | `golang:<version>-alpine` | `debian:<codename>-slim` with `ca-certificates` and `tzdata` (a hardened static image when the service needs no OS package) |
| Node.js, Next.js | `node:<LTS>-slim` | `node:<LTS>-slim` ([Next.js note](../nextjs-conventions/12-deployment-and-self-hosting.md)) |
| Python | `python:<version>-slim` | `python:<version>-slim` |
| nginx | none | `nginx:<stable>-alpine` |

- This note prefers Debian slim to Alpine for language runtimes, as the Next.js note does, because musl differences cause native-module problems. Alpine is fine for the build stage of a statically linked binary and for nginx. This is a recorded decision ([decisions](01-principles-and-sources.md#decisions-to-review)).
- **Pin the tag and the digest:** `golang:1.27-alpine@sha256:...`. A tag is mutable and may resolve to a different image next month; a digest always names the same one. Keep the tag in front of the digest, so a reader sees the version.
- **A digest pin switches off automatic fixes.** The Docker documentation says so, and recommends a bot that opens pull requests for new tags and digests (Dependabot with `package-ecosystem: "docker"`). On GitLab, run a scheduled job or bot that opens a merge request with the new digest each week, and treat that merge request as routine work.
- Tag the images you build with the commit SHA. Add a release tag (`v1.4.2`) that points at the same image. Never deploy `latest` ([CI/CD](10-ci-cd-and-deployment.md#build-once-promote-the-image)).
- Keep the supported lines current. On 2026-11-11 the official images carried Go 1.27.4, nginx 1.30 (stable) and 1.31 (mainline), MySQL 8.4, 9.7 and 26.10, PostgreSQL 18 and Debian 13 "trixie". The official `mysql` image no longer lists 8.0 ([databases](09-databases-and-data-stores.md#versions)).

### Build

- Begin the file with `# syntax=docker/dockerfile:1` and build with BuildKit.
- **Multi-stage builds:** build in one stage and copy only the result into the run stage with `COPY --from=build`. Compilers, source code and package caches never reach the final image.
- **Order the layers by how often they change:** copy the dependency files first (`go.mod`, `go.sum`, `package-lock.json`), install, then copy the source. The dependency layer is reused until the dependency files change. Use cache mounts (`RUN --mount=type=cache,target=/go/pkg/mod`) to keep downloaded modules between builds.
- **A build does not change the dependencies.** For Go, run `go mod download` and `go build`; never `go mod tidy`, which edits `go.mod` silently inside the build. Run `go mod tidy` before you commit ([Go note](../golang-conventions/03-project-setup-and-tooling.md)). Build static binaries with `CGO_ENABLED=0 go build -trimpath`.
- Add a `.dockerignore` so that `COPY . .` does not send `.git`, `.env*`, `secrets/` or documentation into the build.
- Use `COPY`, not `ADD`, for local files. Use `ADD --checksum=sha256:...` for a remote file you cannot avoid, or download it in a build stage and verify it. Never pipe a download into a shell.
- Install packages in one `RUN`: `apt-get update && apt-get install -y --no-install-recommends ... && rm -rf /var/lib/apt/lists/*`. Sort the package list, one per line. Do not run `apt-get upgrade`; a rebuild on a new base image does that.
- `apt-get install` without package versions makes hadolint report `DL3008`. This set does not pin Debian package versions, because the base image is pinned by digest and rebuilt weekly, and a pinned package version breaks the rebuild whenever Debian ships a security update. Put `# hadolint ignore=DL3008` on the line above, with that reason in a comment. This is a recorded decision.
- Start any `RUN` that uses a pipe with `set -o pipefail &&`; the `sh` of Debian-based images cannot do it, so use the exec form with `bash -c` there.
- Use absolute paths in `WORKDIR`, and `WORKDIR` instead of `RUN cd`.

### Run

- **Create a non-root user with a fixed numeric ID** and switch to it: `groupadd --gid 10001 app`, `useradd --uid 10001 --gid 10001 --no-log-init --no-create-home --shell /usr/sbin/nologin app`, `USER 10001:10001`. A fixed ID keeps file ownership stable across rebuilds; `--no-log-init` avoids the disk-exhaustion bug of large IDs that the Docker documentation describes. Do not install or use `sudo`.
- The service must work with a read-only root file system. It writes only to a path that Compose mounts as `tmpfs` or as a volume ([Compose](05-compose-and-container-runtime.md#runtime-hardening)).
- **Add a `HEALTHCHECK`** that uses something already in the image. A small service gets a `-healthcheck` flag of its own that probes its own endpoint and exits 0 or 1, so the image needs no `curl` or `wget`.
- Use the exec form for `ENTRYPOINT` and `CMD`: `ENTRYPOINT ["/usr/local/bin/app"]`. The process then receives SIGTERM directly and can stop gracefully. The shell form starts a shell as PID 1.
- `EXPOSE` documents the port; it publishes nothing. Use the port the service listens on.
- One service per image. Decouple the web application, the database and the cache.

### Secrets and labels

- **A secret never goes into the image.** `ARG` and `ENV` values persist in the image, and a file that a later layer deletes is still in the earlier layer (the Docker documentation shows `docker run ... echo $ADMIN_USER` printing a value that was "unset" in a later instruction). Pass a build-time secret with `docker build --secret id=name,src=file` and read it in one instruction with `RUN --mount=type=secret,id=name`. It exists only for that instruction ([secrets](08-secrets-and-configuration.md)).
- Label every image with the OCI keys that identify it: `org.opencontainers.image.source` (the repository URL), `org.opencontainers.image.revision` (the commit) and `org.opencontainers.image.version`. CI passes the last two as build arguments. They are not secrets.

### Lint, scan and rebuild

- Run hadolint in CI (`hadolint Dockerfile`; 2.15.1 on 2026-11-11). OWASP lists what such a linter catches: a missing `USER`, an unpinned base image or package versions, `ADD` instead of `COPY`, and piped installers.
- Run BuildKit's own checks, `docker buildx build --check .`, which list problems in the Dockerfile without building.
- Scan the built image for known vulnerabilities in CI and fail the pipeline on fixable high and critical findings on the default branch. Trivy (0.76.2) is one tool: `trivy image IMAGE`. GitLab's Container Scanning template reports findings but, by default, does not fail the pipeline ([CI/CD](10-ci-cd-and-deployment.md#security-jobs)).
- Rebuild every image weekly with `docker build --pull` from a scheduled pipeline, even when the code did not change. The image is a snapshot of its base and libraries at build time, and old images keep old vulnerabilities. `--no-cache` forces fresh package downloads when you need them.
- Produce a software bill of materials, record the provenance, and sign the image when the registry and the clients can check it (OWASP rule 13). Treat that as a later step, after the pipeline above is routine.
- Build without `--privileged`. Docker-in-Docker needs a privileged runner, and binding the Docker socket gives every job root on the host; GitLab documents BuildKit in rootless mode and Buildah as alternatives ([CI/CD](10-ci-cd-and-deployment.md#building-images-in-ci)).

## Reference Dockerfile

This Dockerfile builds a Go service. It was linted with hadolint 2.15.1 (clean, with the `DL3008` ignore; without the ignore it reports exactly that warning), passed `docker buildx build --check` ("no warnings found"), and was built with BuildKit 0.30.0 in Docker 29.5.2. The test service listens on port 8080 and has a `-healthcheck` flag. The image ran with `--read-only`, `--cap-drop ALL` and `no-new-privileges`, became healthy, ran as `uid=10001(app)`, refused a write to `/etc` and carried the three labels. The digests are those of 2026-11-11.

```dockerfile
# syntax=docker/dockerfile:1

# A tag for the reader and a digest for repeatability (digests of 2026-11-11).
ARG GO_IMAGE=golang:1.27-alpine@sha256:eb61c3873c97416fff0116553fff65d67a3549f72e11d9758849a689cdd8b523
ARG RUNTIME_IMAGE=debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2

FROM ${GO_IMAGE} AS build
WORKDIR /src

# Dependencies first: this layer is reused until go.mod or go.sum change.
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/app ./cmd/app

FROM ${RUNTIME_IMAGE}

# Versions are not pinned: the base image is pinned by digest and the image is
# rebuilt with --pull every week, so security updates arrive with the rebuild.
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 app \
    && useradd --uid 10001 --gid 10001 --no-log-init --no-create-home \
      --shell /usr/sbin/nologin app

COPY --from=build /out/app /usr/local/bin/app

ARG VCS_REF=unknown
ARG VERSION=dev
LABEL org.opencontainers.image.source="https://gitlab.example.com/shop/app" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.version="${VERSION}"

USER 10001:10001
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD ["/usr/local/bin/app", "-healthcheck"]
ENTRYPOINT ["/usr/local/bin/app"]
```

```text
# .dockerignore
.git
.gitignore
.env
.env.*
!.env.example
secrets/
*.md
Dockerfile
compose*.yaml
```

- The image was 154 MB with the Debian slim run stage. The local Docker client had no `buildx` plugin, so the checks and the build ran with the `docker buildx` of the Colima virtual machine (buildx 0.34.1, BuildKit 0.30.0).
- Not run: Trivy and image signing. The build-argument values (`VCS_REF`, `VERSION`) came from the command line, not from a pipeline.

## Sources and raw notes

Pages read on 2026-11-11:

- Docker: [Building best practices](https://docs.docker.com/build/building/best-practices/) (multi-stage, base image choice, `--pull`, pinning and digests, Dependabot, `.dockerignore`, `apt-get`, pipes, `ENV`, `ADD` and `COPY`, `USER`, `WORKDIR`), [Build secrets](https://docs.docker.com/build/building/secrets/), [Build checks](https://docs.docker.com/build/checks/) and [Docker Hardened Images](https://docs.docker.com/dhi/).
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html): rules 2 (user), 9 (scanning and Dockerfile linting), 12 (build-time secrets), 13 (supply chain).
- [OCI image specification: annotations](https://github.com/opencontainers/image-spec/blob/main/annotations.md): `source`, `revision`, `version`.
- Docker official images, tag lists: [golang](https://github.com/docker-library/official-images/blob/master/library/golang), [debian](https://github.com/docker-library/official-images/blob/master/library/debian), [nginx](https://github.com/docker-library/official-images/blob/master/library/nginx), [mysql](https://github.com/docker-library/official-images/blob/master/library/mysql), [postgres](https://github.com/docker-library/official-images/blob/master/library/postgres).
- Tools: the [hadolint README](https://github.com/hadolint/hadolint) and [release](https://github.com/hadolint/hadolint/releases/latest) (2.15.1), the [Trivy README](https://github.com/aquasecurity/trivy) and [release](https://github.com/aquasecurity/trivy/releases/latest) (0.76.2).
- GitLab: [Use Docker to build Docker images](https://docs.gitlab.com/ci/docker/using_docker_build/) (privileged mode, socket binding, BuildKit and Buildah alternatives).
- Runs: `hadolint/hadolint:v2.15.1-debian`, `golang:1.27-alpine` (Go 1.27.4), `debian:trixie-slim` (Debian 13.7) on Docker 29.5.2 and buildx 0.34.1 in Colima.
