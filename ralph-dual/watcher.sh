#!/bin/bash
# Watcher Loop - Test app and create Linear tasks for REAL issues
# Each session: one phase action, then exit
# Usage: ./watcher.sh [--sleep seconds] [--max iterations] [--project name]

set -e

# Default configuration
SLEEP_INTERVAL=30         # Seconds between sessions
MAINTENANCE_SLEEP=300     # Longer sleep when in maintenance (5 min)
MAX_ITERATIONS=0          # 0 = infinite
PROJECT_OVERRIDE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --sleep)
      SLEEP_INTERVAL="$2"
      shift 2
      ;;
    --sleep=*)
      SLEEP_INTERVAL="${1#*=}"
      shift
      ;;
    --max)
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --max=*)
      MAX_ITERATIONS="${1#*=}"
      shift
      ;;
    --project)
      PROJECT_OVERRIDE="$2"
      shift 2
      ;;
    --project=*)
      PROJECT_OVERRIDE="${1#*=}"
      shift
      ;;
    --help|-h)
      echo "Watcher Loop - Quality guardian for your app"
      echo ""
      echo "Finds REAL issues and suggests GENUINE improvements."
      echo "Does NOT manufacture problems."
      echo ""
      echo "Usage: ./ralph-dual/watcher.sh [options]"
      echo ""
      echo "Options:"
      echo "  --sleep <seconds>    Sleep between sessions (default: 30)"
      echo "  --max <iterations>   Max iterations, 0=infinite (default: 0)"
      echo "  --project <name>     Override Linear project"
      echo "  --help               Show this help"
      echo ""
      echo "Phases:"
      echo "  discovery   - Explore app, create epics"
      echo "  testing     - Test one route+category"
      echo "  review      - Evaluate epic, decide next"
      echo "  maintenance - App is good, wait for Builder"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUIDANCE_FILE="$SCRIPT_DIR/epic-guidance.json"
STATE_FILE="$SCRIPT_DIR/watcher-state.json"
WATCHER_PROMPT="$SCRIPT_DIR/watcher.md"

# Check files
if [ ! -f "$WATCHER_PROMPT" ]; then
  echo "Error: watcher.md not found"
  exit 1
fi

if [ ! -f "$GUIDANCE_FILE" ]; then
  if [ -f "$SCRIPT_DIR/epic-guidance.json.example" ]; then
    cp "$SCRIPT_DIR/epic-guidance.json.example" "$GUIDANCE_FILE"
    echo "Created epic-guidance.json - please configure Linear settings"
    exit 1
  fi
  echo "Error: epic-guidance.json not found"
  exit 1
fi

if [ ! -f "$STATE_FILE" ]; then
  if [ -f "$SCRIPT_DIR/watcher-state.json.example" ]; then
    cp "$SCRIPT_DIR/watcher-state.json.example" "$STATE_FILE"
    echo "Created watcher-state.json in discovery phase"
  else
    echo "Error: watcher-state.json.example not found"
    exit 1
  fi
fi

echo "========================================"
echo "  Watcher Loop - Quality Guardian"
echo "========================================"
echo "  Sleep: ${SLEEP_INTERVAL}s (${MAINTENANCE_SLEEP}s in maintenance)"
echo "  Max: ${MAX_ITERATIONS:-infinite} iterations"
if [ -n "$PROJECT_OVERRIDE" ]; then
  echo "  Project: $PROJECT_OVERRIDE"
fi
echo "========================================"
echo ""

iteration=0

while :; do
  iteration=$((iteration + 1))

  if [ "$MAX_ITERATIONS" -gt 0 ] && [ "$iteration" -gt "$MAX_ITERATIONS" ]; then
    echo "Max iterations reached. Exiting."
    exit 0
  fi

  # Check current phase for logging
  CURRENT_PHASE=$(grep -o '"phase": *"[^"]*"' "$STATE_FILE" 2>/dev/null | cut -d'"' -f4 || echo "unknown")

  echo ""
  echo "=== Session $iteration [$CURRENT_PHASE] - $(date) ==="

  # Prepare prompt with directory-aware path substitution
  PROMPT_CONTENT=$(cat "$WATCHER_PROMPT")
  RALPH_DIR="${SCRIPT_DIR#$(pwd)/}"
  [ "$RALPH_DIR" = "$SCRIPT_DIR" ] && RALPH_DIR=$(realpath --relative-to="$(pwd)" "$SCRIPT_DIR" 2>/dev/null || basename "$SCRIPT_DIR")
  PROMPT_CONTENT="${PROMPT_CONTENT//\{RALPH_DIR\}/$RALPH_DIR}"
  if [ -n "$PROJECT_OVERRIDE" ]; then
    PROMPT_CONTENT="**PROJECT**: Use Linear project '$PROJECT_OVERRIDE'

$PROMPT_CONTENT"
  fi

  # Run Claude Code
  OUTPUT=$(echo "$PROMPT_CONTENT" | claude --dangerously-skip-permissions --print 2>&1 | tee /dev/stderr) || true

  # Determine sleep based on phase
  NEW_PHASE=$(grep -o '"phase": *"[^"]*"' "$STATE_FILE" 2>/dev/null | cut -d'"' -f4 || echo "testing")

  if [ "$NEW_PHASE" = "maintenance" ]; then
    echo ""
    echo "App is in good shape. Sleeping ${MAINTENANCE_SLEEP}s..."
    sleep "$MAINTENANCE_SLEEP"
  else
    echo ""
    echo "Sleeping ${SLEEP_INTERVAL}s..."
    sleep "$SLEEP_INTERVAL"
  fi
done
