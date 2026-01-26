# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive test suite with multiple test scenarios
- GitHub Actions CI/CD pipeline
- Molecule testing framework support
- Test runner script (`tests/run-tests.sh`)
- Linting configuration (yamllint, ansible-lint)
- CONTRIBUTING.md guide for contributors
- requirements.txt and requirements-dev.txt for development dependencies

### Changed
- Improved README with real-world examples from NAU project
- Enhanced documentation with better structure and formatting

### Removed
- Docker Swarm/Stack support (compose-only role now)
- Removed `docker_deploy_stack_template` variable
- Removed `docker_deploy_stack_name` variable
- Removed `docker_deploy_stack_pip_requirements` variable
- Removed `tasks/docker_deploy_stack.yml` task file

## [1.0.0] - Previous Release

### Added
- Initial support for Docker Compose deployments
- Docker Swarm/Stack deployment support
- File and template management
- Git repository cloning
- Docker configs and secrets support
- Health check functionality
- Custom deployment modes (shell vs Ansible module)

[Unreleased]: https://github.com/fccn/ansible-docker-deploy/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/fccn/ansible-docker-deploy/releases/tag/v1.0.0
