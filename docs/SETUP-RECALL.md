# Setting Up Recall for Ralph Dual Mode

**Optional Enhancement** — Recall provides semantic search, confidence scoring, and team knowledge sharing for Ralph agents. If you prefer simplicity, skip this — `progress.txt` works great out of the box.

**Important:** Recall requires Engram (a backend service) for search functionality. Without Engram, Recall can only store data but cannot query it. This guide covers both.

---

## What You Get

| Feature | File Mode (Default) | Recall + Engram |
|---------|---------------------|-----------------|
| Setup | Zero | Engram + Recall setup |
| Storage | progress.txt (20 patterns max) | SQLite (unlimited) |
| Search | Read entire file | Semantic search via embeddings |
| Quality | Manual curation | Confidence scoring + feedback |
| Team Sharing | None | Cross-machine sync |
| Context Usage | Higher (reads all) | Lower (selective queries) |

---

## When to Use Recall

**Use Recall + Engram if:**
- Long-running project (weeks/months)
- Team working on same codebase
- Expect 50+ patterns to accumulate
- Want semantic search (find conceptually related patterns)
- Have OpenAI API access (required for embeddings)

**Stick with File Mode if:**
- Quick project (days)
- Solo developer
- Want zero setup
- Don't have OpenAI API key
- Patterns stay under 50

---

## Architecture Overview

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Claude Agent   │────▶│     Recall      │────▶│     Engram      │
│  (via MCP)      │     │  (local client) │     │ (backend server)│
└─────────────────┘     └─────────────────┘     └─────────────────┘
                              │                        │
                              │                        ▼
                              │                 ┌─────────────────┐
                              │                 │   OpenAI API    │
                              │                 │  (embeddings)   │
                              ▼                 └─────────────────┘
                        ┌─────────────────┐
                        │  Local SQLite   │
                        │    (cache)      │
                        └─────────────────┘
```

- **Recall** — Local client that agents interact with via MCP
- **Engram** — Backend server that handles semantic search using OpenAI embeddings
- **Local SQLite** — Cache for offline access and sync

---

## Step 1: Set Up Engram (Backend Server)

Engram is required for Recall's query functionality.

### Prerequisites

- Docker installed
- OpenAI API key (for embeddings)

### Option A: Docker (Recommended)

```bash
# Create a directory for Engram data
mkdir -p ~/engram-data

# Run Engram
docker run -d \
  --name engram \
  -p 8080:8080 \
  -e OPENAI_API_KEY="sk-your-openai-api-key" \
  -e ENGRAM_API_KEY="your-secret-key-make-one-up" \
  -v ~/engram-data:/data \
  ghcr.io/hyperengineering/engram:latest
```

**Windows (PowerShell):**
```powershell
# Create directory
mkdir $env:USERPROFILE\engram-data

# Run Engram
docker run -d `
  --name engram `
  -p 8080:8080 `
  -e OPENAI_API_KEY="sk-your-openai-api-key" `
  -e ENGRAM_API_KEY="your-secret-key-make-one-up" `
  -v $env:USERPROFILE\engram-data:/data `
  ghcr.io/hyperengineering/engram:latest
```

**Environment variables:**
| Variable | Description |
|----------|-------------|
| `OPENAI_API_KEY` | Your OpenAI API key (required for embeddings) |
| `ENGRAM_API_KEY` | A secret you create for client authentication |

### Option B: Homebrew (macOS/Linux)

```bash
# Install
brew install hyperengineering/tap/engram

# Set environment variables
export OPENAI_API_KEY="sk-your-openai-api-key"
export ENGRAM_API_KEY="your-secret-key-make-one-up"

# Run
engram
```

### Verify Engram is Running

```bash
curl http://localhost:8080/api/v1/health
```

Should return: `{"status":"ok"}`

---

## Step 2: Install Recall (Client)

### Option A: npm (All Platforms - Recommended)

Requires Node.js 18+.

```bash
npm install -g @hyperengineering/recall
```

### Option B: Homebrew (macOS/Linux)

```bash
brew install hyperengineering/tap/recall
```

### Verify Installation

```bash
recall version
```

---

## Step 3: Configure Recall MCP Server

Add Recall to Claude Code with Engram connection.

### Option A: One-liner

**macOS/Linux:**
```bash
claude mcp add-json recall '{"type":"stdio","command":"recall","args":["mcp"],"env":{"ENGRAM_URL":"http://localhost:8080","ENGRAM_API_KEY":"your-secret-key-make-one-up"}}' --scope user
```

**Windows (PowerShell):**
```powershell
claude mcp add-json recall '{\"type\":\"stdio\",\"command\":\"recall\",\"args\":[\"mcp\"],\"env\":{\"ENGRAM_URL\":\"http://localhost:8080\",\"ENGRAM_API_KEY\":\"your-secret-key-make-one-up\"}}' --scope user
```

### Option B: Manual Configuration

Edit your Claude Code settings file:
- macOS/Linux: `~/.claude/settings.json`
- Windows: `C:\Users\<YourUsername>\.claude\settings.json`

```json
{
  "mcpServers": {
    "recall": {
      "command": "recall",
      "args": ["mcp"],
      "env": {
        "ENGRAM_URL": "http://localhost:8080",
        "ENGRAM_API_KEY": "your-secret-key-make-one-up"
      }
    }
  }
}
```

**Windows — if `recall` isn't found**, use full path:
```json
"command": "C:\\Users\\<YourUsername>\\AppData\\Roaming\\npm\\recall.cmd"
```

### Restart Claude Code

Completely restart Claude Code (not just reload) to load the MCP server.

### Verify MCP Connection

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

## Step 4: Per-Project Setup

For each Ralph project that wants Recall:

### Create Project Store

```bash
recall store create ralph/my-project --description "Knowledge base for My Project"
```

**Store naming convention:**
```
ralph/[project-name]           # Project-specific
ralph/[org]/[project-name]     # Team/org scoped
```

### Configure epic-guidance.json

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

### Run the Loops

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
- Irrelevant patterns stay neutral

---

## Managing Engram

### Start/Stop (Docker)

```bash
# Stop
docker stop engram

# Start
docker start engram

# View logs
docker logs engram

# Remove completely
docker rm -f engram
```

### Run on Startup

```bash
# Add restart policy
docker update --restart unless-stopped engram
```

### Remote/Team Engram

For team sharing, deploy Engram on a server accessible to all team members:

```bash
docker run -d \
  --name engram \
  -p 8080:8080 \
  -e OPENAI_API_KEY="sk-team-openai-key" \
  -e ENGRAM_API_KEY="team-shared-secret" \
  -v /var/engram-data:/data \
  ghcr.io/hyperengineering/engram:latest
```

Then configure team members' Recall:
```json
{
  "env": {
    "ENGRAM_URL": "http://your-server:8080",
    "ENGRAM_API_KEY": "team-shared-secret"
  }
}
```

---

## Troubleshooting

### "Recall is in offline mode" / Queries return empty

**Cause:** Recall can't connect to Engram.

**Fix:**
1. Check Engram is running: `curl http://localhost:8080/api/v1/health`
2. Check `ENGRAM_URL` in MCP config matches where Engram runs
3. Check `ENGRAM_API_KEY` matches between Recall and Engram
4. Restart Claude Code after config changes

### "recall: command not found"

```bash
# Check npm global bin
npm bin -g

# Verify installation
npm list -g @hyperengineering/recall

# Reinstall
npm install -g @hyperengineering/recall
```

### Engram container won't start

```bash
# Check logs
docker logs engram

# Common issues:
# - OPENAI_API_KEY not set or invalid
# - Port 8080 already in use (change with -p 8081:8080)
```

### MCP Server Not Loading

1. Check settings.json syntax (valid JSON?)
2. Restart Claude Code completely
3. Run `/mcp` and check for errors

---

## Quick Reference

```bash
# Engram (Docker)
docker run -d --name engram -p 8080:8080 \
  -e OPENAI_API_KEY="sk-..." -e ENGRAM_API_KEY="secret" \
  -v ~/engram-data:/data ghcr.io/hyperengineering/engram:latest

# Recall client
npm install -g @hyperengineering/recall
recall version

# Create store
recall store create ralph/my-project

# Test query
recall query "test" --store ralph/my-project

# Test record
recall record --content "Test" --category PATTERN_OUTCOME --store ralph/my-project

# Check Engram health
curl http://localhost:8080/api/v1/health
```

---

## Switching Between Modes

### File → Recall

1. Set up Engram (this guide)
2. Install Recall client
3. Configure MCP with Engram connection
4. Add `recallStore` to epic-guidance.json

### Recall → File

1. Remove `recallStore` from epic-guidance.json
2. Agents automatically use progress.txt
3. Recall data persists (can switch back anytime)
4. Engram can be stopped if not needed

---

**Config template:** See `epic-guidance.recall.json.example`

**Repositories:**
- Recall: https://github.com/hyperengineering/recall
- Engram: https://github.com/hyperengineering/engram
