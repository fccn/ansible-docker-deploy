---
skill: create-wrapper-role
description: Create a service-specific Ansible role that wraps fccn.ansible_docker_deploy for Docker Compose deployments
role_source: git+https://github.com/fccn/ansible-docker-deploy.git
role_galaxy: fccn.ansible_docker_deploy
---

# Create a Wrapper Role

## Purpose

A wrapper role encapsulates service-specific logic (variable namespacing, config templates, health checks, post-deploy tasks) while delegating container deployment to `ansible-docker-deploy`. This is the standard pattern used in production.

## Directory structure

```
roles/<service>_docker_deploy/
├── defaults/
│   └── main.yml           # All variables with sensible defaults
├── tasks/
│   └── main.yml           # Orchestration: pre-deploy, include_role, post-deploy
├── templates/
│   ├── docker-compose.yml.j2  # Docker Compose template
│   └── Makefile               # Operational commands
└── files/                     # Static files (certificates, scripts, etc.)
```

## defaults/main.yml — Variable Namespacing

All variables are prefixed with `<service>_docker_deploy_*` to avoid collisions when multiple roles coexist:

```yaml
---
# Service configuration
myapp_docker_image: myapp:latest
myapp_port: "8080"
myapp_database_url: "postgres://localhost/myapp"

# Deployment configuration
myapp_docker_deploy_base_folder: /opt/docker-deploy/myapp
myapp_docker_deploy_compose_template: templates/docker-compose.yml.j2

# Health check tuning
myapp_docker_deploy_healthcheck_delay: 10
myapp_docker_deploy_healthcheck_retries: 20

# Templates list — compose file + operational Makefile + any config files
myapp_docker_deploy_templates_default:
  - src: templates/docker-compose.yml.j2
    dest: "{{ myapp_docker_deploy_base_folder }}/docker-compose.yml"
  - src: templates/Makefile
    dest: "{{ myapp_docker_deploy_base_folder }}/Makefile"

# Allow users to add extra templates without overriding defaults
myapp_docker_deploy_templates_extra: []
myapp_docker_deploy_templates: "{{ myapp_docker_deploy_templates_default + myapp_docker_deploy_templates_extra }}"

# Files, folders, services
myapp_docker_deploy_files: []
myapp_docker_deploy_folders_additional: []
myapp_docker_deploy_services_additional: []
```

## tasks/main.yml — Include Role with Variable Mapping

```yaml
---
# Optional: install OS packages needed by the service
- name: Install packages
  package:
    name: "{{ item }}"
    state: present
  loop: "{{ myapp_packages | default([]) }}"

# Core deployment — delegate to ansible-docker-deploy
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

# Optional: post-deployment tasks (replication setup, migrations, etc.)
- name: Run database migrations
  shell: make migrate
  args:
    chdir: "{{ myapp_docker_deploy_base_folder }}"
  when: myapp_run_migrations | default(false) | bool
```

## templates/docker-compose.yml.j2

Import the helper macros at the top for configs/secrets support:

```yaml
{% import '_docker_deploy_helper.j2' as helper with context %}
services:
  app:
    image: {{ myapp_docker_image }}
    ports:
      - "{{ myapp_port }}:8080"
    environment:
      DATABASE_URL: {{ myapp_database_url }}
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 10s
      timeout: 5s
      retries: 3
    deploy:
      resources:
        limits:
          memory: {{ myapp_memory_limit | default('512M') }}
{{ helper.service_configs(service='app') }}
{{ helper.service_secrets(service='app') }}

{{ helper.configs() }}
{{ helper.secrets() }}
```

The helper macros are **only needed if** you use `config_name` or `secret_name` attributes on your templates/files. For simple deployments without Docker configs/secrets, omit the import and macro calls.

## templates/Makefile — Operational Commands

```makefile
compose_bin={{ docker_deploy_compose_bin | default('docker compose') }}

deploy: ## Deploy containers
	$(compose_bin) pull
	$(compose_bin) up -d

logs: ## View container logs
	$(compose_bin) logs -f --tail=100

ps: ## List running containers
	$(compose_bin) ps

restart: ## Restart all services
	$(compose_bin) restart

healthcheck: ## Check container health status
	$(compose_bin) ps | grep -q "(healthy)"

shell: ## Shell into the app container
	$(compose_bin) exec app /bin/sh

{% for _service in docker_deploy_services %}
restart-{{ _service }}: ## Restart {{ _service }}
	$(compose_bin) restart {{ _service }}

logs-{{ _service }}: ## Logs for {{ _service }}
	$(compose_bin) logs -f --tail=100 {{ _service }}
{% endfor %}
```

## Adding configs and secrets to the wrapper

When your service needs Docker configs or secrets, add entries with `config_name`/`secret_name`:

```yaml
# In defaults/main.yml
myapp_docker_deploy_templates_default:
  - src: templates/docker-compose.yml.j2
    dest: "{{ myapp_docker_deploy_base_folder }}/docker-compose.yml"
  - src: templates/Makefile
    dest: "{{ myapp_docker_deploy_base_folder }}/Makefile"
  # Config file — rendered and mounted as Docker config
  - src: templates/app.conf.j2
    dest: "{{ myapp_docker_deploy_base_folder }}/app.conf"
    config_name: app_conf
    service: app
    docker_target: /etc/app/app.conf
  # Inline secret — password stored as Docker secret
  - src_data: "{{ myapp_secret_key }}"
    dest: "{{ myapp_docker_deploy_base_folder }}/secret-key"
    secret_name: app_secret_key
    service: app
    docker_target: /run/secrets/secret_key
```

## Conditional templates

Use the `when` attribute for templates that should only deploy in certain configurations:

```yaml
myapp_docker_deploy_templates_default:
  - src: templates/replication.conf.j2
    dest: "{{ myapp_docker_deploy_base_folder }}/replication.conf"
    config_name: replication_conf
    service: app
    docker_target: /etc/app/replication.conf
    when: "{{ myapp_enable_replication }}"
```

## Data directories with custom ownership

For services that need persistent data with specific UIDs:

```yaml
myapp_docker_deploy_folders_additional:
  - dest: /data/myapp/
    dir_owner: 1000
    dir_group: 1000
    dir_mode: "0755"
```

## Complete example: Redis wrapper role

```yaml
# roles/redis_docker_deploy/defaults/main.yml
---
redis_docker_image: redis:7-alpine
redis_docker_deploy_base_folder: /opt/docker-deploy/redis
redis_docker_deploy_compose_template: templates/docker-compose.yml.j2
redis_docker_deploy_healthcheck_delay: 5
redis_docker_deploy_healthcheck_retries: 12
redis_maxmemory: "256mb"

redis_docker_deploy_templates:
  - src: templates/docker-compose.yml.j2
    dest: "{{ redis_docker_deploy_base_folder }}/docker-compose.yml"
  - src: templates/redis.conf.j2
    dest: "{{ redis_docker_deploy_base_folder }}/redis.conf"
    config_name: redis_conf
    service: redis
    docker_target: /usr/local/etc/redis/redis.conf
  - src: templates/Makefile
    dest: "{{ redis_docker_deploy_base_folder }}/Makefile"

redis_docker_deploy_folders_additional:
  - dest: /data/redis/
    dir_owner: 999
    dir_group: root
    dir_mode: "0755"
```

```yaml
# roles/redis_docker_deploy/templates/docker-compose.yml.j2
{% import '_docker_deploy_helper.j2' as helper with context %}
services:
  redis:
    image: {{ redis_docker_image }}
    command: redis-server /usr/local/etc/redis/redis.conf
    ports:
      - "6379:6379"
    volumes:
      - /data/redis:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 3
{{ helper.service_configs(service='redis') }}

{{ helper.configs() }}
```

## Playbook integration

```yaml
# deploy.yml
- name: Deploy Redis
  hosts: redis_servers
  become: true
  roles:
    - role: redis_docker_deploy
      when: redis_deploy | default(false) | bool
```

```bash
ansible-playbook deploy.yml -l redis_servers -e redis_deploy=true
```
