# CI/CD and Deployment

## Summary

A pipeline lints, builds, tests, releases and deploys, in that order, and everything it needs is in the repository. The image is built once per commit and tagged with the commit; a release retags that image and never rebuilds it. Every image the pipeline itself uses is pinned. Production is deployed by hand, one deployment at a time, over SSH, with a key that can only run the deploy script; the script pulls the tag, starts the project with `docker compose up --wait` and starts the previous tag again when the new one does not become healthy. The security jobs report findings and do not block by default, so someone must read them. The examples are for GitLab CI; a table at the end maps them to GitHub Actions.

## Rules

### Pipeline shape

- **Stages:** `lint`, `build`, `test`, `release`, `deploy`. GitLab's SAST, Secret Detection and Container Scanning templates all put their jobs in a `test` stage, and Container Scanning documents that a `test` stage must exist.
- Limit pipelines with `workflow:rules` to merge requests, the default branch and tags. Use `rules:` in jobs. `only` and `except` belong to GitLab's page of deprecated keywords.
- Set `default: interruptible: true`, so that a newer push cancels the pipeline it makes redundant. Set `interruptible: false` on the deploy job, so that a push never cancels a deployment half-way.
- Give the deploy job a `resource_group`. Jobs in one resource group are mutually exclusive across pipelines, "similar to semaphores".
- **Pin every image the pipeline uses** (`docker:29.9.3-cli`, `hadolint/hadolint:v2.15.1-debian`, `nginx:1.30-alpine`, `alpine:3.24`), and a database service to the production major and minor (`mysql:8.4`). A bare `golang`, `mysql:latest` or `docker:19.03.12` makes a pipeline break, or pass by luck, when the world moves. Bump the pins on a schedule, as for any other image ([images](04-docker-images-and-dockerfiles.md#base-images-and-tags)).
- **Lint what you ship**, each with a plain command: the Dockerfile (hadolint), the nginx configuration (`nginx -t`, with a throwaway certificate because the configuration names certificate files), the Compose file (`docker compose config --quiet`), shell scripts (shfmt and ShellCheck, [Bash set](../bash-conventions/02-project-setup-and-tooling.md)) and secrets (gitleaks).
- Treat `.gitlab-ci.yml` as code that can steal secrets: protect the default branch, require a review for any change to the pipeline files, and review changes from forks before a pipeline runs ([secrets](08-secrets-and-configuration.md#secrets-in-cicd-gitlab)).

### Build once, promote the image

- **CI builds the image once per commit** and tags it with the full commit SHA (`$CI_COMMIT_SHA`). A release tag (`v1.4.2`) makes a `release` job pull that image and push it again under the tag. Nothing is rebuilt, so the image that passed the tests is the image that ships.
- A deploy names an immutable tag. Not `latest`, not a branch name. The deploy script rejects anything that is not a valid tag.
- The `build` job skips tag pipelines. If a tagged commit never had a pipeline on the default branch, the `release` job fails because the image does not exist, which is the intended outcome.
- Clean up the registry. GitLab's cleanup policy is a scheduled job that expires tags by `name_regex`, keeps the newest `keep_n` and anything younger than `older_than`, and never touches `latest`, protected tags or immutable tags. Keep tags matching `v*`, expire the commit-only tags after a month, and protect or make immutable the release tags so that nobody can overwrite `v1.4.2`.

### Building images in CI

| Approach | Needs | Consequence |
| --- | --- | --- |
| Docker-in-Docker over TLS (`docker:dind`) | A runner in privileged mode | The build is isolated from the runner's Docker, but the runner must be privileged |
| Docker socket binding | Mounts `/var/run/docker.sock` | No privileged mode, but the job controls the host's Docker: GitLab says it "effectively" disables the container's security and exposes the host to privilege escalation |
| BuildKit rootless, Buildah | A rootless setup | No daemon and no privileged mode; more setup |

- The example uses Docker-in-Docker over TLS with the variables from the GitLab documentation (`DOCKER_HOST: tcp://docker:2376`, `DOCKER_TLS_CERTDIR: /certs`). **Build on a runner that is not a production server.** A privileged or socket-bound runner on the machine that serves customers is a way in for anyone who can push a pipeline.
- Log in to the registry with `--password-stdin` and the job's own credentials, never with `-p`.

### Security jobs

- Include the GitLab templates for SAST, Secret Detection and Container Scanning. Their names are `Jobs/SAST.gitlab-ci.yml`, `Jobs/Secret-Detection.gitlab-ci.yml` and `Jobs/Container-Scanning.gitlab-ci.yml`; the old `Security/...` names are stubs that include them. Container Scanning needs the `CS_IMAGE` variable and registry credentials (`CS_REGISTRY_USER`, `CS_REGISTRY_PASSWORD`) when the image is private.
- **These jobs report; they do not block.** All three templates set `allow_failure: true`. Decide who reads the reports and how often (every merge request, plus a weekly look at the default branch), and write it down. A finding that nobody reads protects nothing.
- When a severity must stop a release, add a gate that fails the job: Trivy's `trivy image --exit-code 1 --severity HIGH,CRITICAL IMAGE` (not run here), or the approval policies of your GitLab tier. GitLab's application-security pages list the Free, Premium and Ultimate tiers, and the features differ between them; check what yours includes.
- A pipeline image that is itself part of the supply chain: pin scanner images too, and update them. A tool with access to your registry and secrets is a target.

### Deploying over SSH

- **Staging** deploys on every merge to the default branch. **Production** deploys only from a release tag, with `when: manual`, in a protected `environment` (so that approval and the variables are limited to it), in a `resource_group`, and with `interruptible: false`. OWASP's CI/CD cheat sheet asks for manual approval and review before a production deployment.
- The job connects over SSH as a `deploy` user with a key of its own. The key is a protected, file-type CI/CD variable available only to the production environment, and the host key is pinned with `StrictHostKeyChecking=yes` and a known-hosts file kept in a variable. Never `StrictHostKeyChecking=no`.
- **The key may run one command.** On the server, in the `deploy` user's `authorized_keys`:

```text
restrict,from="203.0.113.0/24",command="/srv/shop/bin/deploy \"$SSH_ORIGINAL_COMMAND\"" ssh-ed25519 AAAA... gitlab-ci-shop
```

- `command="..."` runs that command whenever the key is used and ignores what the client asked for; the client's own command line reaches it in `SSH_ORIGINAL_COMMAND`, here the tag. `restrict` switches off port, agent and X11 forwarding, PTY allocation and `~/.ssh/rc`. `from="..."` limits the source addresses; use it when the runners have fixed addresses and leave it out when they do not.
- **The `deploy` user can use Docker, and Docker access is root access.** The forced command and the validation of the tag in the script are therefore the only barrier. Keep the script short, make it root-owned and not writable by `deploy`, and review every change to it.
- An alternative is a GitLab Runner on the server with the shell executor, so that the pipeline needs no inbound SSH. It moves the trust to the runner: the runner's user runs the pipeline's commands as `deploy`.

### The deploy script

- `bin/deploy TAG` validates the tag, pulls the images, runs `docker compose up -d --wait --wait-timeout 180 --remove-orphans` and records the tag. If the project does not become healthy, it starts the previously recorded tag again and exits with a failure, so the job turns red. Under Bash 5.2 with stub commands it behaved as follows: a missing, malformed or doubled tag exited 2; `v1` deployed and was recorded; `bad` failed, `v1` was started again, the state file kept `v1`, and the exit code was 1.
- **Run database migrations before the new version starts, as their own step**, with the migration account ([databases](09-databases-and-data-stores.md#migrations)). Write each migration so that the previous application version still works with the new schema; the rollback above depends on it. A migration that deletes or reshapes data waits for a later release.
- **Roll back by deploying the previous tag.** There is no rebuild. Rehearse a rollback once a quarter on staging, and after every change to the script. Rolling back data needs a restore ([backups](12-backups-and-recovery.md)), so avoid destructive changes in the release that also changes the schema.
- After the deploy, run a smoke test from outside the server (the health URL over HTTPS) and `bin/check_published_ports` ([helper scripts](#helper-scripts)). Keep the last three image tags on the host and prune older images; never prune volumes.

```bash
#!/usr/bin/env bash
#
# Deploy a tagged release of a Compose project. Pulls the images, starts the
# services, waits until they are healthy and, if they are not, starts the
# previously deployed tag again.
#
# Usage: deploy [-h | --help] TAG
#
# Environment:
#   DEPLOY_DIR           Directory that holds compose.yaml (default /srv/shop).
#   DEPLOY_WAIT_SECONDS  How long to wait for healthy services (default 180).
#
# Requires: Bash 4.4 or newer, Docker with the Compose plugin.

if ((BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1] < 404)); then
  printf '%s: requires Bash 4.4 or newer (found %s)\n' \
    "${0##*/}" "${BASH_VERSION}" >&2
  exit 1
fi

set -euo pipefail
shopt -s inherit_errexit

readonly DEPLOY_DIR="${DEPLOY_DIR:-/srv/shop}"
readonly DEPLOY_WAIT_SECONDS="${DEPLOY_WAIT_SECONDS:-180}"
readonly STATE_FILE="${DEPLOY_DIR}/.deployed_tag"

usage() {
  printf 'Usage: %s [-h | --help] TAG\n' "${0##*/}"
}

err() {
  printf '%s: %s\n' "${0##*/}" "$*" >&2
}

# Pulls the images of a tag, starts the project and waits until every service
# is healthy.
#
# Globals:
#   DEPLOY_DIR, DEPLOY_WAIT_SECONDS
# Arguments:
#   $1: the image tag
# Returns:
#   0 when every service is healthy, non-zero otherwise.
start_release() {
  local tag=$1
  APP_TAG="${tag}" docker compose --project-directory "${DEPLOY_DIR}" \
    pull --quiet || return
  APP_TAG="${tag}" docker compose --project-directory "${DEPLOY_DIR}" \
    up --detach --wait --wait-timeout "${DEPLOY_WAIT_SECONDS}" --remove-orphans
}

main() {
  local tag=""
  while (($#)); do
    case "$1" in
      -h | --help)
        usage
        return 0
        ;;
      -*)
        err "unknown option: $1"
        usage >&2
        return 2
        ;;
      *)
        if [[ -n "${tag}" ]]; then
          err "only one TAG is allowed"
          return 2
        fi
        tag=$1
        ;;
    esac
    shift
  done

  if [[ -z "${tag}" ]]; then
    usage >&2
    return 2
  fi
  local tag_re='^[A-Za-z0-9][A-Za-z0-9._-]*$'
  if [[ ! "${tag}" =~ ${tag_re} ]]; then
    err "invalid tag: ${tag}"
    return 2
  fi

  local previous=""
  if [[ -r "${STATE_FILE}" ]]; then
    read -r previous <"${STATE_FILE}" || true
  fi

  if start_release "${tag}"; then
    printf '%s\n' "${tag}" >"${STATE_FILE}"
    printf 'deployed %s\n' "${tag}"
    return 0
  fi

  err "release ${tag} did not become healthy"
  if [[ -n "${previous}" && "${previous}" != "${tag}" ]]; then
    err "rolling back to ${previous}"
    start_release "${previous}" || err "rollback to ${previous} failed"
  fi
  return 1
}

main "$@"
```

### Helper scripts

- `bin/check_published_ports` lists every container port that is published on all interfaces and exits 1 unless each is allowed. It reads `docker ps`, so it sees exactly what Docker published, and it ignores ports bound to `127.0.0.1`. Run it after a deploy and from a monthly check. In the test it reported a container published on `0.0.0.0` and `[::]` once (not twice), ignored the one published on the loopback address, and exited 0 with `--allow` for that port.

```bash
#!/usr/bin/env bash
#
# Report container ports that are published on every network interface.
#
# Usage: check_published_ports [-h | --help] [--allow PORT]...
#
# Docker publishes a port on 0.0.0.0 and [::] unless the mapping names an
# address, and such a port ignores ufw. This lists every one of them and exits
# 1 unless each is allowed with --allow (for example 80 and 443 on the edge).
#
# Requires: Bash 4.4 or newer, Docker.

if ((BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1] < 404)); then
  printf '%s: requires Bash 4.4 or newer (found %s)\n' \
    "${0##*/}" "${BASH_VERSION}" >&2
  exit 1
fi

set -euo pipefail
shopt -s inherit_errexit

usage() {
  printf 'Usage: %s [-h | --help] [--allow PORT]...\n' "${0##*/}"
}

err() {
  printf '%s: %s\n' "${0##*/}" "$*" >&2
}

# Succeeds when a port is in the list that follows it.
#
# Arguments:
#   $1: the port, then the allowed ports
is_allowed() {
  local port=$1 candidate
  shift
  for candidate in "$@"; do
    if [[ "${candidate}" == "${port}" ]]; then
      return 0
    fi
  done
  return 1
}

main() {
  local -a allowed=()
  while (($#)); do
    case "$1" in
      -h | --help)
        usage
        return 0
        ;;
      --allow)
        if (($# < 2)); then
          err "--allow needs a port"
          return 2
        fi
        allowed+=("$2")
        shift
        ;;
      *)
        err "unknown argument: $1"
        usage >&2
        return 2
        ;;
    esac
    shift
  done

  local status=0 name ports entry port key
  local -A reported=()
  local -a entries
  local entry_re='(0\.0\.0\.0|\[::\]):([0-9-]+)->'
  while IFS=$'\t' read -r name ports; do
    IFS=',' read -ra entries <<<"${ports}"
    for entry in "${entries[@]}"; do
      if [[ ! "${entry}" =~ ${entry_re} ]]; then
        continue
      fi
      port=${BASH_REMATCH[2]}
      key="${name}_${port}"
      if [[ -n "${reported[${key}]-}" ]]; then
        continue
      fi
      reported[${key}]=1
      if ! is_allowed "${port}" "${allowed[@]}"; then
        printf '%s publishes port %s on all interfaces\n' "${name}" "${port}"
        status=1
      fi
    done
  done < <(docker ps --format '{{.Names}}{{"\t"}}{{.Ports}}')
  return "${status}"
}

main "$@"
```

## Reference pipeline

The file below parses as YAML, and each job's stage and `extends` target exist. It was **not** run on a GitLab instance. Its steps were run by hand in the images they name: hadolint 2.15.1 on the example Dockerfile, and the `nginx -t` steps, with the generated certificate, in `nginx:1.30-alpine` (the clean configuration passed; a deliberately broken one was not checked). The three security templates exist at the paths shown, run in the `test` stage and set `allow_failure: true`.

```yaml
include:
  - template: Jobs/SAST.gitlab-ci.yml
  - template: Jobs/Secret-Detection.gitlab-ci.yml
  - template: Jobs/Container-Scanning.gitlab-ci.yml

stages:
  - lint
  - build
  - test
  - release
  - deploy

# Pipelines run for merge requests, the default branch and tags, and nothing else.
workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    - if: $CI_COMMIT_TAG

default:
  interruptible: true

variables:
  IMAGE: $CI_REGISTRY_IMAGE
  # Read by the included Container-Scanning template.
  CS_IMAGE: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  CS_REGISTRY_USER: $CI_REGISTRY_USER
  CS_REGISTRY_PASSWORD: $CI_REGISTRY_PASSWORD

# Docker-in-Docker over TLS, as in the GitLab documentation.
.docker:
  image: docker:29.9.3-cli
  services:
    - name: docker:29.9.3-dind
      variables:
        HEALTHCHECK_TCP_PORT: "2376"
  variables:
    DOCKER_HOST: tcp://docker:2376
    DOCKER_TLS_CERTDIR: /certs
    DOCKER_TLS_VERIFY: "1"
    DOCKER_CERT_PATH: /certs/client
  before_script:
    - echo "$CI_REGISTRY_PASSWORD" | docker login --username "$CI_REGISTRY_USER" --password-stdin "$CI_REGISTRY"

lint:dockerfile:
  stage: lint
  image:
    name: hadolint/hadolint:v2.15.1-debian
    entrypoint: [""]
  script:
    - hadolint Dockerfile

# nginx -t needs the certificate files, so the job makes a throwaway one.
lint:nginx:
  stage: lint
  image:
    name: nginx:1.30-alpine
    entrypoint: [""]
  script:
    - rm -f /etc/nginx/conf.d/default.conf
    - cp deploy/nginx/nginx.conf /etc/nginx/nginx.conf
    - cp -R deploy/nginx/conf.d/. /etc/nginx/conf.d/
    - cp -R deploy/nginx/snippets /etc/nginx/snippets
    - apk add --no-cache openssl
    - mkdir -p /etc/letsencrypt/live/app.example.com
    - >
      openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=lint
      -keyout /etc/letsencrypt/live/app.example.com/privkey.pem
      -out /etc/letsencrypt/live/app.example.com/fullchain.pem
    - nginx -t

# Build once, on every pipeline except a tag pipeline, and tag with the commit.
build:
  extends: .docker
  stage: build
  rules:
    - if: $CI_COMMIT_TAG
      when: never
    - when: on_success
  script:
    - >
      docker build --pull
      --build-arg VCS_REF="$CI_COMMIT_SHA"
      --build-arg VERSION="$CI_COMMIT_SHORT_SHA"
      --tag "$IMAGE:$CI_COMMIT_SHA" .
    - docker push "$IMAGE:$CI_COMMIT_SHA"

# A release tag points the existing image at a version. Nothing is rebuilt.
release:
  extends: .docker
  stage: release
  rules:
    - if: $CI_COMMIT_TAG
  script:
    - docker pull "$IMAGE:$CI_COMMIT_SHA"
    - docker tag "$IMAGE:$CI_COMMIT_SHA" "$IMAGE:$CI_COMMIT_TAG"
    - docker push "$IMAGE:$CI_COMMIT_TAG"

# Production: manual, one at a time, never cancelled half-way. The key can only
# run the deploy script (see the forced command in authorized_keys).
deploy:production:
  stage: deploy
  image: alpine:3.24
  environment:
    name: production
    url: https://app.example.com
  resource_group: production
  interruptible: false
  rules:
    - if: $CI_COMMIT_TAG
      when: manual
  before_script:
    - apk add --no-cache openssh-client
    - chmod 600 "$DEPLOY_SSH_KEY"
  script:
    - >
      ssh -i "$DEPLOY_SSH_KEY" -o UserKnownHostsFile="$DEPLOY_KNOWN_HOSTS"
      -o StrictHostKeyChecking=yes deploy@app.example.com "$CI_COMMIT_TAG"
```

## The same on GitHub Actions

| GitLab CI | GitHub Actions |
| --- | --- |
| Masked, protected and hidden variables | Repository and environment secrets; required reviewers protect environment secrets |
| `id_tokens:` (OIDC) | The workflow's OpenID Connect token, so that cloud credentials are not stored as long-lived secrets |
| Protected `environment`, `when: manual` | Environment protection rules with required reviewers |
| Pinned `image:` | **Pin each action to a full-length commit SHA**; GitHub says this mitigates a backdoor added to the action's repository |

- Restrict the permissions of the `GITHUB_TOKEN` to what each job needs. GitHub also warns that a compromised action can reach all the secrets configured on the repository, so treat a third-party action like code you run with your secrets.

## Sources and raw notes

Pages read on 2026-11-11:

- GitLab: [CI/CD YAML reference](https://docs.gitlab.com/ci/yaml/) (`rules`, `interruptible`, `resource_group`, `needs`, `environment`), [Use Docker to build Docker images](https://docs.gitlab.com/ci/docker/using_docker_build/) and [Docker-in-Docker](https://docs.gitlab.com/ci/docker/docker_in_docker/) (TLS variables, socket binding), [CI/CD variables](https://docs.gitlab.com/ci/variables/), [Reduce container registry storage](https://docs.gitlab.com/user/packages/container_registry/reduce_container_registry_storage/) (cleanup policy), [Deployment safety](https://docs.gitlab.com/ci/environments/deployment_safety/), [Application security testing](https://docs.gitlab.com/user/application_security/) and [Secret detection](https://docs.gitlab.com/user/application_security/secret_detection/) (tiers), and the templates [Jobs/SAST](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/ci/templates/Jobs/SAST.gitlab-ci.yml), [Jobs/Secret-Detection](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/ci/templates/Jobs/Secret-Detection.gitlab-ci.yml) and [Jobs/Container-Scanning](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/ci/templates/Jobs/Container-Scanning.gitlab-ci.yml) (stage, `allow_failure`, `CS_IMAGE`).
- [OWASP CI/CD Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/CI_CD_Security_Cheat_Sheet.html) (pipeline configuration under version control, manual approval for production, least privilege, scanning) and [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html) (secrets in CI/CD tooling and not touched by CI/CD).
- OpenBSD manual [`sshd(8)`](https://man.openbsd.org/sshd.8): `command`, `restrict` and `from` options, `SSH_ORIGINAL_COMMAND`.
- [Docker Compose `up`](https://docs.docker.com/reference/cli/docker/compose/up/) (`--wait`, `--wait-timeout`, `--remove-orphans`); [GitHub Actions: Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use) (pin to a commit SHA, token permissions, environment secrets, third-party actions).
- Docker official images tags for [`docker`](https://github.com/docker-library/official-images/blob/master/library/docker) (29.9.3 `cli` and `dind`) and [`alpine`](https://github.com/docker-library/official-images/blob/master/library/alpine) (3.24); Docker Hub tags of `hadolint/hadolint` (`v2.15.1-debian`) and `aquasec/trivy` (0.76.2).
- Runs: the two scripts were linted with ShellCheck 0.11.0 and shfmt 3.14.1 with the configuration of the [Bash set](../bash-conventions/02-project-setup-and-tooling.md) and run under Bash 5.2.15 in a container without network, with stub `docker`, `restic` and `curl` commands and a `docker ps` fixture taken from a real daemon. The pipeline file was parsed with Ruby's YAML library.
