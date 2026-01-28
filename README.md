# Ansible Docker Deploy

[![CI](https://github.com/fccn/ansible-docker-deploy/workflows/CI/badge.svg)](https://github.com/fccn/ansible-docker-deploy/actions)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Ansible Role](https://img.shields.io/ansible/role/XXXXX)](https://galaxy.ansible.com/fccn/ansible-docker-deploy)

Ansible utility role to easily deploy Docker Compose applications. It handles copying files, rendering templates, cloning git repositories, and deploying containers using docker-compose. The role also includes health check monitoring to ensure containers start successfully.

**Note:** This role does not install Docker or Docker Compose. It focuses solely on deploying and managing containerized applications.

## Features

- 🐳 **Docker Compose Deployment** - Deploy applications using docker-compose
- 📦 **Asset Management** - Copy files, render templates, and clone git repositories
- 🔐 **Secrets & Configs** - Manage Docker secrets and configs with automatic checksums
- ✅ **Health Checks** - Built-in container health monitoring
- 🎯 **Flexible Modes** - Use Ansible modules or direct shell commands
- 🔧 **Wrapper-Friendly** - Easy to wrap for service-specific roles

## Requirements

- Ansible 2.7 or higher
- Docker and Docker Compose installed on target hosts
- `community.docker` Ansible collection (for docker_compose_v2 module)
  ```bash
  ansible-galaxy collection install community.docker
  ```
- Python `docker` module (for non-shell mode)
  ```bash
  pip install docker
  ```

**Note:** If `community.docker` collection is not available, the role will automatically fall back to shell-based deployment mode.

## Role Variables

### Required Variables

At minimum, you must define one of the following:
- **`docker_deploy_compose_template`** - Path to your docker-compose.yml template file
- **`docker_deploy_shell_start`** - Custom shell command to start containers

### Core Variables

- **`docker_deploy_base_folder`** (default: `/opt/docker-deploy`) - Destination directory on the target machine where the docker-compose.yml and all related files will be deployed

### Asset Management

The role provides flexible ways to manage your deployment assets:

- **`docker_deploy_files`** (default: `[]`) - List of files to copy to the target host
- **`docker_deploy_templates`** (default: `[]`) - List of Jinja2 templates to render on the target host
- **`docker_deploy_git_repositories`** (default: `[]`) - List of git repositories to clone

#### Git Repository Options

Each repository in `docker_deploy_git_repositories` can have:
- `repo` - Repository URL (required)
- `dest` - Destination path (required)
- `version` - Branch, tag, or commit (default: `master`)
- `force` - Force clone/update (default: `false`)
- `ssh_key` - SSH private key content for authentication
- `fact` - Define an Ansible fact with the checked out git version

### Deployment Mode

The role supports two deployment modes:

#### 1. Ansible Docker Compose Module Mode (default)

By default, the role uses Ansible's `docker_compose` module.

#### 2. Shell Command Mode

For Docker Compose file format version 3.x or higher, set `docker_deploy_shell: true` to use direct shell commands.

**Shell Mode Variables:**

- **`docker_deploy_shell`** (default: `false`) - Enable shell command mode
- **`docker_deploy_shell_start_default`** (default: `docker-compose pull && docker-compose build && docker-compose up -d`) - Default startup command
- **`docker_deploy_shell_start_default_additional_parameters`** - Additional parameters always added to docker-compose commands
- **`docker_deploy_shell_start_default_additional_parameters_if_changed`** - Parameters added only when files change (e.g., `--force-recreate`)
- **`docker_deploy_force_restart`** - Force container recreation/restart

## Advanced parameters

### Docker Configs and Secrets

Each item in `docker_deploy_templates` or `docker_deploy_files` can include a `config_name` and/or `secret_name` attribute to create Docker configs or secrets.

Docker configs and secrets are immutable - once created, they cannot be updated. The standard workaround is to suffix each config/secret name with a checksum. This role automates this pattern by generating Ansible facts for each config/secret with their checksums:

- `docker_deploy_config_<deployment_name>_<config_name>`
- `docker_deploy_secret_<deployment_name>_<secret_name>`

**Example Configuration:**

```yml
docker_deploy_templates:
  - src: files/nginx.conf.j2
    dest: /opt/nginx.conf
    config_name: nginx_conf
    docker_target: /etc/mysql/conf.d/mysql.cnf
```

**Example Usage in docker-compose.yml template:**

```yml
services:
  app:
    configs:
      - source: nginx_conf_{{ hostvars[inventory_hostname]['docker_deploy_config_' + _docker_deploy_name + '_nginx_conf'][:10] }}
        target: /etc/mysql/conf.d/mysql.cnf

configs:
{% for template in ( docker_deploy_templates | selectattr('config_name', 'defined') | list ) %}
  {{ template.config_name }}_{{ hostvars[inventory_hostname]['docker_deploy_config_' + _docker_deploy_name + '_' + template.config_name][:10] }}:
    file: {{ template.dest }}
{% endfor %}
```

**Note:** You can also use the helper macros in `templates/_docker_deploy_helper.j2` to simplify config and secret generation.

## Dependencies

None. Only Ansible is required.

## Example Playbook

### Example 1: Basic Deployment

Simple deployment with just a compose template:

```yml
- hosts: servers
  roles:
    - role: ansible-docker-deploy
      vars:
        docker_deploy_compose_template: "path_to/docker-compose.yml"
```

### Example 2: Deployment with Files and Templates

Deploy with additional configuration files:

```yml
- hosts: servers
  roles:
    - role: ansible-docker-deploy
      vars:
        docker_deploy_compose_template: "path_to/docker-compose.yml"
        docker_deploy_files:
          - src: "local_path/cert.key.pem"
            dest: "{{ docker_deploy_base_folder }}/cert.key.pem"
        docker_deploy_templates:
          - src: "local_path/nginx.conf"
            dest: "{{ docker_deploy_base_folder }}/nginx.conf"
          - src: "local_path/Makefile"
            dest: "{{ docker_deploy_base_folder }}/Makefile"
```

### Example 3: Deployment with Git Repository

**Group vars:**
```yml
docker_deploy_compose_template: "path_to/docker-compose.yml"
docker_deploy_git_repositories:
  - repo: https://github.com/fccn/wp-nau-theme.git
    dest: "{{ wordpress_nau_theme_dest }}"
    version: "{{ wordpress_nau_theme_version | default('master') }}"
    force: true
    owner: www-data
    group: www-data
    mode: u=rwX,g=rX,o=rX
    fact: wordpress_nau_theme_git_version
    # ssh_key: "{{ SSH_KEY_CONTENT }}"
```

**Playbook:**
```yml
- hosts: servers
  roles:
    - ansible-docker-deploy
```

### Example 4: MySQL Deployment with Secrets

Real-world example deploying MySQL with Docker secrets and configs:

```yml
- hosts: mysql_servers
  roles:
    - role: ansible-docker-deploy
      vars:
        docker_deploy_base_folder: /nau/ops/mysql
        docker_deploy_compose_template: templates/docker-compose.yml.j2
        docker_deploy_shell: true
        docker_deploy_templates:
          - src_data: "{{ mysql_root_password }}"
            dest: "{{ docker_deploy_base_folder }}/mysql-root-password"
            secret_name: mysql_root_password
            service: mysql
            docker_target: /run/secrets/mysql-root-password
          - src: templates/mysql.cnf.j2
            dest: "{{ docker_deploy_base_folder }}/mysql.cfg"
            config_name: mysql_cfg
            service: mysql
            docker_target: /etc/mysql/conf.d/mysql.cnf
          - src: templates/Makefile
            dest: "{{ docker_deploy_base_folder }}/Makefile"
        docker_deploy_folders_additional:
          - dest: /data/mysql/
            dir_owner: 999
            dir_group: root
            dir_mode: "0755"
```

### Example 5: Elasticsearch Cluster Deployment

Deploy Elasticsearch with custom network configuration and health checks:

```yml
- hosts: elasticsearch_servers
  roles:
    - role: ansible-docker-deploy
      vars:
        docker_deploy_base_folder: /nau/ops/elasticsearch
        docker_deploy_compose_template: templates/docker-compose.yml.j2
        docker_deploy_shell: true
        docker_deploy_healthcheck_delay: 5
        docker_deploy_healthcheck_retries: 50
        docker_deploy_templates:
          - src: templates/Makefile
            dest: "{{ docker_deploy_base_folder }}/Makefile"
        docker_deploy_folders_additional:
          - dest: /data/elasticsearch/
            dir_owner: 1000
            dir_group: 1000
            dir_mode: "0755"
```

### Example 6: MongoDB with Replication

Deploy MongoDB with authentication secrets and replication key:

```yml
- hosts: mongo_servers
  roles:
    - role: ansible-docker-deploy
      vars:
        docker_deploy_base_folder: /nau/ops/mongo
        docker_deploy_compose_template: templates/docker-compose.yml.j2
        docker_deploy_shell: true
        docker_deploy_templates:
          - src_data: "{{ mongo_root_username }}"
            dest: "{{ docker_deploy_base_folder }}/mongo/mongo-root-username"
            secret_name: mongo_root_username
            service: mongo
            docker_target: /run/secrets/mongo-root-username
            when: "{{ mongo_root_username | length > 0 }}"
          - src_data: "{{ mongo_root_password }}"
            dest: "{{ docker_deploy_base_folder }}/mongo/mongo-root-password"
            secret_name: mongo_root_password
            service: mongo
            docker_target: /run/secrets/mongo-root-password
            when: "{{ mongo_root_password | length > 0 }}"
          - src_data: "{{ mongo_keyfile_value }}"
            dest: "{{ docker_deploy_base_folder }}/mongo/mongodb_key"
            mode: "0600"
            owner: 999
            secret_name: mongo_key
            service: mongo
            docker_target: /run/secrets/mongodb_key
            when: "{{ mongo_keyfile_value | length > 0 }}"
```

### Example 7: Redis with Resource Limits

Deploy Redis with custom ulimits:

```yml
- hosts: redis_servers
  roles:
    - role: ansible-docker-deploy
      vars:
        docker_deploy_base_folder: /nau/ops/redis
        docker_deploy_compose_template: templates/docker-compose.yml.j2
        docker_deploy_shell: true
        docker_deploy_healthcheck_delay: 10
        docker_deploy_healthcheck_retries: 360
        docker_deploy_templates:
          - src: templates/Makefile
            dest: "{{ docker_deploy_base_folder }}/Makefile"
        docker_deploy_folders_additional:
          - dest: /data/redis/
            dir_owner: 1001
            dir_group: 1001
            dir_mode: "0755"
```

### Example 8: Wrapper Role Pattern

Create a wrapper role that uses ansible-docker-deploy:

**roles/mysql_docker_deploy/tasks/main.yml:**
```yml
---
- name: Install required packages
  package:
    name: "{{ item }}"
    state: present
  loop:
    - make
    - python3-pip
    - mysql-client

- name: Deploy MySQL using ansible-docker-deploy
  include_role:
    name: ansible-docker-deploy
  vars:
    docker_deploy_base_folder: "{{ mysql_docker_deploy_base_folder }}"
    docker_deploy_compose_template: "{{ mysql_docker_deploy_compose_template }}"
    docker_deploy_templates: "{{ mysql_docker_deploy_templates | default([]) }}"
    docker_deploy_files: "{{ mysql_docker_deploy_files | default([]) }}"
    docker_deploy_folders_additional: "{{ mysql_docker_deploy_folders_additional | default([]) }}"
    docker_deploy_shell: true
    docker_deploy_healthcheck_delay: "{{ mysql_docker_deploy_healthcheck_delay }}"
    docker_deploy_healthcheck_retries: "{{ mysql_docker_deploy_healthcheck_retries }}"

- name: Run custom healthcheck
  shell: make healthcheck
  args:
    chdir: "{{ mysql_docker_deploy_base_folder }}"
  delay: "{{ mysql_docker_deploy_healthcheck_delay }}"
  register: result
  until: result.rc == 0
  retries: "{{ mysql_docker_deploy_healthcheck_retries }}"
  changed_when: false
  when: not ansible_check_mode
```

## Testing

### Quick Syntax Check

To quickly test the role syntax:

```bash
virtualenv venv
source venv/bin/activate
pip install ansible
printf '[defaults]\nroles_path=../' > ansible.cfg
ansible-playbook tests/test.yml -i tests/inventory --syntax-check
```

### Comprehensive Test Suite

The role includes a comprehensive test suite with multiple test scenarios:

**Shell Mode Tests:**
1. **test-compose.yml** - Tests basic Docker Compose deployment (shell mode)
2. **test-files-templates.yml** - Tests file copying and template rendering (shell mode)
3. **test-secrets-configs.yml** - Tests Docker secrets and configs functionality (shell mode)

**docker_compose_v2 Module Tests:**
4. **test-compose-v2.yml** - Tests basic Docker Compose deployment (docker_compose_v2 mode)
5. **test-files-templates-v2.yml** - Tests file copying and template rendering (docker_compose_v2 mode)
6. **test-secrets-configs-v2.yml** - Tests Docker secrets and configs functionality (docker_compose_v2 mode)

#### Quick Start - Using Makefile

```bash
# Run all tests (both shell and docker_compose_v2 modes)
make test

# Run specific shell mode tests
make syntax-check
make lint
make test-compose
make test-files
make test-secrets

# Run specific docker_compose_v2 mode tests
make test-compose-v2
make test-files-v2
make test-secrets-v2
```

#### Testing with Multiple Ansible Versions

**Option 1: Docker-based testing (Recommended)**

No need to install different Ansible versions - everything runs in Docker:

```bash
# Test all Ansible versions (4, 5, 6, 7, 8, 9, latest)
make docker-test-all

# Test all versions in parallel (faster!)
make -j4 docker-test-all-parallel

# Test specific version
make docker-test VERSION=9
make docker-test VERSION=6

# Clean up Docker images
make docker-clean
```

**Option 2: Virtual environment testing**

Tests only versions compatible with your current Python:
- **Python 3.12**: Ansible 7, 8, 9
- **Python 3.11**: Ansible 7, 8, 9
- **Python 3.10 or older**: Ansible 5, 6, 7, 8, 9

```bash
# Test all compatible versions sequentially
make test-all-versions

# Test compatible versions in parallel
make -j3 test-all-versions-parallel

# Test specific version (if compatible)
make test-ansible-version VERSION=9

# Clean up virtual environments
make clean-venvs
```

**Python/Ansible Compatibility:**
- Ansible 5-6: Python 3.8 - 3.10
- Ansible 7-8: Python 3.9 - 3.11
- Ansible 9+: Python 3.10 - 3.12

**Note:** Virtual env tests automatically skip incompatible versions. For full version coverage, use Docker-based testing.

#### Running All Tests

```bash
cd tests
./run-tests.sh
```

#### Running Individual Tests

```bash
# Shell mode tests
ansible-playbook tests/test-compose.yml -i tests/inventory -vv
ansible-playbook tests/test-files-templates.yml -i tests/inventory -vv
ansible-playbook tests/test-secrets-configs.yml -i tests/inventory -vv

# docker_compose_v2 mode tests
ansible-playbook tests/test-compose-v2.yml -i tests/inventory -vv
ansible-playbook tests/test-files-templates-v2.yml -i tests/inventory -vv
ansible-playbook tests/test-secrets-configs-v2.yml -i tests/inventory -vv
```

### Molecule Testing

For more advanced testing with Molecule:

```bash
# Install molecule
pip install molecule molecule-plugins[docker] docker

# Run all molecule tests
molecule test

# Run specific steps
molecule create
molecule converge
molecule verify
molecule destroy
```

### GitHub Actions CI/CD

This role includes a comprehensive GitHub Actions workflow that automatically:

- Runs linting (yamllint, ansible-lint)
- Tests syntax across multiple Ansible versions (4 - 9)
- Executes integration tests
- Runs Molecule tests
- Notifies Ansible Galaxy on successful master branch builds

The CI pipeline is triggered on:
- Push to main/master/develop branches
- Pull requests to main/master/develop branches
- Manual workflow dispatch

View the workflow in [.github/workflows/ci.yml](.github/workflows/ci.yml)

### Test Requirements

- Docker and Docker Compose installed
- Python 3.8+
- Ansible 5.0+
- ansible-lint and yamllint (for linting)
- molecule and molecule-docker (for Molecule tests)

## License

GPL-3.0-only

## Author Information

**Ivo Branco** - ivo.branco@fccn.pt

### Organizations
- [FCT|FCCN](https://www.fccn.pt)
- [Arquivo.pt](https://arquivo.pt)
- [NAU](https://www.nau.edu.pt)
- [Educast](https://educast.fccn.pt)