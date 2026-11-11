# Secrets and Configuration

## Summary

Configuration is what differs between environments; a secret is a configuration value that grants access. Neither is baked into an image or committed to Git. Plain configuration travels in environment variables, secrets travel as files that only the service can read, each secret is generated, unique to one service in one environment, listed in an inventory and rotated on a schedule. A secret that reached a remote repository or a log is treated as stolen: rotate it first and clean up afterwards. Scanners in the pipeline and in a pre-commit hook catch the mistake early.

## Rules

### Configuration

- Follow the Twelve-Factor rule: config is everything likely to vary between deploys (backing-service handles, credentials, hostnames), it is separate from code, and it comes from the environment. The litmus test from the same page: the repository could be made open source at any moment without leaking a credential.
- Commit a `.env.example` with every variable the project reads, fake values and a comment per variable. The real `.env` is in `.gitignore` and `.dockerignore`, and it is not on a developer's laptop with production values.
- Name variables in `UPPER_SNAKE_CASE` with the service as prefix (`SHOP_DB_HOST`). The application reads the environment once at start-up into a typed structure, validates it and stops with a clear message when a value is missing ([Go note](../golang-conventions/11-service-practices.md)).
- Do not branch on an environment name in code. Add a variable instead.

### What counts as a secret

- Database and cache passwords, API keys, tokens, webhook URLs that carry a token, SMTP and registry credentials, session and signing keys, encryption keys, and every private key (TLS, SSH, signing). When in doubt, treat the value as a secret.

### Delivering secrets

- **Prefer a secret manager** if you run one (the cloud provider's, or Vault): the service or the deploy step fetches the value at run time. OWASP prefers a design where the pipeline never touches the application's runtime secrets at all.
- **Without a manager:** the secret lives as a masked, protected variable in the CI/CD system, and the deploy step writes it to a file on the server. The directory is `0700` and each file `0600`, owned by the account that runs the deploy, outside any repository checkout (`/etc/shop/secrets/`).
- **Hand it to the container as a file**, with Compose `secrets:` and a `*_FILE` variable ([Compose](05-compose-and-container-runtime.md#configuration-and-secrets)). This set keeps plain configuration in environment variables, as Twelve-Factor asks, but not secrets, because the Compose documentation warns that environment variables "are often available to all processes" and "can also be printed in logs when debugging errors". A recorded decision ([decisions](01-principles-and-sources.md#decisions-to-review)).
- Compose mounts a `file:` secret as a bind mount and ignores `uid`, `gid` and `mode` for it. Set the owner and mode on the host file, and check that the service's user can read it. Compose does not encrypt the file; protect it with file permissions and disk encryption (OWASP).
- Never put a secret on a command line (`ps` and `docker inspect` show arguments), in `ENV` or `ARG` of a Dockerfile, in a `COPY`, or in a URL. A build that needs one uses a BuildKit secret mount ([images](04-docker-images-and-dockerfiles.md#secrets-and-labels)).
- Never log a secret. Mask it in the CI/CD system, redact it in the application, and keep it out of query strings, because the access log records them ([nginx](06-nginx-reverse-proxy.md#logging)).

### Generating and separating

- Generate secrets; do not invent them. A password manager, or `openssl rand -base64 32`, gives a long random value. The MySQL manual's advice is to choose passwords "as long and as unpredictable as possible".
- **One secret per service per environment.** A shared credential means that the leak of one service is the leak of all, and a stolen staging password must never open production.
- Give a person their own account and key. No shared logins, no shared SSH key, and no personal account in a service's configuration.

### Inventory and rotation

- Keep an inventory of every secret: name, purpose, owner, where it is stored, who can read it, when it was created and when it is due. OWASP asks CI/CD teams to document what they store, to simplify audits and migrations. The inventory holds no values.
- Rotate on a schedule: static credentials at least once a year, CI/CD tokens and anything with broad scope every 90 days. These intervals are a recorded decision.
- **Rotate at once** when someone with access leaves, when exposure is suspected, after an incident, and when a vendor reports a breach ([incidents](13-incident-response-and-runbooks.md#containment)).
- Rotate without downtime: create the new credential, store it, deploy, confirm, then revoke the old one. A service that cannot do that needs two valid credentials for a period; build that in before the first rotation.

### Detecting leaks

- Run a secret scanner in two places: a pre-commit hook on every developer machine, and a CI job on every merge request. gitleaks (8.30.1) offers both (`gitleaks git`, plus a pre-commit entry). GitLab's Secret Detection template is a second net; its job runs in the `test` stage and by default does not fail the pipeline, so someone has to read the result ([CI/CD](10-ci-cd-and-deployment.md#security-jobs)).
- **A secret that was pushed is compromised.** GitLab's documentation states that anyone with access to the repository can use it. Rotate first. Rewriting history comes second, and it does not make the old value safe again.
- The same applies to a secret printed in a job log or an application log, sent in a chat message, or found in an image layer.

### Secrets in CI/CD (GitLab)

- Store CI/CD secrets as variables that are **masked** (not shown in job logs; the value must be a single line of at least 8 characters), **protected** (only pipelines on protected branches and tags get them) and, for new ones, **hidden** (never shown again in the settings). Scope production variables to the production environment.
- Masking is not a guarantee: GitLab warns that it does not stop a malicious user from reading a value, and recommends external secrets or file-type variables to keep `env` and `printenv` from printing it. Anyone who can change `.gitlab-ci.yml` can send a variable to a server of their choosing, so review every merge request that changes it before a pipeline runs, especially from a fork. Do not trigger a pipeline for suspicious code.
- Prefer short-lived tokens to stored keys: a job can ask GitLab for an OpenID Connect ID token (`id_tokens:`) and exchange it with a cloud provider or a secret manager. No static cloud key then lives in the CI/CD settings.
- The deploy credential can do one thing: run the deploy script on one server (see the forced command in [CI/CD](10-ci-cd-and-deployment.md#deploying-over-ssh)). It is not an administrator's key.

### Keys and certificates

- TLS private keys belong to root and are readable by root alone (`0600`). They are never in a repository or an image. certbot keeps its keys under `/etc/letsencrypt/`; check once that the key files are not readable by other accounts, and that no container mounts that directory read-write.
- SSH keys are Ed25519, one per person per device, with a passphrase. Review `authorized_keys` every quarter and remove keys of people and systems that left. Keep agent forwarding off.
- The key that encrypts backups is stored apart from the backups and from the server that makes them. If the key sits on the server, whoever owns the server owns the backups ([backups](12-backups-and-recovery.md)).

## Sources and raw notes

Pages read on 2026-11-11:

- [The Twelve-Factor App: Config](https://12factor.net/config) (separate config from code, environment variables, the open-source litmus test).
- Docker Compose: [Manage secrets securely in Docker Compose](https://docs.docker.com/compose/how-tos/use-secrets/) (environment variables against files) and the [services reference](https://docs.docker.com/reference/compose-file/services/) (`uid`, `gid` and `mode` are ignored for `file:` secrets).
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html) (where a secret should be, CI/CD storage, documenting stored secrets, rotation, injection into containers), [OWASP CI/CD Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/CI_CD_Security_Cheat_Sheet.html) (secrets management, least privilege, identity lifecycle) and [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html) (rule 12).
- GitLab: [CI/CD variables](https://docs.gitlab.com/ci/variables/) (masked, hidden, protected, file type, the security section), [OpenID Connect ID tokens](https://docs.gitlab.com/ci/secrets/id_token_authentication/) and [Secret detection](https://docs.gitlab.com/user/application_security/secret_detection/).
- [gitleaks README](https://github.com/gitleaks/gitleaks) (commands, pre-commit) and [release](https://github.com/gitleaks/gitleaks/releases/latest) (8.30.1).
- [MySQL 8.4 Security Guidelines](https://dev.mysql.com/doc/refman/8.4/en/security-guidelines.html) (password choice) and [OWASP Database Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Database_Security_Cheat_Sheet.html) (storing credentials, changing them when staff leave).
- Behaviour checks: the `_FILE` secret, its mount at `/run/secrets/` and the root login from it were run in the Compose test ([Compose note](05-compose-and-container-runtime.md#reference-file)). The scanners, the rotation intervals and the CI settings were not run.
