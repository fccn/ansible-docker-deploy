# Claude Code Skills for ansible-docker-deploy

These skills are designed to be **copied into OTHER projects** that want to adopt the `fccn.ansible_docker_deploy` role for their Docker Compose deployments.

## How to use in your project

1. Copy the relevant skill file(s) to your project's `.claude/skills/` directory
2. Claude Code agents will reference these skills when working on deployment tasks
3. Skills are self-contained — they carry all context needed without reading this repository

## Available skills

| Skill | Description |
|-------|-------------|
| [migrate-to-docker-deploy.md](migrate-to-docker-deploy.md) | Convert an existing deployment to use this role |
| [create-wrapper-role.md](create-wrapper-role.md) | Create a service-specific Ansible wrapper role |
| [configs-and-secrets.md](configs-and-secrets.md) | Docker configs and secrets with immutable checksums |
| [troubleshooting.md](troubleshooting.md) | Debug common deployment issues |

## Role installation

```yaml
# requirements.yml
roles:
  - src: git+https://github.com/fccn/ansible-docker-deploy.git
    name: ansible-docker-deploy
    version: master  # or pin to a specific commit hash
```

```bash
ansible-galaxy install -r requirements.yml
```

## Galaxy name

`fccn.ansible_docker_deploy`
