# Ralph

![Ralph](ralph.webp)

Ralph is an autonomous AI agent loop that runs AI coding tools ([Claude Code](https://docs.anthropic.com/en/docs/claude-code) or [Amp](https://ampcode.com)) repeatedly until all tasks are complete. Each iteration is a fresh instance with clean context.

**Two Modes:**
- **Single-Agent Mode** - Original Ralph with `prd.json` for bounded task lists (5-15 stories)
- **Dual-Agent Mode** - Watcher + Builder coordinated through Linear for continuous development

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

---

## Dual-Agent Mode: Autonomous Development

A continuous development system where specialized AI agents run independently, coordinating through a task queue to discover issues, plan enhancements, and implement fixes indefinitely.

### The Agents

| Agent | Role |
|-------|------|
| **Watcher** | QA and planning agent that tests the running application, identifies real issues, and proposes new features and improvements |
| **Builder(s)** | Developer agent(s) that pick unblocked tasks, implement them, run quality checks, commit, and mark complete |

### How They Coordinate

- **Linear serves as the task queue** — Watcher creates tasks under epics, Builders consume them
- **Task states and blockedBy relationships** prevent conflicts when multiple Builders run
- **Shared config** (`epic-guidance.json`) provides Linear credentials, test credentials, conventions, and docs paths
- **Process termination** after each session ensures fresh context
- **Knowledge backend** — Pluggable system for cross-session learning:
  - *File mode* (`progress.txt`) — Zero setup, manual curation, 20 patterns max
  - *[Recall mode](docs/SETUP-RECALL.md)* — Semantic search, confidence scoring, unlimited patterns, team sync

### Watcher Phases

1. **Discovery** — Explores the app (or reads a PRD), creates or imports epics with routes
2. **Testing** — Tests one route + one category per session (functional, errors, UX, performance, accessibility) across configured viewports
3. **Review** — Epic complete; checks for new epics, decides next epic or starts new cycle
4. **Maintenance** — App is healthy; waits for Builders to catch up, curates learnings

### Watcher Capabilities

- **Bug detection** — Console errors, broken functionality, error handling gaps
- **UX/UI issues** — Usability problems, accessibility violations, responsive breakages
- **Feature planning** — Proposes new features aligned with PRD vision
- **Improvements** — Suggests enhancements like caching, better loading states, performance optimizations

### Builder Workflow

1. Query Linear for highest-priority unblocked task (two-stage query to minimize context)
2. Mark "In Progress" → Investigate → Implement → Quality checks must pass → Commit
3. Mark "Done" with comment → Document learnings → Exit

### Quality Gates

- **Watcher**: "Is this REAL? Would users NOTICE and CARE? Worth Builder's time?" — accuracy over activity
- **Builder**: Tests must pass before committing — no broken code enters the repo

### What You Can Accomplish

- Point at a running application and let it continuously improve
- Provide a PRD for product vision — Watcher uses it to plan features, not just find bugs
- Scale by running multiple Builders against the same queue
- Works with existing Linear epics — Watcher imports rather than duplicates
- Runs indefinitely — cycles through testing, discovers new work, proposes enhancements
- **With Recall enabled:**
  - Agents query only relevant patterns (keyword search, semantic with Engram)
  - Good patterns gain confidence over time, bad ones fade
  - Share learnings across team members via Engram sync
  - Knowledge persists and improves across projects

### Key Principles

- **Fresh context every session** — process terminates, files are the only memory
- **Separation of concerns** — Watcher finds and plans, Builders implement
- **One task per Builder session** — keeps implementation focused
- **Linear as scalable queue** — avoids JSON bloat, supports 100+ tasks
- **Pluggable knowledge backend** — start simple with files, upgrade to Recall for persistent search

---

[Read my in-depth article on how I use Ralph](https://x.com/ryancarson/status/2008548371712135632)

## Prerequisites

- One of the following AI coding tools installed and authenticated:
  - [Amp CLI](https://ampcode.com) (default)
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (`npm install -g @anthropic-ai/claude-code`)
- `jq` installed (`brew install jq` on macOS, `choco install jq` on Windows)
- A git repository for your project

**For Dual-Agent Mode (additional requirements):**
- [Linear](https://linear.app) account with API access - add the Linear MCP server to Claude Code (`/mcp add linear`)
- [Playwright MCP](https://github.com/anthropics/claude-code-plugins) for browser testing - enable via `/plugin add playwright`

## Setup

### Option 1: Copy to your project

Copy the ralph files into your project:

```bash
# From your project root
mkdir -p scripts/ralph
cp /path/to/ralph/ralph.sh scripts/ralph/

# Copy the prompt template for your AI tool of choice:
cp /path/to/ralph/prompt.md scripts/ralph/prompt.md    # For Amp
# OR
cp /path/to/ralph/CLAUDE.md scripts/ralph/CLAUDE.md    # For Claude Code

chmod +x scripts/ralph/ralph.sh
```

### Option 2: Install skills globally (Amp)

Copy the skills to your Amp or Claude config for use across all projects:

For AMP
```bash
cp -r skills/prd ~/.config/amp/skills/
cp -r skills/ralph ~/.config/amp/skills/
```

For Claude Code (manual)
```bash
cp -r skills/prd ~/.claude/skills/
cp -r skills/ralph ~/.claude/skills/
```

### Option 3: Use as Claude Code Marketplace

Add the Ralph marketplace to Claude Code:

```bash
/plugin marketplace add snarktank/ralph
```

Then install the skills:

```bash
/plugin install ralph-skills@ralph-marketplace
```

Available skills after installation:
- `/prd` - Generate Product Requirements Documents
- `/ralph` - Convert PRDs to prd.json format

Skills are automatically invoked when you ask Claude to:
- "create a prd", "write prd for", "plan this feature"
- "convert this prd", "turn into ralph format", "create prd.json"

### Configure Amp auto-handoff (recommended)

Add to `~/.config/amp/settings.json`:

```json
{
  "amp.experimental.autoHandoff": { "context": 90 }
}
```

This enables automatic handoff when context fills up, allowing Ralph to handle large stories that exceed a single context window.

## Workflow

### 1. Create a PRD

Use the PRD skill to generate a detailed requirements document:

```
Load the prd skill and create a PRD for [your feature description]
```

Answer the clarifying questions. The skill saves output to `tasks/prd-[feature-name].md`.

### 2. Convert PRD to Ralph format

Use the Ralph skill to convert the markdown PRD to JSON:

```
Load the ralph skill and convert tasks/prd-[feature-name].md to prd.json
```

This creates `prd.json` with user stories structured for autonomous execution.

### 3. Run Ralph

```bash
# Using Amp (default)
./scripts/ralph/ralph.sh [max_iterations]

# Using Claude Code
./scripts/ralph/ralph.sh --tool claude [max_iterations]
```

Default is 10 iterations. Use `--tool amp` or `--tool claude` to select your AI coding tool.

Ralph will:
1. Create a feature branch (from PRD `branchName`)
2. Pick the highest priority story where `passes: false`
3. Implement that single story
4. Run quality checks (typecheck, tests)
5. Commit if checks pass
6. Update `prd.json` to mark story as `passes: true`
7. Append learnings to `progress.txt`
8. Repeat until all stories pass or max iterations reached

## Key Files

| File | Purpose |
|------|---------|
| `ralph.sh` | The bash loop that spawns fresh AI instances (supports `--tool amp` or `--tool claude`) |
| `prompt.md` | Prompt template for Amp |
| `CLAUDE.md` | Prompt template for Claude Code |
| `prd.json` | User stories with `passes` status (the task list) |
| `prd.json.example` | Example PRD format for reference |
| `progress.txt` | Curated learnings (max 20 patterns, 10 sessions) |
| `skills/prd/` | Skill for generating PRDs (works with Amp and Claude Code) |
| `skills/ralph/` | Skill for converting PRDs to JSON (works with Amp and Claude Code) |
| `.claude-plugin/` | Plugin manifest for Claude Code marketplace discovery |
| `flowchart/` | Interactive visualization of how Ralph works |

## Flowchart

[![Ralph Flowchart](ralph-flowchart.png)](https://snarktank.github.io/ralph/)

**[View Interactive Flowchart](https://snarktank.github.io/ralph/)** - Click through to see each step with animations.

The `flowchart/` directory contains the source code. To run locally:

```bash
cd flowchart
npm install
npm run dev
```

## Critical Concepts

### Each Iteration = Fresh Context

Each iteration spawns a **new AI instance** (Amp or Claude Code) with clean context. The only memory between iterations is:
- Git history (commits from previous iterations)
- `progress.txt` (learnings and context)
- `prd.json` (which stories are done)

### Small Tasks

Each PRD item should be small enough to complete in one context window. If a task is too big, the LLM runs out of context before finishing and produces poor code.

Right-sized stories:
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list

Too big (split these):
- "Build the entire dashboard"
- "Add authentication"
- "Refactor the API"

### AGENTS.md Updates Are Critical

After each iteration, Ralph updates the relevant `AGENTS.md` files with learnings. This is key because AI coding tools automatically read these files, so future iterations (and future human developers) benefit from discovered patterns, gotchas, and conventions.

Examples of what to add to AGENTS.md:
- Patterns discovered ("this codebase uses X for Y")
- Gotchas ("do not forget to update Z when changing W")
- Useful context ("the settings panel is in component X")

### Feedback Loops

Ralph only works if there are feedback loops:
- Typecheck catches type errors
- Tests verify behavior
- CI must stay green (broken code compounds across iterations)

### Browser Verification for UI Stories

Frontend stories must include "Verify in browser using dev-browser skill" in acceptance criteria. Ralph will use the dev-browser skill to navigate to the page, interact with the UI, and confirm changes work.

### Stop Condition

When all stories have `passes: true`, Ralph outputs `<promise>COMPLETE</promise>` and the loop exits.

## Debugging

Check current state:

```bash
# See which stories are done
cat prd.json | jq '.userStories[] | {id, title, passes}'

# See learnings from previous iterations
cat progress.txt

# Check git history
git log --oneline -10
```

## Customizing the Prompt

After copying `prompt.md` (for Amp) or `CLAUDE.md` (for Claude Code) to your project, customize it for your project:
- Add project-specific quality check commands
- Include codebase conventions
- Add common gotchas for your stack

## Archiving

Ralph automatically archives previous runs when you start a new feature (different `branchName`). Archives are saved to `archive/YYYY-MM-DD-feature-name/`.

## Dual-Agent Mode (Continuous Development)

For full application development beyond bounded PRDs, use dual-agent mode with Linear as the task queue.

### Why Dual-Agent?

Single-agent mode breaks down for full app development because:
- `prd.json` bloats with 100+ tasks, filling context on first read
- No mechanism for discovering new work (bugs, improvements)
- One agent both finding AND fixing problems leads to context pollution
- Work queue is finite - loop ends when tasks complete

Dual-agent mode solves this with:
- **Linear as task queue** - Scales to unlimited tasks
- **Separation of concerns** - Watcher finds, Builder fixes
- **Quality-first discovery** - Watcher finds REAL issues, not manufactured ones
- **Sustainable operation** - Maintenance phase when app is healthy

### Watcher Philosophy

The Watcher is a **quality guardian**, not a **task factory**.

```
FIND real issues     → Create task
THINK of improvement → Is it GENUINELY useful? → Yes → Create task
                                               → No  → Do nothing
NOTHING to improve   → Report "CLEAN" → That's success
```

**Watcher does NOT:**
- Manufacture issues to justify its existence
- Create tasks for theoretical edge cases
- Suggest features nobody needs
- Add documentation busywork

**Critical requirements:**
- Call `browser_close` before exiting every session (prevents resource leaks)
- Every task must include: `team`, `project`, `parentId` (epic UUID), `labels`
- Labels: `["ralph-generated", "<domain>", "<type>"]`
  - Domain: `Frontend` | `Backend` | `Security`
  - Type: `Bug` | `Feature` | `Improvement`

**Configuration options in `epic-guidance.json`:**

| Field | Purpose |
|-------|---------|
| `prd` | Path to PRD file for product vision (optional) |
| `testCredentials` | Login credentials for authenticated routes |
| `testing.viewports` | Screen sizes: `["mobile", "desktop"]` or `["mobile", "tablet", "desktop"]` |
| `conventions` | Array of rules to follow (keep to 10-15 items) |
| `docs` | Doc reference: `"docs/index.md"` OR `{ "auth": "docs/auth.md", ... }` |

### Architecture

| Agent | Script | Role |
|-------|--------|------|
| **Watcher** | `watcher.sh` | Tests app, finds bugs/issues, creates Linear tasks |
| **Builder** | `builder.sh` | Implements ONE Linear task per iteration |

Both share:
- Linear (task queue via MCP)
- `epic-guidance.json` (lightweight context)
- `progress.txt` (learnings log)
- Git repository

### Setup

1. **Configure Linear and project context:**
   ```bash
   cp epic-guidance.json.example epic-guidance.json
   # Edit epic-guidance.json:
   # - Set linearConfig.teamId and projectId
   # - Set globalContext.devServerUrl
   # - Set testCredentials for authenticated testing (optional)
   ```

2. **Initialize Watcher state:**
   ```bash
   cp watcher-state.json.example watcher-state.json
   # Starts in "discovery" phase
   # First Watcher session will explore app and create epics
   # No manual route configuration needed
   ```

3. **Start both agents:**
   ```bash
   # Terminal 1: Watcher (tests app, creates tasks)
   ./watcher.sh --project "My Project"

   # Terminal 2: Builder (implements tasks)
   ./builder.sh --project "My Project"
   ```

### Agent Scripts

```bash
# Watcher options
./watcher.sh                      # Use config from epic-guidance.json
./watcher.sh --sleep 120          # Test every 2 minutes
./watcher.sh --project "App"      # Override Linear project
./watcher.sh --max 100            # Run max 100 iterations

# Builder options
./builder.sh                      # Use config from epic-guidance.json
./builder.sh --sleep 10           # Check for tasks every 10s
./builder.sh --project "App"      # Override Linear project
./builder.sh --max 50             # Run max 50 iterations
```

### The Feedback Loop

```
WATCHER:
  Session 1: [discovery] Explores app → creates 3 epics in Linear
             Epic 1: Auth, Epic 2: Dashboard, Epic 3: Settings

  Session 2: [testing] Auth: /login + functional → finds bug → creates task
  Session 3: [testing] Auth: /login + errors → clean
  Session 4: [testing] Auth: /login + uiux → finds issue → creates task
  ...
  Session N: [testing] Auth: all routes+categories done
  Session N+1: [review] Auth complete → move to Dashboard epic
  ...
  Session M: [review] All epics done → CYCLE 2 begins → reset all epics

BUILDER (parallel):
  Session 1: Picks task LIN-123 → implements → commits → marks done
  Session 2: Picks task LIN-124 → implements → commits → marks done
  Session 3: No tasks → waits
  ...

... cycles continue, Watcher finds new issues each cycle as app evolves
```

### Key Files

| File | Purpose |
|------|---------|
| `watcher.sh` | Bash loop for Watcher agent |
| `builder.sh` | Bash loop for Builder agent |
| `watcher.md` | Watcher agent prompt (one route+category per session) |
| `builder.md` | Builder agent prompt (one task per session) |
| `epic-guidance.json` | Linear config and project context (gitignored) |
| `watcher-state.json` | Watcher's testing progress and coverage (gitignored) |
| `*.example` | Templates to copy and configure |

### Switching Projects

```bash
# Option 1: CLI flag
./watcher.sh --project "New Project"
./builder.sh --project "New Project"

# Option 2: Edit epic-guidance.json
# Change linearConfig.projectId and linearConfig.projectName
```

## Troubleshooting

### Single-Agent Mode

| Problem | Solution |
|---------|----------|
| `jq: command not found` | Install jq: `brew install jq` (macOS), `choco install jq` (Windows), `apt install jq` (Linux) |
| Ralph stops without completing | Check `progress.txt` for errors. Increase `max_iterations` if needed. |
| Commits fail quality checks | Fix the failing checks manually, then restart Ralph. |
| Wrong branch | Delete `prd.json` and `.last-branch`, then restart with correct PRD. |

### Dual-Agent Mode

| Problem | Solution |
|---------|----------|
| `Linear MCP not found` | Run `/mcp add linear` in Claude Code and authenticate. |
| Tasks not appearing in project | Ensure `project` and `parentId` are set in task creation. Check `epic-guidance.json` has correct IDs. |
| Watcher creates too many tasks | Quality gate not working - check `watcher.md` is being read. Reset `watcher-state.json` to discovery phase. |
| Builder picks blocked tasks | Verify `blockedBy` field is being checked. Update to latest `builder.md`. |
| Browser not closing | Playwright MCP issue - manually close browser. Check Watcher exits cleanly. |
| "NO_TASKS" but tasks exist | Check Linear project ID matches. Verify task state is "unstarted" not "backlog". |

### General

| Problem | Solution |
|---------|----------|
| Context filling up | Tasks are too large. Break into smaller stories/tasks. |
| Same mistakes repeating | Check `progress.txt` Codebase Patterns section. Add missing patterns. |
| Agent not following instructions | Verify prompt file exists and is readable. Check for syntax errors in JSON configs. |

## Versioning

This project uses [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes to prompt format, state file schema, or CLI arguments
- **MINOR**: New features, new agent capabilities, additional configuration options
- **PATCH**: Bug fixes, documentation updates, prompt improvements

Current version: See [releases](https://github.com/jarnowu/ralph/releases).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on submitting issues and pull requests.

## References

- [Geoffrey Huntley's Ralph article](https://ghuntley.com/ralph/)
- [Amp documentation](https://ampcode.com/manual)
- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code)
