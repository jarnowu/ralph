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
- prd.json or Linear (task status)
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
- epic-guidance.json (lightweight context file)
- Git repository (code + history)
- progress.txt (learnings log)

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
  cat watcher.md | claude --dangerously-skip-permissions --print
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
  cat builder.md | claude --dangerously-skip-permissions --print
done
```

**Builder responsibilities:**
- Read epic-guidance.json for context
- Query Linear for ONE highest-priority unblocked task (two-stage query)
- Implement the task
- Run tests (backpressure)
- Commit changes
- Update Linear task status → Done
- Document learnings in progress.txt

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

**Via epic-guidance.json:**
- Watcher updates with current epic focus
- Builder reads for implementation context
- Stays small (< 50 lines)

**Via progress.txt:**
- Both agents curate (not append-only)
- Max 20 Codebase Patterns, max 10 Recent Sessions
- Keeps context small for future iterations

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

---

## File Structure

### Repository Structure

```
ralph/
├── watcher.md              # Watcher prompt (phase-based workflow)
├── builder.md              # Builder prompt (one task per session)
├── watcher.sh              # Watcher bash loop
├── watcher.ps1             # Watcher PowerShell loop
├── builder.sh              # Builder bash loop
├── builder.ps1             # Builder PowerShell loop
├── epic-guidance.json      # Linear config + project context (both agents read)
├── watcher-state.json      # Watcher's phase and testing progress (Watcher only)
├── progress.txt            # Learnings (both agents curate)
├── AGENTS.md               # Operational patterns
├── README.md               # Documentation
├── *.example               # Templates for JSON files
└── docs/                   # Architecture documentation
```

### State File Separation

**epic-guidance.json** - Shared context (both agents read):
- Linear configuration (team ID, project ID, default labels)
- Current epic context (for Builder to understand what we're building)
- Global context (dev server URL, tech stack)

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
  "currentEpic": {
    "linearId": null,
    "title": "Current Focus",
    "approach": "Technical approach description"
  },
  "globalContext": {
    "projectPath": ".",
    "devServerUrl": "http://localhost:3000"
  }
}
```

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

1. **discovery** - Explore app, create epics in Linear with routes
2. **testing** - Test ONE route + ONE category per session
3. **review** - Epic fully tested, decide next epic or new cycle
4. **maintenance** - App healthy, curate progress.txt, wait for Builder

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
./watcher.sh

# Terminal 2 - Builder
cd /path/to/project
./builder.sh
```

### To Check Status

```bash
# Check progress
cat progress.txt | tail -50

# See recent commits
git log --oneline -10

# Check current focus
cat epic-guidance.json

# Check watcher state
cat watcher-state.json
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
> progress.txt

# Reset watcher state
cp watcher-state.json.example watcher-state.json

# Edit epic-guidance.json manually
```

---

*This document should be provided to any AI assistant continuing work on this project. It contains complete context for understanding and implementing the dual-AI Ralph loop architecture.*
