# Ralph Agent Instructions

## Overview

Ralph is an autonomous AI agent loop that runs AI coding tools repeatedly until tasks are complete. Each iteration is a fresh instance with clean context.

**Two Modes:**
1. **Single-Agent Mode** (`ralph.sh`) - Uses `prd.json` for bounded task lists (5-15 stories)
2. **Dual-Agent Mode** (`watcher.sh` + `builder.sh`) - Uses Linear for continuous development

## Single-Agent Mode (Original Ralph)

```bash
# Run Ralph with Amp (default)
./ralph.sh [max_iterations]

# Run Ralph with Claude Code
./ralph.sh --tool claude [max_iterations]
```

**Key Files:**
- `ralph.sh` - Bash loop spawning fresh AI instances
- `prompt.md` - Instructions for Amp
- `CLAUDE.md` - Instructions for Claude Code
- `prd.json` - Bounded task list with `passes` status

## Dual-Agent Mode (Continuous Development)

Two independent agents coordinated through Linear:

| Agent | Script | Role |
|-------|--------|------|
| **Watcher** | `watcher.sh` | QA/Product Owner - Tests app, finds issues, creates Linear tasks |
| **Builder** | `builder.sh` | Developer - Implements ONE Linear task per iteration |

```bash
# Terminal 1: Start Watcher (tests app, creates tasks)
./watcher.sh --project "My Project"

# Terminal 2: Start Builder (implements tasks)
./builder.sh --project "My Project"
```

**Key Files:**
- `watcher.md` / `builder.md` - Agent prompts (one task per session)
- `watcher.sh` / `builder.sh` - Bash loops (provide continuity)
- `epic-guidance.json` - Linear config and project context
- `watcher-state.json` - Watcher's testing progress and coverage
- Linear - Task queue (replaces `prd.json`)

**Shared Resources:**
- `epic-guidance.json` - Linear config and project context
- `watcher-state.json` - Watcher's phase and testing progress
- Git repository - Code and commit history
- **Knowledge backend** (one of):
  - `progress.txt` - File mode (default, zero setup)
  - Recall MCP - Semantic search mode (optional, see `docs/SETUP-RECALL.md`)

### Knowledge Backend

Agents auto-detect backend from `epic-guidance.json`:
- **No `recallStore` field** → File mode (progress.txt)
- **Has `recallStore` field** → Recall mode (semantic search)

#### File Mode: progress.txt Structure

```
## Codebase Patterns     ← Curated, max 20 entries
---
## Recent Sessions       ← Last 10 sessions only
```

| Who | Does What |
|-----|-----------|
| Builder | Creates file, adds session logs, promotes patterns to top |
| Watcher | Curates during maintenance: trims old sessions, removes stale patterns |

**Why:** Both agents read this file. Unbounded growth = context waste.

#### Recall Mode (Optional)

Semantic search with confidence scoring. See `docs/SETUP-RECALL.md` for setup.

| Who | Does What |
|-----|-----------|
| Builder | `recall_query` before implementing, `recall_record` learnings, `recall_feedback` |
| Watcher | `recall_query` before testing, `recall_record` edge cases, `recall_feedback` in maintenance |

**Why:** Semantic queries return only relevant patterns vs reading entire file.

## Commands Reference

```bash
# Single-Agent Mode
./ralph.sh --tool claude 10    # Run 10 iterations with Claude Code

# Dual-Agent Mode
./watcher.sh --sleep 60        # Test every 60 seconds
./builder.sh --sleep 5         # Check for tasks every 5 seconds
./watcher.sh --project "App"   # Override Linear project
./builder.sh --max 50          # Run max 50 iterations

# Flowchart dev server
cd flowchart && npm run dev
```

## Core Patterns

### Fresh Context Every Iteration
- Each iteration spawns a **new AI instance** with clean context
- Process termination IS the feature (clears accumulated garbage)
- Memory persists only via: git history, knowledge backend, Linear/prd.json

### One Task Per Session
- Single-agent: One PRD story per iteration
- Builder: One Linear task per iteration
- If task is too big, context fills and code quality degrades

### Files as Memory
- **Knowledge backend** - Learnings and patterns:
  - File mode: `progress.txt` (curated: max 20 patterns, 10 sessions)
  - Recall mode: SQLite via MCP (unlimited, semantic search)
- `AGENTS.md` - Project-specific patterns for AI tools
- Git commits - Record of completed work
- Linear/prd.json - Task status

### Backpressure via Tests
- Never commit broken code
- Quality checks must pass before committing
- If checks fail, fix and retry (don't skip)

## Dual-Agent Coordination

### Watcher Responsibilities (per session)

**Core Principle:** Find REAL issues, suggest GENUINE improvements. If app is good, say so. Do NOT manufacture problems.

**Four phases:**
1. **discovery** - Explore app, create epics in Linear
2. **testing** - Test ONE route + ONE category, create tasks for REAL issues only
3. **review** - Epic done, evaluate honestly, decide next step
4. **maintenance** - App is healthy, wait for Builder to catch up

**Quality Gates (before creating any task):**
- Is this a REAL issue users would notice?
- Would fixing this make a MEANINGFUL difference?
- Am I suggesting this because it's needed, or because I feel I should suggest SOMETHING?

**Task creation required fields:**
```
team: linearConfig.teamId
project: linearConfig.projectId
labels: ["ralph-generated", "<domain>", "<type>"]
parentId: currentEpic.linearId (UUID, not identifier)
```
- Domain: `Frontend` | `Backend` | `Security`
- Type: `Bug` | `Feature` | `Improvement`

**Resource management:** Call `browser_close` before exiting every session.

**Never writes code or commits. Silence is golden when app is good.**

### Builder Responsibilities (per session)
- Query Linear for ONE highest-priority task
- Mark task "In Progress" immediately
- Investigate codebase before coding
- Implement the task following existing patterns
- Run quality checks, commit only if passing
- Mark task "Done" in Linear
- Append learnings to `progress.txt`
- **Never creates new tasks**

### Coordination via State
- Linear task states: Todo → In Progress → Done
- `epic-guidance.json`: Current epic context
- No direct communication between agents

### Linear Query Efficiency

**Problem:** Querying Linear naively can return 100+ tasks with full descriptions → context blown.

**Solution:** Two-stage queries.

| Agent | Operation | Strategy |
|-------|-----------|----------|
| Builder | Get next task | Stage 1: Get 1 ID (minimal fields) → Stage 2: Get that task's full details |
| Watcher | Check duplicates | Search with specific terms, limit 5, titles only |

**Rules:**
- Always use `limit` parameter
- Request minimal fields in search queries (id, title only)
- Fetch full details only for the ONE task you're working on
- Use targeted search terms, not "get all"

### Task Dependencies

**Watcher sets dependencies at creation time:**
- Before creating task, Watcher asks: "Does this need something else first?"
- If YES: Find or create prerequisite task, then create dependent task with `blockedBy` link
- Create prerequisite tasks first, dependent tasks second

**Builder respects dependencies:**
- Queries 5 candidates with `blockedBy` field
- Skips tasks where blockedBy has unfinished tasks
- Picks first unblocked task

**Fallback (implicit dependency discovered during implementation):**
- Rare if Watcher sets up dependencies correctly
- Builder finds/creates prerequisite, adds `blockedBy` link
- Moves current task to Backlog, exits

## Setup for Dual-Agent Mode

1. Create Linear project for your app
2. Copy `epic-guidance.json.example` to `epic-guidance.json`
3. Configure `linearConfig.teamId` and `linearConfig.projectId`
4. Set `currentEpic` with your initial focus
5. (Optional) Enable Recall for semantic knowledge search:
   - See `docs/SETUP-RECALL.md` for setup
   - Or use `epic-guidance.recall.json.example` as template
6. Start both agents in separate terminals

## Flowchart

Interactive visualization at `flowchart/`:
```bash
cd flowchart
npm install
npm run dev
```

## Anti-Patterns to Avoid

- ❌ Plugin/hook approach (context accumulates within session)
- ❌ Single large JSON with 100+ tasks (bloats first read)
- ❌ One agent doing everything (context pollution)
- ❌ Complex orchestration (simplicity wins)
- ❌ Committing broken code (compounds across iterations)
- ❌ Leaving browser open (resource leak across sessions)
- ❌ Creating tasks without project/parentId (orphaned in Linear)
- ❌ Manufacturing issues when app is healthy (noise)
