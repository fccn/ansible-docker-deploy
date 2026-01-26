#!/usr/bin/env bash
#
# Test runner script for ansible-docker-deploy role
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${GREEN}=== Ansible Docker Deploy - Test Suite ===${NC}\n"

# Function to run a test
run_test() {
    local test_name=$1
    local test_file=$2

    echo -e "${YELLOW}Running: ${test_name}${NC}"
    if ansible-playbook "$test_file" -i "$SCRIPT_DIR/inventory" -vv; then
        echo -e "${GREEN}✓ ${test_name} passed${NC}\n"
        return 0
    else
        echo -e "${RED}✗ ${test_name} failed${NC}\n"
        return 1
    fi
}

# Setup
echo "Setting up test environment..."
cd "$PROJECT_DIR"
printf '[defaults]\nroles_path=../' > ansible.cfg

# Track failures
FAILED_TESTS=()

# Run syntax check
echo -e "${YELLOW}Running syntax check...${NC}"
if ansible-playbook tests/test.yml -i tests/inventory --syntax-check; then
    echo -e "${GREEN}✓ Syntax check passed${NC}\n"
else
    echo -e "${RED}✗ Syntax check failed${NC}\n"
    FAILED_TESTS+=("Syntax check")
fi

# Run integration tests
run_test "Compose Deployment Test" "$SCRIPT_DIR/test-compose.yml" || FAILED_TESTS+=("Compose Deployment")
run_test "Files and Templates Test" "$SCRIPT_DIR/test-files-templates.yml" || FAILED_TESTS+=("Files and Templates")
run_test "Secrets and Configs Test" "$SCRIPT_DIR/test-secrets-configs.yml" || FAILED_TESTS+=("Secrets and Configs")

# Cleanup
echo -e "${YELLOW}Cleaning up...${NC}"
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true
docker swarm leave --force 2>/dev/null || true

# Summary
echo -e "\n${GREEN}=== Test Summary ===${NC}"
if [ ${#FAILED_TESTS[@]} -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Failed tests:${NC}"
    for test in "${FAILED_TESTS[@]}"; do
        echo -e "${RED}  - $test${NC}"
    done
    exit 1
fi
