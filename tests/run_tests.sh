#!/bin/bash

# Script para ejecutar todos los tests del plugin dependencies.nvim
# Usage: ./tests/run_tests.sh

set -e  # Salir si algún test falla

echo "========================================="
echo "  Dependencies.nvim - Test Suite"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track test results
FAILED=0
TOTAL=0

# Function to run a test suite
run_test_suite() {
  local test_name=$1
  local test_file=$2

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Running: $test_name"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  TOTAL=$((TOTAL + 1))

  if nvim --headless -c "set runtimepath+=." -c "luafile $test_file" -c "qa"; then
    echo -e "${GREEN}✓ $test_name - PASSED${NC}"
  else
    echo -e "${RED}✗ $test_name - FAILED${NC}"
    FAILED=$((FAILED + 1))
  fi

  echo ""
}

# Run all test suites
echo "Starting test execution..."
echo ""

run_test_suite "Parser Tests" "lua/tests/parser_spec.lua"
run_test_suite "Maven Integration Tests" "lua/tests/maven_spec.lua"
run_test_suite "Virtual Text Tests" "lua/tests/virtual_text_spec.lua"

# Print summary
echo "========================================="
echo "  Test Summary"
echo "========================================="
if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}✓ All test suites passed! ($TOTAL/$TOTAL)${NC}"
  exit 0
else
  echo -e "${RED}✗ $FAILED/$TOTAL test suites failed${NC}"
  exit 1
fi

