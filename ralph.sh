#!/bin/bash

# Ralph Wiggum loop script - iteratively implements the website

MAX_ITERATIONS=${1:-1}
START_TIME=$(date +%s)

echo "════════════════════════════════════════════════════════════"
echo "Ralph Wiggum Loop Starting"
echo "════════════════════════════════════════════════════════════"
echo "Max iterations: $MAX_ITERATIONS"
echo "Start time: $(date)"
echo ""

for ((i=1; i<=MAX_ITERATIONS; i++)); do
  ITERATION_START=$(date +%s)
  ITERATION_TIME=$(printf "%02d" $((i)))

  echo "─────────────────────────────────────────────────────────"
  echo "Iteration $i/$MAX_ITERATIONS"
  echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "─────────────────────────────────────────────────────────"

  # Run claude with the prompt
  claude -p --model opus --dangerously-skip-permissions "$(cat ralph-prompt.md)"

  ITERATION_END=$(date +%s)
  ITERATION_DURATION=$((ITERATION_END - ITERATION_START))

  echo ""
  echo "✓ Iteration $i completed in ${ITERATION_DURATION}s"
  echo ""
done

END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

echo "════════════════════════════════════════════════════════════"
echo "Ralph Wiggum Loop Complete"
echo "════════════════════════════════════════════════════════════"
echo "Total iterations: $MAX_ITERATIONS"
echo "Total time: ${TOTAL_DURATION}s ($(printf "%d min %d sec" $((TOTAL_DURATION/60)) $((TOTAL_DURATION%60))))"
echo "End time: $(date)"
echo "════════════════════════════════════════════════════════════"
