#!/bin/bash

# Script to run Maven integration tests
# Usage: ./tests/run_maven_test.sh

echo "Running Maven Integration Tests..."
echo "=================================="

nvim --headless -c "set runtimepath+=." -c "luafile lua/tests/maven_spec.lua" -c "qa"

echo ""
echo "Tests completed!"

