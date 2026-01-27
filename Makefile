# Makefile for ansible-docker-deploy role
#
# This Makefile provides convenient targets for testing, linting, and managing
# the ansible-docker-deploy Ansible role. It supports:
# - Local testing with syntax checks, linting, and integration tests
# - Multi-version testing with virtual environments or Docker
# - Parallel test execution for faster CI/CD pipelines
# - Docker-based testing for complete Ansible version coverage
#
# Common targets:
#   make test                    - Run all tests (syntax, lint, integration)
#   make test-all                - Run integration tests only
#   make docker-test-all         - Test all Ansible versions with Docker
#   make -j4 docker-test-all-parallel - Parallel Docker testing (recommended)
#   make help                    - Show all available targets

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
.PHONY: help

install: ## Install development dependencies
	pip install -r requirements-dev.txt
.PHONY: install

test: syntax-check lint test-all ## Run all tests
.PHONY: test

lint: ## Run linting (yamllint and ansible-lint)
	@echo "Running yamllint..."
	yamllint .
	@echo "Running ansible-lint..."
	ansible-lint
.PHONY: lint

syntax-check: ## Run Ansible syntax check
	@echo "Running syntax check..."
	printf '[defaults]\nroles_path=../' > ansible.cfg
	ansible-playbook tests/test.yml -i tests/inventory --syntax-check
.PHONY: syntax-check

test-all: test-compose test-files test-secrets ## Run all integration tests
	@echo "All integration tests completed!"
.PHONY: test-all

test-compose: ## Run compose deployment test
	@echo "Running compose deployment test..."
	ansible-playbook tests/test-compose.yml -i tests/inventory -vv
.PHONY: test-compose

test-files: ## Run files and templates test
	@echo "Running files and templates test..."
	ansible-playbook tests/test-files-templates.yml -i tests/inventory -vv
.PHONY: test-files

test-secrets: ## Run secrets and configs test
	@echo "Running secrets and configs test..."
	ansible-playbook tests/test-secrets-configs.yml -i tests/inventory -vv
.PHONY: test-secrets

molecule: ## Run molecule tests
	@echo "Running molecule tests..."
	molecule test
.PHONY: molecule

molecule-converge: ## Run molecule converge
	molecule converge
.PHONY: molecule-converge

molecule-verify: ## Run molecule verify
	molecule verify
.PHONY: molecule-verify

molecule-destroy: ## Destroy molecule instances
	molecule destroy
.PHONY: molecule-destroy

clean: ## Clean up test artifacts and Docker resources
	@echo "Cleaning up..."
	rm -rf ansible.cfg
	docker stop $$(docker ps -aq) 2>/dev/null || true
	docker rm $$(docker ps -aq) 2>/dev/null || true
	docker swarm leave --force 2>/dev/null || true
	rm -rf /tmp/ansible-docker-deploy-test*
.PHONY: clean

setup: ## Setup development environment
	python3 -m venv venv
	./venv/bin/pip install -r requirements-dev.txt
	ansible-galaxy collection install -r requirements.yml
	@echo "Development environment ready!"
	@echo "Activate it with: source venv/bin/activate"
.PHONY: setup

test-ansible-version: ## Test with specific Ansible version (usage: make test-ansible-version VERSION=9)
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION not specified. Usage: make test-ansible-version VERSION=9"; \
		exit 1; \
	fi
	@echo "Testing with Ansible $(VERSION)..."
	@python_version=$$(python3 --version | awk '{print $$2}' | cut -d. -f1,2); \
	if [ "$(VERSION)" = "4" ] || [ "$(VERSION)" = "5" ] || [ "$(VERSION)" = "6" ]; then \
		if [ "$$(echo "$$python_version >= 3.11" | bc)" -eq 1 ]; then \
			echo "WARNING: Ansible $(VERSION) is not compatible with Python $$python_version"; \
			echo "Ansible 4-6 require Python <= 3.10. Skipping test."; \
			exit 0; \
		fi; \
	fi
	python3 -m venv venv-ansible-$(VERSION)
	./venv-ansible-$(VERSION)/bin/pip install --upgrade pip
	./venv-ansible-$(VERSION)/bin/pip install "ansible~=$(VERSION).0"
	./venv-ansible-$(VERSION)/bin/ansible --version
	./venv-ansible-$(VERSION)/bin/ansible-galaxy collection install -r requirements.yml
	printf '[defaults]\nroles_path=../' > ansible.cfg
	./venv-ansible-$(VERSION)/bin/ansible-playbook tests/test.yml -i tests/inventory --syntax-check
	@echo "Ansible $(VERSION) tests completed!"
.PHONY: test-ansible-version

test-all-versions: ## Test against all supported Ansible versions (compatible with current Python)
	@echo "Testing against multiple Ansible versions..."
	@python_version=$$(python3 --version | awk '{print $$2}' | cut -d. -f1,2); \
	if [ "$$(echo "$$python_version >= 3.11" | bc)" -eq 1 ]; then \
		echo "Python $$python_version detected: Testing Ansible 7, 8, 9 (compatible versions)"; \
		versions="7 8 9"; \
	else \
		echo "Python $$python_version detected: Testing Ansible 4-9"; \
		versions="4 5 6 7 8 9"; \
	fi; \
	for version in $$versions; do \
		echo ""; \
		echo "========================================"; \
		echo "Testing Ansible $$version"; \
		echo "========================================"; \
		$(MAKE) test-ansible-version VERSION=$$version || exit 1; \
	done
	@echo ""
	@echo "All version tests completed successfully!"
.PHONY: test-all-versions

# Individual version targets for parallel execution
test-ansible-4:
	@$(MAKE) test-ansible-version VERSION=4
.PHONY: test-ansible-4

test-ansible-5:
	@$(MAKE) test-ansible-version VERSION=5
.PHONY: test-ansible-5

test-ansible-6:
	@$(MAKE) test-ansible-version VERSION=6
.PHONY: test-ansible-6

test-ansible-7:
	@$(MAKE) test-ansible-version VERSION=7
.PHONY: test-ansible-7

test-ansible-8:
	@$(MAKE) test-ansible-version VERSION=8
.PHONY: test-ansible-8

test-ansible-9:
	@$(MAKE) test-ansible-version VERSION=9
.PHONY: test-ansible-9

test-all-versions-parallel: test-ansible-7 test-ansible-8 test-ansible-9 ## Test compatible versions in parallel (use with make -j3)
	@echo ""
	@echo "All parallel version tests completed!"
	@echo "Note: Use Docker tests for full version coverage: make -j4 docker-test-all-parallel"
.PHONY: test-all-versions-parallel

clean-venvs: ## Remove all test virtual environments
	@echo "Removing test virtual environments..."
	rm -rf venv-ansible-*
.PHONY: clean-venvs

# Docker-based testing targets
docker-test: ## Run tests in Docker for specific Ansible version (usage: make docker-test VERSION=9)
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION not specified. Usage: make docker-test VERSION=9"; \
		exit 1; \
	fi
	./docker-test.sh $(VERSION)
.PHONY: docker-test

docker-test-all: ## Run tests in Docker for all Ansible versions
	./docker-test.sh all
.PHONY: docker-test-all

# Individual Docker test targets for parallel execution
docker-test-4:
	@./docker-test.sh 4
.PHONY: docker-test-4

docker-test-5:
	@./docker-test.sh 5
.PHONY: docker-test-5

docker-test-6:
	@./docker-test.sh 6
.PHONY: docker-test-6

docker-test-7:
	@./docker-test.sh 7
.PHONY: docker-test-7

docker-test-8:
	@./docker-test.sh 8
.PHONY: docker-test-8

docker-test-9:
	@./docker-test.sh 9
.PHONY: docker-test-9

docker-test-latest:
	@./docker-test.sh latest
.PHONY: docker-test-latest

docker-test-all-parallel: docker-test-4 docker-test-5 docker-test-6 docker-test-7 docker-test-8 docker-test-9 docker-test-latest ## Run Docker tests in parallel (use with make -j4)
	@echo ""
	@echo "All parallel Docker tests completed!"
.PHONY: docker-test-all-parallel

docker-test-syntax: ## Run syntax check in Docker (usage: make docker-test-syntax VERSION=9)
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION not specified. Usage: make docker-test-syntax VERSION=9"; \
		exit 1; \
	fi
	./docker-test.sh $(VERSION) 3.11 syntax
.PHONY: docker-test-syntax

docker-test-compose: ## Run compose test in Docker (usage: make docker-test-compose VERSION=9)
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION not specified. Usage: make docker-test-compose VERSION=9"; \
		exit 1; \
	fi
	./docker-test.sh $(VERSION) 3.11 test-compose
.PHONY: docker-test-compose

docker-clean: ## Clean up Docker test images
	@echo "Removing Docker test images..."
	docker rmi $(shell docker images -q ansible-docker-deploy-test) 2>/dev/null || true
.PHONY: docker-clean
