# Dual-AI Ralph Loop Architecture

## Project Overview

**Owner:** Jarno (jarnowu)
**Repository:** https://github.com/jarnowu/ralph.git (forked from snarktank/ralph)
**Goal:** Extend the Ralph Wiggum autonomous coding pattern to support continuous, indefinite development using two independent AI agents coordinated through Linear.

---

## Table of Contents

1. [The Problem We're Solving](#the-problem-were-solving)
2. [Why Current Approaches Fail](#why-current-approaches-fail)
3. [Understanding Ralph: The Core Mechanism](#understanding-ralph-the-core-mechanism)
4. [Our Solution: Dual-AI Architecture](#our-solution-dual-ai-architecture)
5. [Technical Architecture](#technical-architecture)
6. [File Structure](#file-structure)
7. [Implementation Details](#implementation-details)
8. [Key Principles](#key-principles)
9. [Resources](#resources)

---

## The Problem We're Solving

### Current Ralph Limitations

The original Ralph pattern (by Geoffrey Huntley, popularized by Ryan Carson's snarktank/ralph repo) works excellently for **bounded tasks** - a PRD with 5-15 user stories that can be completed in a session.

However, it breaks down for **full application development** because:

1. **prd.json bloat**: A complete app requires 10+ epics and 100+ tasks. The JSON file becomes so large it fills the context window just reading the task list.

2. **No continuous task discovery**: Human must define ALL tasks upfront. The loop ends when tasks are complete. There's no mechanism for discovering new work (bugs, improvements, new features).

3. **Single responsibility**: One agent tries to both find problems AND fix them, leading to context pollution.

4. **Finite work queue**: When prd.json tasks are done, the loop stops. No continuous operation.

### What We Want

An autonomous development system that:
- Runs indefinitely without human intervention
- Continuously discovers new work (bugs, improvements, features)
- Maintains fresh context on every iteration
- Scales to full application development (100+ tasks)
- Self-improves over time

---

## Why Current Approaches Fail

### The Plugin Approach (DON'T USE)

Anthropic's official Claude Code plugin (`anthropics/claude-code/plugins/ralph-wiggum`) uses a **stop hook** pattern:

```
User runs /ralph-loop → Claude works → tries to exit → hook blocks exit → feeds same prompt → repeat
```

**Why this fails:**
- Loop happens **inside a single session**
- Context accumulates across iterations
- By iteration 5-10, context is polluted
- Effectiveness degrades progressively

Geoffrey Huntley explicitly states: "the claude code plugin isn't it."

### The malloc/free Problem

LLMs have a fundamental limitation:
- They can **read files** (like malloc - allocate memory)
- They **cannot selectively forget** (no free() equivalent)
- Every file read, tool output, and failed attempt stays in context
- Once context is polluted, "like a bowling ball in the gutter, there's no saving it"

### The Solution: Kill the Process

The ONLY way to clear context is to **terminate the process entirely**.

Files become the only memory:
- Git history (commits)
- progress.txt (learnings)
- Task status (single-agent: `prd.json`, dual-agent: Linear + `ralph-dual/watcher-state.json`)
- AGENTS.md (patterns discovered)

**Iron rule:** One session = one task. If task is too big → context fills → poor code.

---

## Understanding Ralph: The Core Mechanism

### Ralph IS a Bash Loop

At its core, Ralph is elegantly simple:

```bash
while :; do cat PROMPT.md | claude --dangerously-skip-permissions --print; done
```

**What happens each iteration:**
1. Bash spawns a **completely new Claude process**
2. Claude reads PROMPT.md, AGENTS.md, prd.json
3. Claude picks ONE task, implements it, tests, commits
4. Claude process **terminates** (context destroyed)
5. Loop restarts → fresh Claude process
6. New Claude reads files, picks next task
7. Repeat indefinitely

### Why This Works

- **Fresh context every iteration**: No accumulated garbage
- **Files as memory**: Only intentional state persists
- **Deterministic starting point**: Every iteration begins identically
- **No context degradation**: Iteration 100 is as effective as iteration 1

### The Critical Insight

The bash loop is not orchestration overhead - **it IS the architecture**. The process termination is the feature, not a bug.

---

## Our Solution: Dual-AI Architecture

### Core Idea

Split responsibilities between two independent bash loops:

| Role | Responsibility | Loop |
|------|---------------|------|
| **Watcher** | Find work (bugs, issues, improvements) | Terminal 1 |
| **Builder** | Execute work (implement, test, commit) | Terminal 2 |

Both loops share:
- Linear (task queue via MCP)
- ralph-dual/epic-guidance.json (lightweight context file)
- Git repository (code + history)
- ralph-dual/progress.txt (learnings log)

### Why Two Agents?

1. **Separation of concerns**: Finding problems ≠ fixing problems
2. **Continuous discovery**: Watcher always finds new work
3. **No task list bloat**: Tasks live in Linear, not JSON
4. **Infinite operation**: Neither loop ever runs out of work

### The Feedback Loop

```
Watcher tests app → finds console error
  → Creates Linear task "Fix undefined error in UserCard"

Builder queries Linear → gets highest priority task
  → Implements fix → Tests → Commits → Marks task Done

Watcher tests again → error gone → finds "Loading state missing"
  → Creates new task

Builder implements loading state...

Watcher thinks "Should add caching for performance"
  → Creates improvement task

Builder implements caching...

Watcher discovers "New feature opportunity: batch operations"
  → Creates new Epic with subtasks

... continues indefinitely
```

---

## Technical Architecture

### Terminal 1: Watcher Loop

```bash
while :; do
  cat ralph-dual/watcher.md | claude --dangerously-skip-permissions --print
  sleep 30  # Optional: rate limiting
done
```

**Watcher responsibilities:**
- Test the application continuously (via Playwright MCP)
- Identify bugs, UX issues, missing features
- Create tasks in Linear (via Linear MCP)
- Close browser at end of every session (prevent resource leaks)

**Watcher does NOT:**
- Write application code
- Commit to git
- Modify source files

### Terminal 2: Builder Loop

```bash
while :; do
  cat ralph-dual/builder.md | claude --dangerously-skip-permissions --print
done
```

**Builder responsibilities:**
- Read ralph-dual/epic-guidance.json for context
- Query Linear for ONE highest-priority unblocked task (two-stage query)
- Implement the task
- Run tests (backpressure)
- Commit changes
- Update Linear task status → Done
- Document learnings in ralph-dual/progress.txt

**Builder does NOT:**
- Create new tasks (only prerequisite tasks when blocked)
- Test the full application
- Decide what to work on (Linear decides)

### Coordination Mechanism

**Via Linear task states:**
- `Todo` → Available for Builder to pick
- `In Progress` → Builder currently working
- `Done` → Complete
- `Backlog` → Blocked or needs clarification

**Via ralph-dual/epic-guidance.json:**
- Human configures once (Linear IDs, conventions, docs)
- Both agents read for context
- Stays small (< 50 lines)

**Via ralph-dual/watcher-state.json:**
- Watcher updates with current phase, epic, testing progress
- Builder does not use this file

**Via ralph-dual/progress.txt (File Mode - default):**
- Both agents curate (not append-only)
- Max 20 Codebase Patterns, max 10 Recent Sessions
- Keeps context small for future iterations

**Via Recall (optional enhancement):**
- Semantic search instead of reading entire file
- Confidence scoring improves pattern quality over time
- Team sharing via Engram sync
- Configure by adding `recallStore` to ralph-dual/epic-guidance.json
- See `docs/SETUP-RECALL.md` for setup

### Required MCP Servers

1. **Linear MCP** (required for both agents)
   - Setup: `/mcp add linear` in Claude Code, then authenticate with Linear API key
   - Create tasks/epics
   - Query tasks by state
   - Update task status

2. **Playwright MCP** (required for Watcher)
   - Setup: `/plugin add playwright` in Claude Code
   - Navigate application
   - Interact with UI
   - Capture console errors
   - **Must call `browser_close` before exiting**

3. **Context7 MCP** (optional but recommended)
   - Fetch up-to-date API documentation
   - Prevents outdated code patterns

4. **Recall MCP** (optional enhancement)
   - Semantic knowledge search across sessions
   - Confidence scoring for pattern quality
   - Team knowledge sharing via Engram
   - Setup: See `docs/SETUP-RECALL.md`

---

## File Structure

### Single-Agent vs Dual-Agent Files

Dual-agent mode is a **fork of the original Ralph pattern**. It keeps the core philosophy:
- Bash loop spawns fresh Claude processes (no context accumulation)
- Files as memory (git, progress.txt, AGENTS.md)
- One task per session

But it replaces how tasks are managed:
- **Original**: `prd.json` (bounded task list, human-defined upfront)
- **Dual-agent**: Linear + `ralph-dual/watcher-state.json` (unlimited tasks, continuously discovered)

And splits one agent into two specialized roles:
- **Original**: Single agent finds AND fixes problems
- **Dual-agent**: Watcher finds problems → Builder fixes them

The two modes are **completely separate** - you use one OR the other, never both together.

**Single-Agent Mode** (original Ralph):
| File | Purpose |
|------|---------|
| `ralph.sh` | Bash loop |
| `prompt.md` / `CLAUDE.md` | Agent prompt |
| `prd.json` | Task list with `passes: true/false` status |
| `progress.txt` | Learnings |
| `AGENTS.md` | Patterns |

**Dual-Agent Mode** (this architecture):
| File | Purpose |
|------|---------|
| `ralph-dual/watcher.sh` + `ralph-dual/builder.sh` | Bash loops (one per agent) |
| `ralph-dual/watcher.ps1` + `ralph-dual/builder.ps1` | PowerShell loops (Windows) |
| `ralph-dual/watcher.md` + `ralph-dual/builder.md` | Agent prompts |
| `ralph-dual/watcher-state.json` | Watcher's phases, epics, testing progress |
| `ralph-dual/epic-guidance.json` | Linear config, conventions, docs path |
| Linear (via MCP) | Task list and status (replaces `prd.json`) |
| `ralph-dual/progress.txt` | Learnings (shared by both agents) |
| `ralph-dual/AGENTS.md` | Patterns (shared by both agents) |

**Key difference:** Single-agent uses `prd.json` for tasks. Dual-agent uses Linear + `ralph-dual/watcher-state.json` instead - `prd.json` is not used at all.

### Dual-Agent Repository Structure

```
ralph/
├── ralph-dual/                        # Dual-agent mode files
│   ├── watcher.md                     # Watcher prompt (phase-based workflow)
│   ├── builder.md                     # Builder prompt (one task per session)
│   ├── watcher.sh                     # Watcher bash loop
│   ├── watcher.ps1                    # Watcher PowerShell loop
│   ├── builder.sh                     # Builder bash loop
│   ├── builder.ps1                    # Builder PowerShell loop
│   ├── AGENTS.md                      # Operational patterns
│   ├── epic-guidance.json             # Linear config + project context (gitignored)
│   ├── epic-guidance.json.example     # Template (file mode - default)
│   ├── epic-guidance.recall.json.example  # Template (Recall mode - optional)
│   ├── watcher-state.json             # Watcher's phase and testing progress (gitignored)
│   ├── watcher-state.json.example     # Template for watcher state
│   └── progress.txt                   # Learnings - file mode (gitignored)
└── docs/
    ├── DUAL-AI-RALPH-ARCHITECTURE.md  # This document
    └── SETUP-RECALL.md                # Optional Recall enhancement guide
```

**Note:** Single-agent files (`ralph.sh`, `prompt.md`, `prd.json`) still exist in the repo for users who prefer bounded task lists. Dual-agent mode is an alternative, not a replacement.

### State File Separation

**epic-guidance.json** - Shared context (both agents read):
- Linear configuration (team ID, project ID, default labels)
- Current epic context (for Builder to understand what we're building)
- Global context (dev server URL, tech stack)
- Test credentials (for Watcher to access authenticated routes)

**watcher-state.json** - Watcher's private state:
- Current phase (discovery/testing/review/maintenance)
- Epic list with routes and testing status
- Testing progress (which route+category is next)
- Recent task IDs (for duplicate checking)

### epic-guidance.json

```json
{
  "linearConfig": {
    "teamId": "uuid",
    "projectId": "uuid",
    "projectName": "My Project",
    "defaultLabels": ["ralph-generated"]
  },
  "globalContext": {
    "devServerUrl": "http://localhost:3000"
  },
  "prd": "docs/PRD.md",
  "testCredentials": {
    "user": { "email": "...", "password": "..." },
    "admin": { "email": "...", "password": "..." }
  },
  "testing": {
    "viewports": ["mobile", "desktop"]
  },
  "conventions": [
    "Use shadcn/ui components",
    "Tailwind for styling",
    "tRPC for API routes"
  ],
  "docs": "docs/index.md"
}
```

**Field reference:**
- `prd` - Path to a PRD **markdown file** (NOT `prd.json`!) - see below
- `testCredentials` - Login credentials for authenticated testing
- `testing.viewports` - Screen sizes to test (`mobile`=375px, `tablet`=768px, `desktop`=1280px)
- `conventions` - Rules both agents check against (keep to 10-15 items)
- `docs` - Either an index file path OR object mapping topics to files
- `recallStore` - (Optional) Recall store ID to enable persistent knowledge search
- `recallConfig` - (Optional) Recall configuration (sourcePrefix, confidenceThreshold, queryLimit)

**The `prd` field (Product Vision):**

This is an **optional** path to a markdown PRD file (e.g., `docs/PRD.md`) that describes your product vision. It is completely unrelated to `prd.json` from single-agent mode.

Purpose:
- Gives Watcher context about what the product should be
- Helps Watcher suggest features that align with product goals
- Helps Watcher prioritize issues based on user impact

The Watcher reads this file during discovery and review phases to understand:
- What is this product?
- Who are the target users?
- What are the planned features and goals?

Without this file, Watcher still works but only finds bugs and issues - it won't proactively suggest features aligned with a product vision.

### watcher-state.json

```json
{
  "phase": "discovery|testing|review|maintenance",
  "epics": [
    {
      "linearId": "uuid-from-linear",
      "identifier": "LAT-123",
      "title": "Feature Area",
      "status": "pending|tested",
      "routes": ["/route1", "/route2"]
    }
  ],
  "currentEpic": "uuid-from-linear",
  "testingProgress": { "routeIndex": 0, "categoryIndex": 0 },
  "categories": ["functional", "errors", "uiux", "performance", "accessibility"],
  "recentTaskIds": [],
  "cycle": 1
}
```

**Note:** `linearId` must be the UUID from Linear (e.g., "32965e75-248f-..."), not the identifier (e.g., "LAT-123"). The UUID is required for `parentId` when creating subtasks.

---

## Implementation Details

### Watcher Phases

1. **discovery** - Check Linear for existing epics first, import them; only create new epics if none exist
2. **testing** - Test ONE route + ONE category per session
3. **review** - Epic fully tested, check for new epics in Linear, decide next epic or new cycle
4. **maintenance** - App healthy, curate progress.txt, wait for Builder

### Linear Sync Behavior

The Watcher syncs with Linear to avoid duplicates:
- **Discovery**: Queries Linear for existing epics before creating new ones
- **Review**: Checks for epics created outside Watcher (manually or by other tools)
- **Task creation**: Always searches for similar tasks before creating

This means you can:
- Start Watcher on a project with existing epics - they'll be imported
- Manually create epics in Linear - Watcher will pick them up in review phase
- Use Linear's UI alongside Watcher without conflicts

### Watcher Task Creation

**Required fields for every task:**
```json
{
  "title": "Clear, actionable title",
  "description": "What's wrong, how to fix",
  "team": "linearConfig.teamId",
  "project": "linearConfig.projectId",
  "labels": ["ralph-generated", "<domain>", "<type>"],
  "parentId": "currentEpic.linearId"
}
```

**Domain labels:** `Frontend` | `Backend` | `Security` (pick relevant)
**Type labels:** `Bug` | `Feature` | `Improvement` (pick one)

Without `project` and `parentId`, tasks won't appear in the project or under the epic!

### Watcher Quality Gate

Before creating a task (skip for console errors/crashes):
1. Is this REAL, not theoretical?
2. Would users NOTICE and CARE?
3. Worth Builder's time?

All yes → create task. Any no → skip.

**Principle:** Accuracy over activity. A quiet Watcher with a healthy app is success.

### Builder Two-Stage Query

To avoid loading 100+ task descriptions into context:

**Stage 1:** Get 5 candidates with minimal fields
```
list_issues: team, project, state="unstarted", limit=5
Fields: id, identifier, title, priority, blockedBy ONLY
```

**Stage 2:** Find first unblocked task
```
for each candidate:
  if blockedBy empty or all blockedBy Done → use this task
  else → skip
```

**Stage 3:** Get full details for THE chosen task
```
get_issue: id=[unblocked task], includeRelations=true
```

### Dependency Management

**Watcher:** Sets `blockedBy` when creating dependent tasks
**Builder:** Respects `blockedBy` - skips blocked tasks in query

If Builder discovers implicit block during implementation:
1. Find/create prerequisite task
2. Add `blockedBy` link to current task
3. Set current task to "Backlog"
4. Exit (don't pick another task)

### Resource Management

**Critical:** Watcher must call `browser_close` before exiting every session.

Unclosed browsers accumulate across sessions → fans spin → memory leak → system slowdown.

---

## Key Principles

### From Original Ralph

1. **Fresh context every iteration** - Kill the process, not just the conversation
2. **Files as memory** - Git, progress.txt, AGENTS.md
3. **One task per session** - If too big, split it
4. **Backpressure via tests** - Don't commit broken code
5. **Sit on the loop, not in it** - Engineer the environment, observe, tune

### For Dual-AI Extension

6. **Linear as task queue** - Not JSON (prevents bloat)
7. **Separation of concerns** - Watcher finds, Builder fixes
8. **Small context files** - Actively curated, not append-only
9. **Infinite work discovery** - Watcher always finds more
10. **Coordinate via state** - Linear states, not direct communication
11. **Close browser every session** - Prevent resource leaks
12. **Quality gate for tasks** - Accuracy over activity
13. **Pluggable knowledge backend** - File mode (default) or Recall (optional)

### Anti-Patterns to Avoid

- ❌ Plugin/hook approach (context accumulates)
- ❌ Single large JSON task file (context bloat)
- ❌ One agent doing everything (polluted context)
- ❌ Complex orchestration (simplicity wins)
- ❌ Tight coupling between agents (independence is key)
- ❌ Leaving browser open (resource leak)
- ❌ Creating tasks for theoretical issues (noise)

---

## Resources

### Original Ralph

- **Geoffrey Huntley's article**: https://ghuntley.com/ralph/
- **snarktank/ralph repo**: https://github.com/snarktank/ralph
- **Forked repo**: https://github.com/jarnowu/ralph

### Documentation & Playbooks

- **Ralph Playbook**: https://github.com/ClaytonFarr/ralph-playbook
- **ghuntley/how-to-ralph-wiggum**: https://github.com/ghuntley/how-to-ralph-wiggum
- **awesome-ralph**: https://github.com/snwfdhmp/awesome-ralph

### Tools

- **Claude Code**: https://docs.anthropic.com/en/docs/claude-code
- **Linear MCP**: Built into Claude Code
- **Playwright MCP**: Browser automation
- **Context7 MCP**: API documentation

### Key Quotes

> "Ralph is a Bash loop" - Geoffrey Huntley

> "The technique is deterministically bad in an undeterministic world"

> "It's not if it gets popped, it's when. And what is the blast radius?"

> "That's the beauty of Ralph - the context is cleared, you get a fresh agent"

---

## Quick Reference

### To Start Building

```bash
# Terminal 1 - Watcher
cd /path/to/project
./ralph-dual/watcher.sh

# Terminal 2 - Builder
cd /path/to/project
./ralph-dual/builder.sh
```

### To Check Status

```bash
# Check progress
cat progress.txt | tail -50

# See recent commits
git log --oneline -10

# Check current focus
cat ralph-dual/epic-guidance.json

# Check watcher state
cat ralph-dual/watcher-state.json
```

### To Stop

```bash
# Ctrl+C in each terminal
# Or kill the bash processes
```

### To Reset

```bash
# Revert uncommitted changes
git reset --hard

# Clear progress (optional)
> ralph-dual/progress.txt

# Reset watcher state
cp ralph-dual/watcher-state.json.example ralph-dual/watcher-state.json

# Edit ralph-dual/epic-guidance.json manually
```

---

*This document should be provided to any AI assistant continuing work on this project. It contains complete context for understanding and implementing the dual-AI Ralph loop architecture.*
