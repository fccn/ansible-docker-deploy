# ansible-docker-deploy

Ansible utility role for deploying Docker Compose applications. Handles file/template management, git repo cloning, S3 downloads, Docker configs/secrets with immutable checksums, and container health monitoring. Designed to be wrapped by service-specific roles via `include_role`.

## Task Execution Flow (tasks/main.yml)

1. Verify required variables (`docker_deploy_compose_template` or `docker_deploy_shell_start`)
2. Set `_docker_deploy_name` from `docker_deploy_base_folder` basename
3. Create root directory
4. Stop/remove old containers (`docker_deploy_containers_to_remove`, `docker_deploy_services_to_remove`)
5. Clone/update git repositories
6. Create parent directories for files, templates, git repos
7. Create additional folders (`docker_deploy_folders_additional`)
8. Copy files (`docker_deploy_files`)
9. Download S3 files (`docker_deploy_s3_files`)
10. Render templates with `src` attribute
11. Render templates with `src_data` attribute (inline data)
12. Create Docker configs (checksum-suffixed names)
13. Create Docker secrets (checksum-suffixed names)
14. Auto-detect deployment mode (module vs shell)
15. Deploy via shell OR docker_compose_v2 module
16. Health check (poll container health status)
17. Cleanup old configs/secrets

## Key Variables

### Required (at least one)
- `docker_deploy_compose_template` — path to docker-compose.yml.j2 template
- `docker_deploy_shell_start` — custom shell command to start containers

### Core
- `docker_deploy_base_folder` (default: `/opt/docker-deploy`) — deployment destination
- `docker_deploy_shell` (default: auto) — force shell mode if set to `true`
- `docker_deploy_compose_bin` (default: `auto`) — auto-detects `docker compose` v2 or `docker-compose` v1

### Assets
- `docker_deploy_files: []` — files to copy (each: src, dest, mode, owner, group, when, service, config_name, secret_name, docker_target)
- `docker_deploy_templates: []` — Jinja2 templates to render (same attributes + src_data for inline)
- `docker_deploy_git_repositories: []` — git repos to clone (repo, dest, version, ssh_key, owner, group)
- `docker_deploy_s3_files: []` — S3 file downloads
- `docker_deploy_folders_additional: []` — extra directories (dest, dir_owner, dir_group, dir_mode)

### Docker Configs/Secrets
- Files/templates with `config_name` attribute become Docker configs
- Files/templates with `secret_name` attribute become Docker secrets
- Checksum suffix enables immutable update detection
- Facts set: `docker_deploy_configs_checksum[<deploy_name>_<config_name>]`

### Health Check
- `docker_deploy_healthcheck` (default: `true`)
- `docker_deploy_healthcheck_delay` — seconds between retries
- `docker_deploy_healthcheck_retries` (default: `20`)

### Service Filtering
- `docker_deploy_services` — auto-computed from `service` attributes on templates/files
- `limited_services` — deploy only specific services (comma-separated)

## Conventions

- All role variables prefixed with `docker_deploy_`
- Internal fact: `_docker_deploy_name` = basename of `docker_deploy_base_folder`
- Wrapper roles namespace: `<service>_docker_deploy_*` mapped to `docker_deploy_*` via include_role vars
- Helper macros in `templates/_docker_deploy_helper.j2` (import as: `{% import '_docker_deploy_helper.j2' as helper with context %}`)

## Testing

```bash
make test              # All tests
make lint              # yamllint + ansible-lint
make test-compose      # Shell mode deployment test
make test-compose-v2   # Module mode deployment test
make test-files        # Files/templates test
make test-secrets      # Configs/secrets test
make docker-test-all   # Multi-version Ansible tests in Docker
make molecule          # Molecule test suite
```

## Anti-patterns

- Never hardcode `docker compose` or `docker-compose` — use `docker_deploy_compose_bin: auto`
- Never skip the `service` attribute on templates/files that need config/secret scoping
- Never put sensitive data directly in docker-compose.yml.j2 — use `src_data` + `secret_name`
- Never create configs/secrets without `docker_target` — the helper macros require it
- Never use `docker_deploy_shell: true` without also defining the compose template (auto-detect handles this)

## Skills for Other Projects

See `.claude/skills/` for portable documentation that helps other projects adopt this role. Copy relevant skill files to your project's `.claude/skills/` directory.
