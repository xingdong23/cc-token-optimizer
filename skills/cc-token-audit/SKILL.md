---
name: cc-token-audit
description: Use when Claude Code sessions feel slow or expensive, when you want to measure actual system prompt size, when suspecting MCP servers are inflating token usage, or when setting up a new machine and want to baseline token costs.
---

# CC Token Audit

## Overview

Every MCP server you enable injects its full tool schema into every session's system prompt. A single heavy MCP (playwright, browser-use, pencil) can add 10,000–40,000 tokens — paid on every single API call. This skill measures the real cost and removes the waste.

**Core insight:** `cache_creation_input_tokens` in the session JSONL is the ground truth — it's the actual system prompt size billed on the first message of each session.

## What It Does

Three-phase workflow:

1. **Diagnose** — Read the latest session JSONL and show actual token usage
2. **Audit** — Scan all MCP config locations, count tool definitions per server
3. **Fix** — Remove unused MCPs and verify the saving in the next session

## Diagnosis: Read Actual Token Usage

```bash
# Find the latest session file for current project
PROJECT_DIR=$(pwd | sed 's|/|-|g' | sed 's|^|~/.claude/projects/|')
ls -t ~/.claude/projects/*$(basename $(pwd))*.jsonl 2>/dev/null | head -1
# or search all projects
ls -t ~/.claude/projects/*/*.jsonl 2>/dev/null | head -1
```

Then extract the first API call's usage:
```bash
grep -o '"usage":{[^}]*}' <SESSION_FILE> | head -1
```

**Reading the output:**
| Field | Meaning |
|-------|---------|
| `cache_creation_input_tokens` | System prompt size (first message) — this is what you're paying |
| `cache_read_input_tokens` | System prompt served from cache (subsequent messages — cheap) |
| `input_tokens` | User message tokens |

**Benchmarks:**
| System prompt size | Assessment |
|--------------------|------------|
| < 20,000 tokens | Lean — well optimized |
| 20,000–40,000 | Moderate — check for heavy MCPs |
| 40,000–80,000 | Heavy — significant MCPs injecting tool schemas |
| > 80,000 | Bloated — multiple large MCPs active |

## MCP Audit: Find What's Injecting Tokens

Scan all config locations in order:

```bash
# 1. Global user config (most common location)
cat ~/.claude.json | python3 -c "
import json,sys
d=json.load(sys.stdin)
mcps=d.get('mcpServers',{})
print(f'~/.claude.json: {len(mcps)} servers')
for k in mcps: print(f'  - {k}')
"

# 2. User settings
cat ~/.claude/settings.json | python3 -c "
import json,sys
d=json.load(sys.stdin)
mcps=d.get('mcpServers',{})
print(f'~/.claude/settings.json: {len(mcps)} servers')
for k in mcps: print(f'  - {k}')
" 2>/dev/null

# 3. Project settings
cat .claude/settings.json | python3 -c "
import json,sys
d=json.load(sys.stdin)
mcps=d.get('mcpServers',{})
print(f'.claude/settings.json: {len(mcps)} servers')
for k in mcps: print(f'  - {k}')
" 2>/dev/null
```

**Known heavy MCPs** (token cost estimates):
| MCP | Tool count | ~Token cost |
|-----|-----------|-------------|
| playwright / browser-use | 20–30 tools | ~15,000–25,000 |
| pencil / design tools | 10–15 tools | ~8,000–15,000 |
| zai-mcp-server | 15–25 tools | ~10,000–20,000 |
| qveris | 10–20 tools | ~8,000–15,000 |
| chrome / puppeteer | 15–25 tools | ~10,000–20,000 |

## Fix: Remove Unused MCPs

```bash
# Remove specific servers from ~/.claude.json
cat ~/.claude.json | python3 -c "
import json, sys
d = json.load(sys.stdin)
to_remove = {'chrome', 'pencil', 'playwright', 'qveris', 'zai-mcp-server'}
# customize: only remove servers you don't actually use
removed = [k for k in d.get('mcpServers', {}) if k in to_remove]
d['mcpServers'] = {k: v for k, v in d.get('mcpServers', {}).items() if k not in to_remove}
print('Removed:', removed)
print('Remaining:', list(d['mcpServers'].keys()))
with open('/Users/\$(whoami)/.claude.json', 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
"
```

**After removing:** Start a new session and re-run the diagnosis. The difference in `cache_creation_input_tokens` is your saving per session.

## RTK: Save Tokens on Tool Outputs

MCP schemas bloat the *system prompt*. RTK (Rust Token Killer) compresses *tool outputs* — git, grep, find, etc. — saving 60–90% on those results.

```bash
# Check if RTK is installed
rtk --version 2>/dev/null || echo "RTK not installed"

# If not installed: https://github.com/colerafiz/rtk
# Once installed, it rewrites commands via Claude Code hooks automatically
# No usage change needed — transparent proxy
```

## Monitor: Track Savings Over Time

```bash
# Check token usage across recent sessions
for f in $(ls -t ~/.claude/projects/$(pwd | sed 's|/|-|g' | sed 's|^-||')/*.jsonl 2>/dev/null | head -5); do
  tokens=$(grep -o '"cache_creation_input_tokens":[0-9]*' "$f" | head -1 | grep -o '[0-9]*')
  date=$(stat -f "%Sm" -t "%Y-%m-%d" "$f" 2>/dev/null || stat -c "%y" "$f" 2>/dev/null | cut -d' ' -f1)
  echo "$date  $(basename $f | cut -c1-8)  ${tokens:-unknown} tokens"
done
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Checking `settings.json` but not `~/.claude.json` | MCPs are usually in `~/.claude.json` — check both |
| Expecting immediate change | Changes apply to the *next* new session only |
| Removing MCPs you actually use | Keep MCPs you invoke regularly; remove idle ones |
| Using `input_tokens` as the metric | Use `cache_creation_input_tokens` — that's the system prompt |

## Quick Reference

```bash
# Full audit in one shot
LATEST=$(ls -t ~/.claude/projects/**/*.jsonl 2>/dev/null | head -1)
echo "=== Token Usage ===" && grep -o '"usage":{[^}]*}' "$LATEST" | head -1
echo "=== MCPs in ~/.claude.json ===" && cat ~/.claude.json | python3 -c "import json,sys; d=json.load(sys.stdin); [print(f'  {k}') for k in d.get('mcpServers',{})]"
echo "=== RTK ===" && (rtk --version 2>/dev/null || echo "not installed")
```
