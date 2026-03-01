#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
C0_DIR="$(dirname "$SCRIPT_DIR")"

declare -a TESTS=(
    "simple.c0:42"
    "arithmetic.c0:30"
    "add.c0:7"
    "sum4.c0:100"
    "factorial.c0:120"
    "fibonacci.c0:55"
    "nested_control.c0:103"
)

PASSED=0
FAILED=0

echo "Running c0 tests..."
echo "==================="

for test in "${TESTS[@]}"; do
    IFS=':' read -r filename expected <<< "$test"

    printf "%-25s" "$filename"

    # Run the test
    result=$("$C0_DIR/run_c0.sh" "$SCRIPT_DIR/$filename" 2>&1 | grep -o '\[Result: [0-9-]*\]' | grep -o '[0-9-]*' || echo "ERROR")

    if [ "$result" = "$expected" ]; then
        echo "PASS (got $result)"
        ((PASSED++))
    else
        echo "FAIL (expected $expected, got $result)"
        ((FAILED++))
    fi
done

echo "==================="
echo "Passed: $PASSED / $((PASSED + FAILED))"

if [ $FAILED -gt 0 ]; then
    exit 1
fi

