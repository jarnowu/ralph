#!/bin/bash
# Builder Loop - Implement Linear tasks
# Each iteration implements ONE task, then exits
# Usage: ./ralph-dual/builder.sh [--sleep seconds] [--max iterations] [--project name]

set -e

# Default configuration
SLEEP_INTERVAL=5       # Seconds between sessions (fast - Builder is responsive)
MAX_ITERATIONS=0       # 0 = infinite
PROJECT_OVERRIDE=""    # Override project from epic-guidance.json
MAX_IDLE=10            # Exit after N "no tasks" in a row

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
      echo "Builder Loop - Implement Linear tasks"
      echo ""
      echo "Each iteration implements ONE task from Linear,"
      echo "commits the changes, then exits."
      echo "The bash loop provides continuity across sessions."
      echo ""
      echo "Usage: ./ralph-dual/builder.sh [options]"
      echo ""
      echo "Options:"
      echo "  --sleep <seconds>    Sleep between iterations (default: 5)"
      echo "  --max <iterations>   Max iterations, 0=infinite (default: 0)"
      echo "  --project <name>     Override Linear project"
      echo "  --help               Show this help"
      echo ""
      echo "Required files (in ralph-dual/):"
      echo "  epic-guidance.json   - Linear config and project context"
      echo "  progress.txt         - Learnings (auto-created)"
      echo ""
      echo "Example:"
      echo "  ./ralph-dual/builder.sh --sleep 10 --project 'My App'"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage"
      exit 1
      ;;
  esac
done

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUIDANCE_FILE="$SCRIPT_DIR/epic-guidance.json"
BUILDER_PROMPT="$SCRIPT_DIR/builder.md"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"

# Check required files
if [ ! -f "$BUILDER_PROMPT" ]; then
  echo "Error: builder.md not found"
  exit 1
fi

if [ ! -f "$GUIDANCE_FILE" ]; then
  echo "Error: epic-guidance.json not found in $SCRIPT_DIR"
  echo "Run Watcher first or create from template:"
  echo "  cp ralph-dual/epic-guidance.json.example ralph-dual/epic-guidance.json"
  exit 1
fi

# Initialize progress file with proper structure
if [ ! -f "$PROGRESS_FILE" ]; then
  cat > "$PROGRESS_FILE" << 'EOF'
## Codebase Patterns

<!-- Curated patterns - max 20 entries -->
<!-- Builder adds genuinely reusable patterns here -->
<!-- Watcher curates during maintenance phase -->

---

## Recent Sessions

<!-- Keep only last 10 sessions -->
<!-- Older sessions get deleted to save context -->

EOF
fi

echo "========================================"
echo "  Builder Loop"
echo "========================================"
echo "  Sleep: ${SLEEP_INTERVAL}s"
echo "  Max: ${MAX_ITERATIONS:-infinite} iterations"
if [ -n "$PROJECT_OVERRIDE" ]; then
  echo "  Project: $PROJECT_OVERRIDE"
fi
echo "========================================"
echo ""

iteration=0
idle_count=0

while :; do
  iteration=$((iteration + 1))

  if [ "$MAX_ITERATIONS" -gt 0 ] && [ "$iteration" -gt "$MAX_ITERATIONS" ]; then
    echo "Max iterations reached. Exiting."
    exit 0
  fi

  echo ""
  echo "=== Builder Session $iteration - $(date) ==="

  # Prepare prompt with directory-aware path substitution
  PROMPT_CONTENT=$(cat "$BUILDER_PROMPT")
  RALPH_DIR="${SCRIPT_DIR#$(pwd)/}"
  if [ "$RALPH_DIR" = "$SCRIPT_DIR" ]; then
    if [ "$SCRIPT_DIR" = "$(pwd)" ]; then
      RALPH_DIR="."
    else
      RALPH_DIR=$(realpath --relative-to="$(pwd)" "$SCRIPT_DIR" 2>/dev/null || basename "$SCRIPT_DIR")
    fi
  fi
  PROMPT_CONTENT="${PROMPT_CONTENT//\{RALPH_DIR\}/$RALPH_DIR}"
  if [ -n "$PROJECT_OVERRIDE" ]; then
    PROMPT_CONTENT="**PROJECT**: Use Linear project '$PROJECT_OVERRIDE'

$PROMPT_CONTENT"
  fi

  # Run Claude Code
  OUTPUT=$(echo "$PROMPT_CONTENT" | claude --dangerously-skip-permissions --print 2>&1 | tee /dev/stderr) || true

  # Check for no tasks
  if echo "$OUTPUT" | grep -q "NO_TASKS"; then
    idle_count=$((idle_count + 1))
    echo ""
    echo "No tasks. Idle: $idle_count/$MAX_IDLE"

    if [ "$idle_count" -ge "$MAX_IDLE" ]; then
      echo "Max idle reached. Exiting."
      echo "Watcher may not be running or queue is empty."
      exit 0
    fi

    # Longer sleep when idle
    sleep $((SLEEP_INTERVAL * 3))
    continue
  fi

  # Reset idle on any activity
  idle_count=0

  # Check for blocked
  if echo "$OUTPUT" | grep -q "BLOCKED"; then
    echo ""
    echo "Task blocked. See output above."
  fi

  echo ""
  echo "Session complete. Sleeping ${SLEEP_INTERVAL}s..."
  sleep "$SLEEP_INTERVAL"
done
