.PHONY: help test lint syntax-check install clean test-compose test-files test-secrets molecule

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## Install development dependencies
	pip install -r requirements-dev.txt

test: syntax-check lint test-all ## Run all tests

lint: ## Run linting (yamllint and ansible-lint)
	@echo "Running yamllint..."
	yamllint .
	@echo "Running ansible-lint..."
	ansible-lint

syntax-check: ## Run Ansible syntax check
	@echo "Running syntax check..."
	printf '[defaults]\nroles_path=../' > ansible.cfg
	ansible-playbook tests/test.yml -i tests/inventory --syntax-check

test-all: ## Run all integration tests
	@echo "Running all integration tests..."
	cd tests && ./run-tests.sh

test-compose: ## Run compose deployment test
	@echo "Running compose deployment test..."
	ansible-playbook tests/test-compose.yml -i tests/inventory -vv

test-files: ## Run files and templates test
	@echo "Running files and templates test..."
	ansible-playbook tests/test-files-templates.yml -i tests/inventory -vv

test-secrets: ## Run secrets and configs test
	@echo "Running secrets and configs test..."
	ansible-playbook tests/test-secrets-configs.yml -i tests/inventory -vv

molecule: ## Run molecule tests
	@echo "Running molecule tests..."
	molecule test

molecule-converge: ## Run molecule converge
	molecule converge

molecule-verify: ## Run molecule verify
	molecule verify

molecule-destroy: ## Destroy molecule instances
	molecule destroy

clean: ## Clean up test artifacts and Docker resources
	@echo "Cleaning up..."
	rm -rf ansible.cfg
	docker stop $$(docker ps -aq) 2>/dev/null || true
	docker rm $$(docker ps -aq) 2>/dev/null || true
	docker swarm leave --force 2>/dev/null || true
	rm -rf /tmp/ansible-docker-deploy-test*

setup: ## Setup development environment
	python3 -m venv venv
	./venv/bin/pip install -r requirements-dev.txt
	@echo "Development environment ready!"
	@echo "Activate it with: source venv/bin/activate"
