---
skill: migrate-to-docker-deploy
description: Convert an existing Docker Compose deployment to use the fccn.ansible_docker_deploy Ansible role
role_source: git+https://github.com/fccn/ansible-docker-deploy.git
role_galaxy: fccn.ansible_docker_deploy
---

# Migrate to ansible-docker-deploy

## When to use this role

- You have a `docker-compose.yml` and want Ansible-managed deployments
- You need multi-environment support (dev/staging/prod) with templated configuration
- You want built-in health checks, secret management, or config versioning
- You want a standardized deployment pattern across multiple services

## Prerequisites

- Ansible 4.0+ on the control machine
- Docker and Docker Compose installed on target hosts
- `community.docker` collection (optional — role auto-falls-back to shell mode)

## Step 1: Install the role

Add to your `requirements.yml`:

```yaml
roles:
  - src: git+https://github.com/fccn/ansible-docker-deploy.git
    name: ansible-docker-deploy
    version: master  # or pin a commit hash for stability
```

Install:
```bash
ansible-galaxy install -r requirements.yml
```

## Step 2: Convert docker-compose.yml to a Jinja2 template

Rename your `docker-compose.yml` to `docker-compose.yml.j2` and templatize variable parts:

**Before:**
```yaml
services:
  app:
    image: myapp:latest
    ports:
      - "8080:8080"
    environment:
      DATABASE_URL: postgres://user:pass@db:5432/mydb
```

**After (docker-compose.yml.j2):**
```yaml
{% import '_docker_deploy_helper.j2' as helper with context %}
services:
  app:
    image: {{ app_docker_image }}
    ports:
      - "{{ app_port }}:8080"
    environment:
      DATABASE_URL: {{ app_database_url }}
{{ helper.service_configs(service='app') }}
{{ helper.service_secrets(service='app') }}

{{ helper.configs() }}
{{ helper.secrets() }}
```

The helper import is optional — only needed if you use Docker configs/secrets.

## Step 3: Create a wrapper role

Create the standard directory structure:

```
roles/myapp_docker_deploy/
├── defaults/main.yml
├── tasks/main.yml
└── templates/
    ├── docker-compose.yml.j2
    └── Makefile
```

**tasks/main.yml:**
```yaml
---
- name: Deploy myapp
  include_role:
    name: ansible-docker-deploy
  vars:
    docker_deploy_base_folder:         "{{ myapp_docker_deploy_base_folder }}"
    docker_deploy_compose_template:    "{{ myapp_docker_deploy_compose_template }}"
    docker_deploy_templates:           "{{ myapp_docker_deploy_templates }}"
    docker_deploy_files:               "{{ myapp_docker_deploy_files | default([]) }}"
    docker_deploy_folders_additional:  "{{ myapp_docker_deploy_folders_additional | default([]) }}"
    docker_deploy_configs:             "{{ myapp_docker_deploy_configs | default([]) }}"
    docker_deploy_secrets:             "{{ myapp_docker_deploy_secrets | default([]) }}"
    docker_deploy_services_additional: "{{ myapp_docker_deploy_services_additional | default([]) }}"
    docker_deploy_shell:               true
    docker_deploy_healthcheck_delay:   "{{ myapp_docker_deploy_healthcheck_delay }}"
    docker_deploy_healthcheck_retries: "{{ myapp_docker_deploy_healthcheck_retries }}"
```

**defaults/main.yml:**
```yaml
---
myapp_docker_deploy_base_folder: /opt/docker-deploy/myapp
myapp_docker_deploy_compose_template: templates/docker-compose.yml.j2

myapp_docker_image: myapp:latest
myapp_port: "8080"

myapp_docker_deploy_healthcheck_delay: 10
myapp_docker_deploy_healthcheck_retries: 20

myapp_docker_deploy_templates:
  - src: templates/docker-compose.yml.j2
    dest: "{{ myapp_docker_deploy_base_folder }}/docker-compose.yml"
  - src: templates/Makefile
    dest: "{{ myapp_docker_deploy_base_folder }}/Makefile"

myapp_docker_deploy_files: []
myapp_docker_deploy_folders_additional: []
```

## Step 4: Map existing files

Convert your existing files to the role's format:

| What you have | Role variable | Entry format |
|---------------|---------------|--------------|
| Static config files | `docker_deploy_files` | `{src: "files/app.conf", dest: "/opt/.../app.conf"}` |
| Templated configs (.j2) | `docker_deploy_templates` | `{src: "templates/app.conf.j2", dest: "/opt/.../app.conf"}` |
| Inline secrets/passwords | `docker_deploy_templates` | `{src_data: "{{ password_var }}", dest: "/opt/.../secret"}` |
| SSL certificates | `docker_deploy_files` | `{src: "files/cert.pem", dest: "/opt/.../cert.pem", secret_name: "cert"}` |
| Data directories | `docker_deploy_folders_additional` | `{dest: "/data/myapp", dir_owner: "1000", dir_mode: "0755"}` |

### Template entry attributes

```yaml
- src: templates/nginx.conf.j2       # Jinja2 template path (relative to role)
  dest: "{{ base_folder }}/nginx.conf" # Destination on target host
  mode: "0644"                         # File permissions (default: 0644)
  owner: root                          # File owner (default: root)
  group: root                          # File group (default: root)
  service: nginx                       # Service name (for filtering and helper macros)
  config_name: nginx_conf              # Makes this a Docker config (with checksum suffix)
  secret_name: nginx_key               # Makes this a Docker secret (with checksum suffix)
  docker_target: /etc/nginx/nginx.conf # Path inside the container
  when: "{{ deploy_nginx }}"           # Conditional deployment
```

## Step 5: Configure health checks

Add `HEALTHCHECK` to your Dockerfile or docker-compose.yml.j2:

```yaml
services:
  app:
    image: {{ app_docker_image }}
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 10s
      timeout: 5s
      retries: 3
```

The role polls `docker ps --filter health=healthy` until all containers pass. Configure timing:

```yaml
myapp_docker_deploy_healthcheck_delay: 10     # seconds between checks
myapp_docker_deploy_healthcheck_retries: 20   # max attempts before failing
```

## Step 6: Add a Makefile template

Create `templates/Makefile` for operational convenience:

```makefile
compose_bin={{ docker_deploy_compose_bin | default('docker compose') }}

deploy: ## Pull images and deploy
	$(compose_bin) pull
	$(compose_bin) up -d

logs: ## View logs
	$(compose_bin) logs -f --tail=100

ps: ## List containers
	$(compose_bin) ps

restart: ## Restart all services
	$(compose_bin) restart

healthcheck: ## Check container health
	$(compose_bin) ps | grep -q "(healthy)"

shell: ## Open shell in app container
	$(compose_bin) exec app /bin/sh

{% for _service in docker_deploy_services %}
restart-{{ _service }}: ## Restart {{ _service }}
	$(compose_bin) restart {{ _service }}
{% endfor %}
```

## Step 7: Test

```bash
# Syntax check
ansible-playbook deploy.yml --syntax-check

# Dry run
ansible-playbook deploy.yml --check --diff -l myapp_servers

# Deploy
ansible-playbook deploy.yml -l myapp_servers -e myapp_deploy=true
```

---

## Common Patterns

### Pattern A: Simple single-service app (like registry_mirror)

Minimal setup for one container with one config file:

```yaml
# defaults/main.yml
myapp_docker_deploy_base_folder: /opt/docker-deploy/myapp
myapp_docker_deploy_compose_template: templates/docker-compose.yml.j2
myapp_docker_deploy_templates:
  - src: templates/docker-compose.yml.j2
    dest: "{{ myapp_docker_deploy_base_folder }}/docker-compose.yml"
  - src: templates/config.yml
    dest: "{{ myapp_docker_deploy_base_folder }}/config.yml"
    config_name: app_config
    service: app
    docker_target: /etc/app/config.yml
```

### Pattern B: Multi-service app (like financial_manager)

App + nginx + worker with resource limits:

```yaml
# defaults/main.yml
myapp_docker_deploy_templates:
  - src: templates/docker-compose.yml.j2
    dest: "{{ myapp_docker_deploy_base_folder }}/docker-compose.yml"
  - src: templates/nginx.conf.j2
    dest: "{{ myapp_docker_deploy_base_folder }}/nginx.conf"
    config_name: nginx_conf
    service: nginx
    docker_target: /etc/nginx/nginx.conf
  - src: templates/app-settings.yml.j2
    dest: "{{ myapp_docker_deploy_base_folder }}/settings.yml"
    config_name: app_settings
    service: app
    docker_target: /app/settings.yml
  - src_data: "{{ myapp_secret_key }}"
    dest: "{{ myapp_docker_deploy_base_folder }}/secret-key"
    secret_name: app_secret_key
    service: app
    docker_target: /run/secrets/secret_key
```

### Pattern C: Database with secrets (like mysql)

Database with persistent volume and password management:

```yaml
# defaults/main.yml
mysql_docker_deploy_base_folder: /opt/docker-deploy/mysql
mysql_docker_deploy_folders_additional:
  - dest: /data/mysql/
    dir_owner: 999
    dir_group: root
    dir_mode: "0755"

mysql_docker_deploy_templates:
  - src: templates/docker-compose.yml.j2
    dest: "{{ mysql_docker_deploy_base_folder }}/docker-compose.yml"
  - src: templates/mysql.cnf.j2
    dest: "{{ mysql_docker_deploy_base_folder }}/mysql.cnf"
    config_name: mysql_cnf
    service: mysql
    docker_target: /etc/mysql/conf.d/custom.cnf
  - src_data: "{{ mysql_root_password }}"
    dest: "{{ mysql_docker_deploy_base_folder }}/root-password"
    secret_name: mysql_root_password
    service: mysql
    docker_target: /run/secrets/mysql_root_password
  - src: templates/Makefile
    dest: "{{ mysql_docker_deploy_base_folder }}/Makefile"
```

---

## What NOT to do

- Don't put secrets in plain docker-compose.yml.j2 — use `src_data` + `secret_name`
- Don't hardcode paths — always use `{{ myapp_docker_deploy_base_folder }}/...`
- Don't skip the `service` attribute on config/secret entries — helper macros need it
- Don't forget `docker_target` on config/secret entries — it maps the file path inside the container
- Don't set `docker_deploy_shell: false` unless you've verified `community.docker.docker_compose_v2` is installed
