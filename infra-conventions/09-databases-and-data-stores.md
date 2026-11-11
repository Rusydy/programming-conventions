# Databases and Data Stores

## Summary

A database is never reachable from the internet. The application reaches it over an internal network with an account that can do only what the application does: read and change rows of its own schema, nothing else. Migrations, reporting and backups each get their own account. Run a supported version, keep `root` inside the container, restrict every account to the client network, and watch the error log, because an injection probe leaves syntax errors behind. These rules do not stop SQL injection. They decide how much an injected statement can read, change or destroy, and the cure for the injection is parameterised queries in the application ([abuse control](07-abuse-control-and-edge-protection.md)). The examples use MySQL; the same shape applies to PostgreSQL, and the last section covers Redis and other stores.

## Rules

### Versions

| Product | Use | Facts on 2026-11-11 |
| --- | --- | --- |
| MySQL | 8.4 LTS (8.4.13) or 9.7 LTS (9.7.4) | 8.4 is supported to 2032-04-30 and 9.7 to 2034-04-30 (endoflife.date). Oracle moved **8.0** to Sustaining Support on 2026-04-21 and advises 8.4 LTS or 9.7 LTS; the official Docker image no longer lists 8.0 |
| PostgreSQL | 18 (18.6) | A major version is supported for five years. 14 reaches end of life on 2026-11-12 and 15 on 2027-11-11 |
| Redis | 8.x (8.10.3) | Current line in the official image |

- Run an LTS release in production. `mysql:latest` is now the 26.10 innovation release, so a pipeline that tests against `latest` tests a different server from the one in production.
- **Use the same major and minor version in CI, staging and production**, pinned to a tag (`mysql:8.4`, not `latest`). Pin the patch version in Compose files ([Compose](05-compose-and-container-runtime.md#images)).
- Write the end-of-life date of each database in the runbook and plan the upgrade six months before it. Upgrade one major version at a time, after a verified restore of a backup into the new version ([backups](12-backups-and-recovery.md)).

### Placement

- **The database publishes no port.** In Compose it has no `ports:` and sits only on an `internal: true` network ([Compose](05-compose-and-container-runtime.md#ports-and-networks)). OWASP's database cheat sheet gives the same options in other words: bind to localhost or an internal segment, and restrict the port to specific hosts with firewall rules.
- The MySQL manual's check is the one to use: scan the host's ports from a machine on the internet, or try `telnet host 3306`. If you get a connection, close the port.
- Administrators connect with `docker compose exec db mysql ...`. Web-based tools such as phpMyAdmin or Adminer are not exposed; if one is needed, put it behind the VPN, TLS and authentication (OWASP).
- Encrypt the connection whenever it crosses a host boundary: OWASP asks for encrypted connections only, TLS 1.2 or later, with the client verifying the server certificate; the MySQL manual says to use SSL or an SSH tunnel and never plain text over the internet. Inside one host's `internal` network it is optional.

### Accounts and privileges

- **One account for each application and each role.** `shop_app` for the running application, `shop_migrate` for the migration job, `shop_report` for read-only reporting, `shop_backup` for the dump, `shop_monitor` for the error counters. Development, staging and production use separate databases and separate accounts (OWASP).
- **The runtime account can change data and nothing else:** `SELECT, INSERT, UPDATE, DELETE` on its own schema. No `CREATE`, `ALTER`, `DROP`, `GRANT OPTION`, no `FILE`, no administrative privilege, and it does not own the schema. OWASP: "do not assign DBA or admin type access to your application accounts", and "rarely, if ever, grant create or delete access".
- **Name the client network in the account:** `'shop_app'@'172.30.10.%'`, never `'%'`. The MySQL manual says: "Never grant privileges to all hosts." The Compose subnet is fixed per project so this works ([Compose](05-compose-and-container-runtime.md#ports-and-networks)).
- **Keep `root` inside the container.** The official MySQL image creates both `root@localhost` and `root@%`, so root accepts a password from any host that can reach the server. Set `MYSQL_ROOT_HOST: localhost`: only `root@localhost` is then created, and a network login as root from another container failed with `ERROR 1130 Host ... is not allowed to connect`. Applications never use root.
- After you create the accounts, review them: `SELECT user, host FROM mysql.user;` and `SHOW GRANTS FOR 'shop_app'@'172.30.10.%';`. The MySQL manual's checklist includes `SHOW GRANTS` and `REVOKE` for what is not needed.
- Where one feature needs less than the whole schema, narrow it further: grant a view instead of a table, or column-level privileges, and give the login feature its own account. OWASP's example is a login page that needs to read the credentials table and never write to it.
- Credentials are generated, unique, kept in the secret store ([secrets](08-secrets-and-configuration.md)), and changed when someone with access leaves or when exposure is suspected (OWASP).

The accounts below were created on a throwaway server (the official `mysql:8.0` image) and tested from a client container whose address was inside `172.30.10.0/24`. For the application account:

| Statement | Result |
| --- | --- |
| `INSERT`, `UPDATE`, `SELECT`, `DELETE` on `shop` | Allowed |
| `CREATE TABLE`, `DROP TABLE`, `ALTER TABLE` | `ERROR 1142 ... command denied` |
| `SELECT ... INTO OUTFILE '/tmp/out.txt'` | `ERROR 1227 ... you need the FILE privilege` |
| `SELECT LOAD_FILE('/etc/passwd')` | `NULL` (no file privilege) |
| `GRANT ALL ON shop.* ...` and `DROP DATABASE shop` | `ERROR 1044 ... Access denied` |
| `SELECT user FROM mysql.user` | `ERROR 1142 ... command denied` |

The reporting account read the data and failed on `INSERT`. The backup account produced a dump with the routines and the view (see below), and the monitoring account read its one table (see [containment](#containment-and-detection)).

```sql
-- Accounts for one application. Run once, as an administrator, from a
-- migration or provisioning step. Replace the placeholders with generated
-- values from the secret store; never commit real passwords.
--
-- 172.30.10.% is the fixed subnet of the internal "backend" network.

-- Schema owner: used only by the migration job.
CREATE USER 'shop_migrate'@'172.30.10.%' IDENTIFIED BY 'change-me-migrate';
GRANT ALL PRIVILEGES ON shop.* TO 'shop_migrate'@'172.30.10.%';

-- Runtime account: data changes only, no schema changes.
CREATE USER 'shop_app'@'172.30.10.%' IDENTIFIED BY 'change-me-app';
GRANT SELECT, INSERT, UPDATE, DELETE ON shop.* TO 'shop_app'@'172.30.10.%';

-- Reporting account: read-only.
CREATE USER 'shop_report'@'172.30.10.%' IDENTIFIED BY 'change-me-report';
GRANT SELECT ON shop.* TO 'shop_report'@'172.30.10.%';

-- Backup account: what mysqldump needs with --single-transaction, --routines,
-- --events and --no-tablespaces.
CREATE USER 'shop_backup'@'172.30.10.%' IDENTIFIED BY 'change-me-backup';
GRANT SELECT, SHOW VIEW, TRIGGER, EVENT ON shop.* TO 'shop_backup'@'172.30.10.%';
GRANT SHOW_ROUTINE ON *.* TO 'shop_backup'@'172.30.10.%';

-- Monitoring account: reads one Performance Schema table with the counters of
-- errors that clients provoked (parse errors, unknown columns, unknown tables).
CREATE USER 'shop_monitor'@'172.30.10.%' IDENTIFIED BY 'change-me-monitor';
GRANT SELECT ON performance_schema.events_errors_summary_global_by_error
  TO 'shop_monitor'@'172.30.10.%';
```

- `GRANT ALL PRIVILEGES ON shop.*` for the migration account is the widest account in the set. It exists only for the duration of the migration job; the application never holds it, so a compromised application cannot change the schema.
- **A backup account needs `--no-tablespaces`.** Without it `mysqldump` stops with `Access denied; you need (at least one of) the PROCESS privilege(s) for this operation`, because it wants to dump tablespaces. With `--single-transaction --routines --triggers --events --no-tablespaces` and the grants above, the dump contained the procedure and the view. `SHOW_ROUTINE` is a global privilege; it is the only global one in the set.
- Not run: MySQL 8.4 and 9.7 (the test image was 8.0, because it was the one on the machine). Run the SQL and the table above again on the version you deploy.

### Migrations

- Schema changes run as a separate step with the migration account, before the new application version starts, and they are forward-only SQL files, never edited after they merge ([Go note](../golang-conventions/11-service-practices.md)). A change that the previous application version cannot work with is split into two releases.
- The application does not create or alter tables at start-up. It cannot, and that is the point.

### Containment and detection

- Assume the injection will one day get through. Then the account's grants are the blast radius: with the account above, an attacker reads and rewrites the rows of one schema. Keep sensitive columns (identity numbers, bank details) in tables or views that the runtime account reads only where a feature needs them.
- **Count the errors that clients provoke, and alert on a rise.** A probe that sends `'` or `UNION SELECT` to a parameter that is concatenated into SQL produces syntax errors (1064), unknown-column errors (1054) and unknown-table errors (1146) that normal traffic does not. **MySQL does not write these to its error log, and the general query log is off by default**: in a test, the error log was unchanged after two bad statements. Two places do show them. The application receives the error and logs it with the request ID ([abuse control](07-abuse-control-and-edge-protection.md#what-to-ask-of-the-application)). And Performance Schema counts them: `SELECT error_name, sum_error_raised FROM performance_schema.events_errors_summary_global_by_error WHERE error_name IN ('ER_PARSE_ERROR', 'ER_BAD_FIELD_ERROR', 'ER_NO_SUCH_TABLE')`. In the test the counters rose by 2, 1 and 1 after four bad statements. Have the monitoring system read these counters every minute with the `shop_monitor` account and alert on a rise over the baseline ([logging](11-logging-monitoring-and-alerting.md#security-signals)). That account holds `SELECT` on that one table: it read the counters and was refused `performance_schema.users` and `mysql.user`.
- The server writes its own error log to stderr in a container, so `docker logs` carries start-up problems, crashes and failed start-ups (19 server lines in the test). Enable the slow-query log, and turn on an audit log if the data is sensitive and the edition offers one; decide it per system and write the decision in the runbook. Use the general query log only during an investigation, because it records every statement.

### Containers and volumes

- Data lives in one named volume per database and is covered by the backup. The init variables (`MYSQL_DATABASE`, `MYSQL_ROOT_PASSWORD_FILE`) and the files in `/docker-entrypoint-initdb.d` take effect only when the container starts for the first time on an empty data directory; changing them later changes nothing.
- Give the database a memory limit and a long `stop_grace_period` (60 seconds in the reference) so that a stop does not kill it in the middle of a flush. Do not run the data directory on the same small disk as the logs ([server](03-linux-server-baseline.md#disk-time-and-logs)).
- Official images accept the secret as a file (`MYSQL_ROOT_PASSWORD_FILE`, `POSTGRES_PASSWORD_FILE`), which is how Compose delivers it ([Compose](05-compose-and-container-runtime.md#configuration-and-secrets)).
- For PostgreSQL: do not set `POSTGRES_HOST_AUTH_METHOD=trust`. The image warns that `trust` lets anyone connect without a password. Keep `listen_addresses` and the `pg_hba.conf` entries to the application network, and use roles with the same split as above.

### Redis and other data stores

- Redis is designed for "trusted clients inside trusted environments", and its documentation advises against exposing it directly to the internet. Never publish its port; put it on the internal network; keep protected mode on. Require authentication: ACL users since Redis 6 are the recommended method, and `requirepass` is the legacy one. A single `FLUSHALL` from an outside attacker deletes the whole data set.
- The same rules hold for every other store (a document database, an object store, a message queue): authentication on, default credentials changed, reachable only from the application network, backed up and restored on a schedule. Read the vendor's security checklist before the first deploy and record any exception in the runbook.

## Sources and raw notes

Pages read on 2026-11-11:

- [OWASP Database Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Database_Security_Cheat_Sheet.html) (isolation, transport protection, authentication, least privilege, hardening, `FILE`) and [OWASP SQL Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html) (parameterised queries, least privilege, views, separate accounts).
- MySQL: [8.4 Security Guidelines](https://dev.mysql.com/doc/refman/8.4/en/security-guidelines.html) (grants for hosts, `SHOW GRANTS`, scanning the port from the internet, SSL or SSH), [Support EOL announcements](https://www.mysql.com/support/eol-notice.html) (8.0 in Sustaining Support from 2026-04-21), [endoflife.date: MySQL](https://endoflife.date/api/mysql.json) and the [`mysql` official image](https://github.com/docker-library/official-images/blob/master/library/mysql) tag list. The [Docker image README](https://github.com/docker-library/docs/blob/master/mysql/README.md): `_FILE` variables and first-start initialisation.
- PostgreSQL: [Versioning Policy](https://www.postgresql.org/support/versioning/), [endoflife.date: PostgreSQL](https://endoflife.date/api/postgresql.json) and the [Docker image README](https://github.com/docker-library/docs/blob/master/postgres/README.md) (`POSTGRES_PASSWORD_FILE`, `trust`).
- Redis: [Redis security](https://redis.io/docs/latest/operate/oss_and_stack/management/security/) (trusted environments, network security, protected mode, ACL and `requirepass`) and the [Redis official image](https://github.com/docker-library/official-images/blob/master/library/redis) tags.
- Behaviour checks: the account SQL (four accounts first, the monitoring account in a later run), the six denied statements, the read-only account and the dump with and without `--no-tablespaces`, run on `mysql:8.0` (the version on the machine) with client containers on a Docker network of `172.30.10.0/24`. The default accounts of the image (`root@%` and `root@localhost`) and the effect of `MYSQL_ROOT_HOST=localhost` (only `root@localhost`; network login refused with error 1130) were listed and tried on the same image. On the same image, four bad statements raised the Performance Schema counters (`ER_PARSE_ERROR` 2, `ER_BAD_FIELD_ERROR` 1, `ER_NO_SUCH_TABLE` 1), two of them left the container log unchanged, `general_log` was `OFF`, and the monitoring account read the counters but not `performance_schema.users` or `mysql.user`. The [MySQL binary log page](https://dev.mysql.com/doc/refman/8.4/en/binary-log.html) names the general query log as the way to log all statements.
