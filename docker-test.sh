#!/usr/bin/env bash
#
# Run tests in Docker containers for different Ansible versions
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ANSIBLE_VERSION="${1:-all}"
PYTHON_VERSION="${2:-3.11}"
TEST_TYPE="${3:-syntax}"

# Function to run test for a specific version
run_test() {
    local version=$1
    local python_ver=$2
    
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}Testing Ansible ${version} with Python ${python_ver}${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    # Use Python 3.8 for Ansible 2.9
    if [ "$version" = "2.9" ]; then
        python_ver="3.8"
    fi
    
    # Build the test image
    echo -e "${YELLOW}Building test image...${NC}"
    docker build \
        --build-arg ANSIBLE_VERSION="$version" \
        --build-arg PYTHON_VERSION="$python_ver" \
        -t ansible-docker-deploy-test:ansible-${version} \
        -f Dockerfile.test \
        .
    
    # Run the test
    echo -e "${YELLOW}Running tests...${NC}"
    case "$TEST_TYPE" in
        syntax)
            docker run --rm ansible-docker-deploy-test:ansible-${version} \
                ansible-playbook tests/test.yml -i tests/inventory --syntax-check
            ;;
        lint)
            docker run --rm ansible-docker-deploy-test:ansible-${version} \
                sh -c "pip install yamllint ansible-lint && yamllint . && ansible-lint"
            ;;
        all)
            docker run --rm \
                -v /var/run/docker.sock:/var/run/docker.sock \
                ansible-docker-deploy-test:ansible-${version} \
                sh -c "cd tests && ./run-tests.sh"
            ;;
        *)
            docker run --rm ansible-docker-deploy-test:ansible-${version} \
                ansible-playbook "tests/${TEST_TYPE}.yml" -i tests/inventory -vv
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Ansible ${version} tests passed${NC}"
        return 0
    else
        echo -e "${RED}✗ Ansible ${version} tests failed${NC}"
        return 1
    fi
}

# Main execution
if [ "$ANSIBLE_VERSION" = "all" ]; then
    echo -e "${GREEN}=== Running tests for all Ansible versions ===${NC}\n"
    
    VERSIONS=("4" "5" "6" "7" "8" "9" "latest")
    FAILED_TESTS=()
    
    for version in "${VERSIONS[@]}"; do
        if ! run_test "$version" "$PYTHON_VERSION"; then
            FAILED_TESTS+=("$version")
        fi
    done
    
    # Summary
    echo -e "\n${GREEN}=== Test Summary ===${NC}"
    if [ ${#FAILED_TESTS[@]} -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Failed tests:${NC}"
        for version in "${FAILED_TESTS[@]}"; do
            echo -e "${RED}  - Ansible $version${NC}"
        done
        exit 1
    fi
else
    run_test "$ANSIBLE_VERSION" "$PYTHON_VERSION"
fi
