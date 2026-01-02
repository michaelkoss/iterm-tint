#!/bin/sh
# Run test suite under both bash and zsh for full coverage
# Per CLAUDE.md: "Always test in both bash and zsh"

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_SCRIPT="$SCRIPT_DIR/test.sh"

printf "Running tests under bash...\n"
printf "============================\n"
bash "$TEST_SCRIPT"

printf "\nRunning tests under zsh...\n"
printf "===========================\n"
zsh "$TEST_SCRIPT"

printf "\n=== All shell tests passed ===\n"
