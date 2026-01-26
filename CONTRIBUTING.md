# Contributing to ansible-docker-deploy

Thank you for your interest in contributing to ansible-docker-deploy!

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR-USERNAME/ansible-docker-deploy.git
   cd ansible-docker-deploy
   ```

3. Create a new branch for your feature or bugfix:
   ```bash
   git checkout -b feature/my-new-feature
   ```

## Development Setup

### Install Dependencies

```bash
# Create a virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install development dependencies
pip install -r requirements-dev.txt

# Install Ansible collections
ansible-galaxy collection install -r requirements.yml
```

### Install Docker (if not already installed)

- **Ubuntu/Debian:**
  ```bash
  sudo apt-get update
  sudo apt-get install docker.io docker-compose
  sudo systemctl start docker
  sudo usermod -aG docker $USER
  ```

- **macOS:** Install Docker Desktop from https://www.docker.com/products/docker-desktop

- **Windows:** Install Docker Desktop from https://www.docker.com/products/docker-desktop

## Testing

### Run All Tests

```bash
# From the project root
cd tests
./run-tests.sh
```

### Run Specific Tests

```bash
# Syntax check
ansible-playbook tests/test.yml -i tests/inventory --syntax-check

# Compose test
ansible-playbook tests/test-compose.yml -i tests/inventory -vv

# Files and templates test
ansible-playbook tests/test-files-templates.yml -i tests/inventory -vv

# Secrets and configs test
ansible-playbook tests/test-secrets-configs.yml -i tests/inventory -vv
```

### Run Linting

```bash
# YAML linting
yamllint .

# Ansible linting
ansible-lint

# Both together
yamllint . && ansible-lint
```

### Run Molecule Tests

```bash
# Full test suite
molecule test

# Step by step
molecule create    # Create test instance
molecule converge  # Run the role
molecule verify    # Run verification tests
molecule destroy   # Clean up
```

## Code Style Guidelines

### YAML Files

- Use 2 spaces for indentation
- Maximum line length: 160 characters
- Always use `---` at the beginning of YAML files
- Use `true`/`false` for booleans (not `yes`/`no` unless in legacy code)

### Ansible Tasks

- Always include a descriptive `name` for tasks
- Use tags appropriately (`docker_deploy`, `healthcheck`, etc.)
- Add comments for complex logic
- Use `when` conditions to make tasks conditional
- Use `changed_when: false` for read-only tasks

### Variables

- Prefix role variables with `docker_deploy_`
- Use descriptive variable names
- Document all variables in `defaults/main.yml`
- Use sensible defaults

## Pull Request Process

1. **Update documentation** if you're adding new features or changing behavior
2. **Add tests** for new features
3. **Run the test suite** and ensure all tests pass:
   ```bash
   ./tests/run-tests.sh
   yamllint .
   ansible-lint
   ```
4. **Update CHANGELOG.md** with your changes
5. **Commit your changes** with clear, descriptive commit messages:
   ```bash
   git add .
   git commit -m "Add feature: description of feature"
   ```
6. **Push to your fork**:
   ```bash
   git push origin feature/my-new-feature
   ```
7. **Create a Pull Request** on GitHub with:
   - Clear title and description
   - Reference to any related issues
   - Screenshots if applicable
   - Test results

## Commit Message Guidelines

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters
- Reference issues and pull requests after the first line

Examples:
```
Add support for custom healthcheck commands

- Implement docker_deploy_healthcheck_command variable
- Update documentation with examples
- Add tests for custom healthcheck functionality

Fixes #123
```

## Issue Reporting

When reporting issues, please include:

- Your Ansible version (`ansible --version`)
- Your OS and version
- Docker version (`docker --version`)
- Complete error messages and stack traces
- Steps to reproduce the issue
- Expected vs actual behavior

## Feature Requests

Feature requests are welcome! Please:

- Check if the feature has already been requested
- Clearly describe the feature and its use case
- Provide examples of how it would be used
- Consider contributing the feature yourself

## Questions?

- Open an issue for bugs or feature requests
- Check existing issues for similar questions
- Review the documentation in README.md

## Code of Conduct

- Be respectful and inclusive
- Welcome newcomers and help them get started
- Focus on what is best for the community
- Show empathy towards other community members

## License

By contributing, you agree that your contributions will be licensed under the GPL-3.0-only License.
