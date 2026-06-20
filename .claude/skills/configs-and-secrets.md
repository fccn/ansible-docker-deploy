---
skill: docker-configs-and-secrets
description: Manage Docker configs and secrets using the immutable checksum pattern in fccn.ansible_docker_deploy
role_source: git+https://github.com/fccn/ansible-docker-deploy.git
role_galaxy: fccn.ansible_docker_deploy
---

# Docker Configs and Secrets

## How the checksum pattern works

Docker configs and secrets are **immutable** — once created, they cannot be updated. The role solves this by appending a content checksum to each name:

1. File/template is written to the target host
2. A SHA256 checksum is computed from the file content
3. A Docker config/secret is created with name: `<deploy_name>_<config_name>_<checksum[:10]>`
4. Ansible facts are set for use in docker-compose.yml.j2:
   - `docker_deploy_configs_checksum[<deploy_name>_<config_name>]` = first 10 chars of checksum
   - `docker_deploy_secrets_checksum[<deploy_name>_<secret_name>]` = first 10 chars of checksum
5. When content changes → new checksum → new name → Docker detects the change and recreates the service

Old configs/secrets are automatically cleaned up by `docker_clean.yml` after each deployment.

## Setting up a config

Add `config_name`, `service`, and `docker_target` to a template or file entry:

```yaml
myapp_docker_deploy_templates:
  - src: templates/nginx.conf.j2
    dest: "{{ myapp_docker_deploy_base_folder }}/nginx.conf"
    config_name: nginx_conf            # Name used in Docker config
    service: nginx                     # Which service uses this config
    docker_target: /etc/nginx/nginx.conf  # Mount path inside container
```

## Setting up a secret

### From a Jinja2 template file

```yaml
myapp_docker_deploy_templates:
  - src: templates/db-credentials.j2
    dest: "{{ myapp_docker_deploy_base_folder }}/db-credentials"
    secret_name: db_credentials
    service: app
    docker_target: /run/secrets/db_credentials
```

### From inline data (src_data)

For simple values like passwords — no template file needed:

```yaml
myapp_docker_deploy_templates:
  - src_data: "{{ myapp_db_password }}"
    dest: "{{ myapp_docker_deploy_base_folder }}/db-password"
    secret_name: db_password
    service: app
    docker_target: /run/secrets/db_password
```

### From static files (certificates, keys)

```yaml
myapp_docker_deploy_files:
  - src: "{{ myapp_ssl_cert_path }}"
    dest: "{{ myapp_docker_deploy_base_folder }}/ssl-cert.pem"
    secret_name: ssl_cert
    service: nginx
    docker_target: /etc/ssl/certs/app.pem
  - src: "{{ myapp_ssl_key_path }}"
    dest: "{{ myapp_docker_deploy_base_folder }}/ssl-key.pem"
    secret_name: ssl_key
    service: nginx
    docker_target: /etc/ssl/private/app.key
```

## Using helper macros in docker-compose.yml.j2

Import the helper at the top of your compose template:

```yaml
{% import '_docker_deploy_helper.j2' as helper with context %}
```

### Service-level declarations

Add configs/secrets to a specific service:

```yaml
services:
  app:
    image: {{ myapp_docker_image }}
{{ helper.service_configs(service='app') }}
{{ helper.service_secrets(service='app') }}

  nginx:
    image: nginx:alpine
{{ helper.service_configs(service='nginx') }}
{{ helper.service_secrets(service='nginx') }}
```

This renders (example output):
```yaml
services:
  app:
    image: myapp:latest
    configs:
      - source: app_settings_ab8c30826d
        target: /etc/app/settings.yml
    secrets:
      - source: db_password_7c3ff94989
        target: /run/secrets/db_password

  nginx:
    image: nginx:alpine
    configs:
      - source: nginx_conf_f4e82a1b3c
        target: /etc/nginx/nginx.conf
    secrets:
      - source: ssl_cert_2d9e4f7a1b
        target: /etc/ssl/certs/app.pem
```

### Top-level declarations

Define all configs and secrets at the compose root:

```yaml
{{ helper.configs() }}
{{ helper.secrets() }}
```

This renders:
```yaml
configs:
  nginx_conf_f4e82a1b3c:
    file: /opt/docker-deploy/myapp/nginx.conf
  app_settings_ab8c30826d:
    file: /opt/docker-deploy/myapp/settings.yml
secrets:
  db_password_7c3ff94989:
    file: /opt/docker-deploy/myapp/db-password
  ssl_cert_2d9e4f7a1b:
    file: /opt/docker-deploy/myapp/ssl-cert.pem
```

### Controlling the header

The macros accept `header=true|false` to control whether the `configs:`/`secrets:` keyword is printed:

```yaml
{{ helper.service_configs(header=true, service='app') }}   # Prints "    configs:" + entries
{{ helper.service_configs(header=false, service='app') }}  # Prints only entries (no header)
```

## The `service` attribute

The `service` attribute on templates/files serves two purposes:

1. **Helper macro filtering** — `helper.service_configs(service='app')` only renders entries with `service: app`
2. **`limited_services` filtering** — when `limited_services` is set, only entries matching are deployed

If you omit `service`, the entry:
- Still works as a config/secret
- Renders in `helper.service_configs()` calls without a service filter
- Is NOT filtered by `limited_services`

## Conditional configs

Use `when` for configs that should only exist in certain conditions:

```yaml
myapp_docker_deploy_templates:
  - src: templates/cluster-config.yml.j2
    dest: "{{ myapp_docker_deploy_base_folder }}/cluster.yml"
    config_name: cluster_config
    service: app
    docker_target: /etc/app/cluster.yml
    when: "{{ myapp_cluster_enabled }}"
```

The helper macros respect `when` — they skip entries where `when` evaluates to false.

## Complete example: MySQL with config + secret

```yaml
# defaults/main.yml
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

```yaml
# templates/docker-compose.yml.j2
{% import '_docker_deploy_helper.j2' as helper with context %}
services:
  mysql:
    image: {{ mysql_docker_image }}
    environment:
      MYSQL_ROOT_PASSWORD_FILE: /run/secrets/mysql_root_password
    volumes:
      - /data/mysql:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 3
{{ helper.service_configs(service='mysql') }}
{{ helper.service_secrets(service='mysql') }}

{{ helper.configs() }}
{{ helper.secrets() }}
```

## Gotchas

- The checksum is truncated to **10 characters** (first 10 of SHA256)
- Old configs/secrets are cleaned up automatically after each deploy (docker_clean.yml filters by `_docker_deploy_name` prefix)
- The Ansible fact naming convention: `docker_deploy_configs_checksum['<deploy_name>_<config_name>']`
- `docker_target` is **required** for helper macros to work — it becomes the `target:` in compose
- If you add a `config_name`/`secret_name` but forget the helper macro calls in docker-compose.yml.j2, the config/secret is created but never mounted
- Entries using `src_data` don't need a template file — the content is written inline
