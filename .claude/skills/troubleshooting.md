---
skill: troubleshoot-docker-deploy
description: Debug common issues when using the fccn.ansible_docker_deploy Ansible role
role_source: git+https://github.com/fccn/ansible-docker-deploy.git
role_galaxy: fccn.ansible_docker_deploy
---

# Troubleshooting ansible-docker-deploy

## "You need to define at least one of..." error

**Cause:** Neither `docker_deploy_compose_template` nor `docker_deploy_shell_start` is defined.

**Fix:** Ensure your wrapper role passes at least one:
```yaml
include_role:
  name: ansible-docker-deploy
vars:
  docker_deploy_compose_template: "{{ myapp_docker_deploy_compose_template }}"
```

Check that the variable is defined in `defaults/main.yml` and not accidentally overridden to `undefined`.

## Health check never becomes healthy

**Symptoms:** Task "Wait for containers to be healthy" retries exhaustively and fails.

**Diagnosis:**
```bash
# On the target host:
docker ps --format "table {{.Names}}\t{{.Status}}"
docker inspect --format='{{.State.Health.Status}}' <container_name>
docker inspect --format='{{json .State.Health}}' <container_name>
```

**Common causes:**
1. **No HEALTHCHECK in Dockerfile or compose** — the role checks for `(healthy)` status, which requires a health check to be defined
2. **Health check command fails** — test the command manually inside the container
3. **Insufficient retries/delay** — increase timing:
   ```yaml
   myapp_docker_deploy_healthcheck_delay: 15    # seconds between checks
   myapp_docker_deploy_healthcheck_retries: 30  # total attempts
   ```
4. **Container crashes on start** — check `docker logs <container>`

**Disable health check** (not recommended for production):
```yaml
docker_deploy_healthcheck: false
```

## Template rendering fails

**Symptoms:** Jinja2 error during template rendering.

**Common causes:**

1. **Undefined variable** — ensure all variables used in templates have defaults:
   ```yaml
   # defaults/main.yml
   myapp_port: "8080"  # Must have a value
   ```

2. **Helper macro import fails** — verify the import line is correct:
   ```yaml
   {% import '_docker_deploy_helper.j2' as helper with context %}
   ```
   The `with context` part is required for the macros to access role variables.

3. **Missing checksum facts** — if using helper macros but `docker_deploy_configs`/`docker_deploy_secrets` lists are empty, the checksum dictionaries won't exist. Ensure entries with `config_name`/`secret_name` are in `docker_deploy_templates` or `docker_deploy_files`.

## "docker compose" vs "docker-compose" detection issues

**How auto-detection works:** The role checks if `docker compose version` succeeds on the target host. If yes, uses `docker compose` (v2 plugin). If not, falls back to `docker-compose` (v1 standalone).

**Force a specific command:**
```yaml
docker_deploy_compose_bin: "docker compose"     # Force v2 plugin
docker_deploy_compose_bin: "docker-compose"     # Force v1 standalone
docker_deploy_compose_bin: "auto"               # Auto-detect (default)
```

**Common issue:** Ansible connects as a different user than who has Docker Compose installed. Verify:
```bash
ansible target_host -m shell -a "docker compose version"
```

## Configs/secrets not updating after content change

**Symptoms:** You changed a template but the container doesn't pick up the new config.

**Diagnosis:** The checksum mechanism should detect changes automatically. If it doesn't:

1. **Template rendered identically** — the actual rendered output hasn't changed (only whitespace or comments differ in the source template, but Jinja2 produces the same output)
2. **Stale facts** — run with `--flush-cache` to clear Ansible fact cache
3. **Docker compose not recreating** — force recreation:
   ```yaml
   docker_deploy_force_restart: true
   ```

**Verify the config was updated:**
```bash
# On target host:
docker config ls | grep <deploy_name>
docker secret ls | grep <deploy_name>
```

## Permission denied on data directories

**Symptoms:** Container fails to write to mounted volumes.

**Fix:** Set correct ownership in `docker_deploy_folders_additional`:
```yaml
myapp_docker_deploy_folders_additional:
  - dest: /data/myapp/
    dir_owner: 1000      # UID that the container process runs as
    dir_group: 1000
    dir_mode: "0755"
```

**Find the correct UID:** Check the Dockerfile or run:
```bash
docker run --rm <image> id
```

Common UIDs: MySQL=999, PostgreSQL=999, Redis=999, Elasticsearch=1000, MongoDB=999.

## limited_services not filtering correctly

**How it works:** When `limited_services` is set (comma-separated string), only templates/files with a matching `service` attribute are deployed.

**Common issues:**

1. **Missing `service` attribute** — entries without `service` are always deployed regardless of `limited_services`
2. **Wrong service name** — the `service` value must exactly match what you pass in `limited_services`
3. **docker-compose.yml not filtered** — the compose template itself should NOT have a `service` attribute (it's always needed)

**Example:**
```bash
# Deploy only the nginx service and its configs
ansible-playbook deploy.yml -e limited_services=nginx
```

Requires templates to have `service: nginx`:
```yaml
myapp_docker_deploy_templates:
  - src: templates/docker-compose.yml.j2
    dest: "{{ base }}/docker-compose.yml"
    # No service attribute — always deployed
  - src: templates/nginx.conf.j2
    dest: "{{ base }}/nginx.conf"
    service: nginx  # Only deployed when limited_services includes "nginx"
```

## Shell mode vs module mode issues

**Auto-detection logic:**
1. Role checks if `community.docker.docker_compose_v2` Ansible module is available
2. If available and `docker_deploy_shell` is not explicitly `true` → uses module mode
3. If not available → automatically falls back to shell mode

**Force shell mode** (recommended for most deployments):
```yaml
docker_deploy_shell: true
```

**Module mode requires:**
- `community.docker` Ansible collection installed
- Python `docker` module on the target host
- Docker Compose file format compatible with the module

## Container not starting after deploy

**Debugging steps:**
```bash
cd /opt/docker-deploy/<service_name>
make ps          # Check container status
make logs        # View container logs
docker compose config  # Validate compose file syntax
```

**Common causes:**
1. Image not found — check `docker compose pull` output
2. Port conflict — another service using the same port
3. Volume mount path doesn't exist — check `docker_deploy_folders_additional`
4. Environment variable undefined in template — renders as empty string
