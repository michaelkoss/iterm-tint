#!/bin/bash
# iterm-tint test suite
# Run from project root: ./tests/test.sh
#
# For full test coverage, run under both shells:
#   bash ./tests/test.sh && zsh ./tests/test.sh

# Track test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output (if terminal supports it)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    NC=''
fi

# Test assertion helper
assert_eq() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ "$expected" = "$actual" ]; then
        printf "${GREEN}PASS${NC} %s\n" "$test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        printf "${RED}FAIL${NC} %s\n" "$test_name"
        printf "       expected: %s\n" "$expected"
        printf "       actual:   %s\n" "$actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Source the main script to get access to functions
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# Prevent initialization hooks by setting TERM_PROGRAM to something other than iTerm
TERM_PROGRAM="test"
# Skip initialization/side effects by setting the guard variable before sourcing
_ITINT_INITIALIZED=1
source "$SCRIPT_DIR/iterm-tint.sh"

printf "\n=== iterm-tint test suite ===\n\n"

# ============================================
# DJB2 Hash Tests
# ============================================
printf "DJB2 Hash Tests:\n"

# Test basic hashing - same input should produce same output
hue1=$(_itint_path_to_hue "/home/user/project")
hue2=$(_itint_path_to_hue "/home/user/project")
assert_eq "$hue1" "$hue2" "Same path produces same hue"

# Test known fixture produces expected hue (deterministic)
# This verifies the DJB2 algorithm implementation is correct
assert_eq "185" "$hue1" "Known path produces expected hue (185)"

# Test output is in valid hue range (0-359)
hue=$(_itint_path_to_hue "/some/arbitrary/path")
if [ "$hue" -ge 0 ] && [ "$hue" -lt 360 ]; then
    printf "${GREEN}PASS${NC} Hue is in valid range (0-359): %s\n" "$hue"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf "${RED}FAIL${NC} Hue out of range: %s\n" "$hue"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test empty string
hue_empty=$(_itint_path_to_hue "")
if [ "$hue_empty" -ge 0 ] && [ "$hue_empty" -lt 360 ]; then
    printf "${GREEN}PASS${NC} Empty string produces valid hue: %s\n" "$hue_empty"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf "${RED}FAIL${NC} Empty string hue out of range: %s\n" "$hue_empty"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test single character
hue_char=$(_itint_path_to_hue "a")
if [ "$hue_char" -ge 0 ] && [ "$hue_char" -lt 360 ]; then
    printf "${GREEN}PASS${NC} Single char produces valid hue: %s\n" "$hue_char"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf "${RED}FAIL${NC} Single char hue out of range: %s\n" "$hue_char"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test long path
long_path="/very/long/path/that/goes/deep/into/the/filesystem/structure/a/b/c/d/e/f"
hue_long=$(_itint_path_to_hue "$long_path")
if [ "$hue_long" -ge 0 ] && [ "$hue_long" -lt 360 ]; then
    printf "${GREEN}PASS${NC} Long path produces valid hue: %s\n" "$hue_long"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf "${RED}FAIL${NC} Long path hue out of range: %s\n" "$hue_long"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test path with special characters
special_path="/path/with spaces/and-dashes/and_underscores"
hue_special=$(_itint_path_to_hue "$special_path")
if [ "$hue_special" -ge 0 ] && [ "$hue_special" -lt 360 ]; then
    printf "${GREEN}PASS${NC} Special chars path produces valid hue: %s\n" "$hue_special"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf "${RED}FAIL${NC} Special chars hue out of range: %s\n" "$hue_special"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ============================================
# Summary
# ============================================
printf "\n=== Results ===\n"
printf "Tests run:    %d\n" "$TESTS_RUN"
printf "Tests passed: %d\n" "$TESTS_PASSED"
printf "Tests failed: %d\n" "$TESTS_FAILED"

if [ "$TESTS_FAILED" -gt 0 ]; then
    printf "\n${RED}FAILED${NC}\n\n"
    exit 1
else
    printf "\n${GREEN}ALL TESTS PASSED${NC}\n\n"
    exit 0
fi
