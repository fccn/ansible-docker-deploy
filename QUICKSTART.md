# Quick Start Guide

## Installation

### From Ansible Galaxy
```bash
ansible-galaxy install fccn.ansible-docker-deploy
```

### From GitHub
```bash
ansible-galaxy install git+https://github.com/fccn/ansible-docker-deploy.git
```

## Minimal Example

```yaml
- hosts: servers
  roles:
    - role: fccn.ansible-docker-deploy
      vars:
        docker_deploy_compose_template: "templates/docker-compose.yml.j2"
        docker_deploy_base_folder: /opt/myapp
        docker_deploy_shell: true
```

## Common Use Cases

### 1. Deploy with Environment File

```yaml
docker_deploy_templates:
  - src: templates/.env.j2
    dest: "{{ docker_deploy_base_folder }}/.env"
```

### 2. Deploy with Secrets

```yaml
docker_deploy_templates:
  - src_data: "{{ database_password }}"
    dest: "{{ docker_deploy_base_folder }}/db-password"
    secret_name: db_password
    service: app
    docker_target: /run/secrets/db-password
```

### 3. Deploy with Git Repository

```yaml
docker_deploy_git_repositories:
  - repo: https://github.com/example/app.git
    dest: "{{ docker_deploy_base_folder }}/app"
    version: v1.0.0
    force: true
```

### 4. Deploy with Custom Folders

```yaml
docker_deploy_folders_additional:
  - dest: /data/app/uploads
    dir_owner: 33  # www-data
    dir_group: 33
    dir_mode: "0755"
```

### 5. Deploy with Health Check

```yaml
docker_deploy_healthcheck_delay: 10
docker_deploy_healthcheck_retries: 30
```

## Testing Your Deployment

```bash
# Quick syntax check
make syntax-check

# Run all tests
make test

# Test with different Ansible versions using Docker
make docker-test-all

# Test in parallel (faster!)
make -j4 docker-test-all-parallel

# Run specific test
make test-compose
```

## Troubleshooting

### Container doesn't start
Check logs: `docker logs <container_name>`

### Permission issues
Verify folder ownership in `docker_deploy_folders_additional`

### Template not rendering
Check that all variables are defined in your playbook

## More Examples

See [README.md](README.md) for comprehensive examples including:
- MySQL deployment with replication
- Elasticsearch cluster setup
- MongoDB with authentication
- Redis with resource limits
- Wrapper role patterns

## Getting Help

- 📖 [Full Documentation](README.md)
- 🐛 [Report Issues](https://github.com/fccn/ansible-docker-deploy/issues)
- 💬 [Discussions](https://github.com/fccn/ansible-docker-deploy/discussions)
