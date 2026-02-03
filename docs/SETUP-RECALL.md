# Setting Up Recall for Ralph Dual Mode

**Optional Enhancement** — Recall provides semantic search, confidence scoring, and team knowledge sharing for Ralph agents. If you prefer simplicity, skip this — `progress.txt` works great out of the box.

---

## What You Get

| Feature | File Mode (Default) | Recall Mode |
|---------|---------------------|-------------|
| Setup | Zero | One-time global setup |
| Storage | progress.txt (20 patterns max) | SQLite (unlimited) |
| Search | Read entire file | Semantic query (top N relevant) |
| Quality | Manual curation | Confidence scoring + feedback |
| Team Sharing | None | Engram sync (optional) |
| Context Usage | Higher (reads all) | Lower (selective queries) |

---

## When to Use Recall

**Use Recall if:**
- Long-running project (weeks/months)
- Team working on same codebase
- Expect 50+ patterns to accumulate
- Want cross-project knowledge sharing

**Stick with File Mode if:**
- Quick project (days)
- Solo developer
- Want zero setup
- Patterns stay under 50

---

## One-Time Global Setup

You only do this once per machine. Recall then works for all Ralph projects.

### Step 1: Install Recall

#### Option A: npm (All Platforms - Recommended)

Requires Node.js 18+. Always gets the latest version.

```bash
npm install -g @hyperengineering/recall
```

Verify:
```bash
recall version
```

#### Option B: Homebrew (macOS/Linux)

```bash
brew install hyperengineering/tap/recall
```

#### Verify Installation

```bash
recall version
```

### Step 2: Add Recall MCP Server

Add to your Claude Code MCP configuration.

#### Option A: One-liner (Recommended)

```bash
claude mcp add-json recall '{"type":"stdio","command":"recall","args":["mcp"],"env":{"RECALL_DEBUG":"false"}}' --scope user
```

#### Option B: Manual Configuration

**Find your settings file:**
- macOS/Linux: `~/.claude/settings.json`
- Windows: `C:\Users\<YourUsername>\.claude\settings.json`

**Add the recall server:**

```json
{
  "mcpServers": {
    "recall": {
      "command": "recall",
      "args": ["mcp"],
      "env": {
        "RECALL_DEBUG": "false"
      }
    }
  }
}
```

**If `recall` isn't found**, use the full path:

```json
// npm global install (most common)
"command": "C:\\Users\\<YourUsername>\\AppData\\Roaming\\npm\\recall.cmd"

// Or manual install location
"command": "C:\\Program Files\\recall\\recall.exe"
```

**Restart Claude Code** completely (not just reload) to load the MCP server.

### Step 3: Verify MCP Connection

In Claude Code:
```
/mcp
```

You should see `recall` listed with tools:
- `recall_query`
- `recall_record`
- `recall_feedback`
- `recall_sync`
- `recall_store_list`
- `recall_store_info`

---

## Per-Project Setup

For each Ralph project that wants Recall:

### Step 1: Create Project Store

```bash
recall store create ralph/my-project --description "Knowledge base for My Project"
```

**Store naming convention:**
```
ralph/[project-name]           # Project-specific
ralph/[org]/[project-name]     # Team/org scoped
```

### Step 2: Configure epic-guidance.json

Add the `recallStore` field:

```json
{
  "linearConfig": {
    "teamId": "...",
    "projectId": "..."
  },

  "recallStore": "ralph/my-project",
  "recallConfig": {
    "sourcePrefix": "ralph",
    "confidenceThreshold": 0.4,
    "queryLimit": 5
  }
}
```

**Configuration options:**

| Field | Default | Description |
|-------|---------|-------------|
| `recallStore` | (none) | Store ID. If omitted, uses file mode. |
| `recallConfig.sourcePrefix` | `"ralph"` | Prefix for source IDs (e.g., `ralph-watcher`) |
| `recallConfig.confidenceThreshold` | `0.4` | Min confidence for query results |
| `recallConfig.queryLimit` | `5` | Max results per query |

### Step 3: Run the Loops

No changes needed — agents auto-detect Recall mode from config:

```bash
# Terminal 1
./watcher.ps1   # or ./watcher.sh

# Terminal 2
./builder.ps1   # or ./builder.sh
```

---

## How Agents Use Recall

### Builder Agent

**Before implementing (Step 4):**
```
recall_query "authentication middleware patterns" --store ralph/my-project --k 5
```

**After completing task (Step 9):**
```
recall_record \
  --content "Use { credentials: 'include' } with fetch for cookie auth" \
  --category IMPLEMENTATION_FRICTION \
  --store ralph/my-project
```

**Feedback on patterns used:**
```
recall_feedback --helpful L1 L3 --incorrect L2
```

### Watcher Agent

**Before testing route:**
```
recall_query "/admin authentication issues" --store ralph/my-project --k 3
```

**After discovering edge case:**
```
recall_record \
  --content "Admin routes return 401 if role check fails before auth check" \
  --category EDGE_CASE_DISCOVERY \
  --store ralph/my-project
```

**During maintenance phase:**
```
recall_feedback --helpful L1 --not-relevant L2 L3
```

---

## Category Reference

Use these Recall categories for different insight types:

| Category | Agent | Use For |
|----------|-------|---------|
| `EDGE_CASE_DISCOVERY` | Watcher | Unexpected behaviors, corner cases |
| `TESTING_STRATEGY` | Watcher | Effective testing approaches |
| `INTERFACE_LESSON` | Watcher | UI/UX patterns, accessibility |
| `PERFORMANCE_INSIGHT` | Watcher | Speed, rendering observations |
| `IMPLEMENTATION_FRICTION` | Builder | Gotchas, unexpected blockers |
| `PATTERN_OUTCOME` | Builder | What worked, what didn't |
| `DEPENDENCY_BEHAVIOR` | Builder | Library quirks, API behaviors |
| `ARCHITECTURAL_DECISION` | Builder | Design choices, rationale |

---

## Confidence Scoring

Recall tracks pattern quality automatically:

| Action | Confidence Change |
|--------|-------------------|
| Initial record | 0.5 (baseline) |
| `--helpful` feedback | +0.08 |
| `--incorrect` feedback | -0.15 |
| `--not-relevant` feedback | No change |

Over time:
- Good patterns rise to 0.7-1.0
- Bad patterns sink below threshold
- Irrelevant patterns stay neutral (context mismatch, not quality issue)

**Query with threshold:**
```
recall_query "topic" --confidence 0.6 --store ralph/my-project
```

---

## Multi-Agent Future-Proofing

The store structure supports adding more agents later:

```
ralph/my-project          # All agents share this store
```

Source IDs distinguish contributors:
```
RECALL_SOURCE_ID=ralph-watcher
RECALL_SOURCE_ID=ralph-builder
RECALL_SOURCE_ID=ralph-reviewer    # Future agent
RECALL_SOURCE_ID=ralph-security    # Future agent
```

**Feedback discipline:** Only rate patterns you actually tried to use:
- ✅ Builder marks implementation pattern helpful after using it
- ❌ Builder marks testing pattern not-relevant (wrong — just don't rate it)

---

## Optional: Team Sharing with Engram

Share knowledge across team members or machines.

### Setup Engram

1. Get Engram credentials from your team admin (or self-host)
2. Set environment variables:

```bash
export ENGRAM_URL="https://engram.yourteam.com"
export ENGRAM_API_KEY="your-api-key"
```

Or add to MCP config:

```json
{
  "mcpServers": {
    "recall": {
      "command": "recall",
      "args": ["mcp"],
      "env": {
        "ENGRAM_URL": "https://engram.yourteam.com",
        "ENGRAM_API_KEY": "your-api-key"
      }
    }
  }
}
```

### Sync Commands

```bash
# Pull team knowledge
recall sync --direction pull --store ralph/my-project

# Push your discoveries
recall sync --direction push --store ralph/my-project

# Bidirectional sync
recall sync --store ralph/my-project
```

Agents can also sync via MCP:
```
recall_sync --direction both --store ralph/my-project
```

---

## Troubleshooting

### "recall: command not found" / "not recognized"

**If installed via npm:**
```bash
# Check npm global bin location
npm bin -g

# Verify recall is there
npm list -g @hyperengineering/recall

# Reinstall if needed
npm install -g @hyperengineering/recall
```

**Windows (manual install):**
```powershell
# Check if recall is in PATH
where.exe recall

# If not found, verify it exists and add to PATH
```

**macOS/Linux:**
```bash
# Check installation
which recall

# If using Homebrew
brew list recall
```

### MCP Server Not Loading

1. Check settings.json syntax (valid JSON?)
2. Restart Claude Code completely
3. Check `/mcp` output for errors

### Queries Return Empty

- Store might be empty (normal for new projects)
- Confidence threshold too high (try `--confidence 0.3`)
- Check store name matches config

### High Memory Usage

SQLite databases stay small. If memory issues:
```bash
# Check database size
ls -lh ~/.recall/stores/*/lore.db

# Vacuum if needed
recall store vacuum ralph/my-project
```

---

## Switching Between Modes

### File → Recall

1. Set up Recall (this guide)
2. Add `recallStore` to epic-guidance.json
3. Optionally import existing patterns:
   ```bash
   # Manual: read progress.txt, record key patterns to Recall
   ```

### Recall → File

1. Remove `recallStore` from epic-guidance.json
2. Agents automatically use progress.txt
3. Recall data persists (can switch back anytime)

---

## Quick Reference

```bash
# Create store
recall store create ralph/my-project

# Check store stats
recall store info ralph/my-project

# Manual query (testing)
recall query "authentication" --store ralph/my-project

# Manual record (testing)
recall record --content "Test insight" --category PATTERN_OUTCOME --store ralph/my-project

# List all stores
recall store list
```

**Config template:** See `epic-guidance.recall.json.example`

**Latest release:** https://github.com/hyperengineering/recall/releases/latest

---

*For more details, see the [Recall documentation](https://github.com/hyperengineering/recall).*
