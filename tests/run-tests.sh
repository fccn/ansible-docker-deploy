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

# Setup
echo "Setting up test environment..."
cd "$PROJECT_DIR"

# Run tests using Makefile
echo -e "${YELLOW}Running all tests...${NC}\n"

if make test; then
    echo -e "\n${GREEN}=== All tests passed! ===${NC}"
    exit 0
else
    echo -e "\n${RED}=== Tests failed ===${NC}"
    exit 1
fi
