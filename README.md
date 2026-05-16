# cc-token-optimizer

Audit and reduce your Claude Code token costs.

## The Problem

Every MCP server you enable injects its full tool schema into your session's system prompt — billed on every API call. A single heavy MCP like playwright or pencil can add 15,000–40,000 tokens. With 5 MCPs running, you're paying for 50,000+ tokens of tool definitions you probably never use.

The system prompt is where 80–90% of token waste hides. But Claude Code doesn't show you this number anywhere in the UI.

## What This Does

1. **Diagnose** — Reads your session JSONL to show the real `cache_creation_input_tokens` (actual system prompt size)
2. **Audit** — Scans all MCP config files and lists what's enabled
3. **Fix** — Removes unused MCPs, verifies the saving
4. **RTK integration** — Guides setup of [RTK](https://github.com/colerafiz/rtk) for tool output compression (60–90% savings)

## Install

```bash
# Copy skill to Claude Code
mkdir -p ~/.claude/skills/cc-token-audit
cp skills/cc-token-audit/SKILL.md ~/.claude/skills/cc-token-audit/

# Or one-liner (after cloning)
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/cc-token-optimizer/main/scripts/install.sh | bash
```

## Usage

In any Claude Code session:

```
/cc-token-audit
```

Or just ask Claude naturally:
> "run a token audit on my current setup"

## What You'll See

```
=== Token Usage (latest session) ===
cache_creation_input_tokens: 56,656   ← system prompt (billed every new session)
cache_read_input_tokens: 0
input_tokens: 3

=== MCPs in ~/.claude.json ===
  - chrome
  - feishu
  - pencil         ← ~12,000 tokens
  - playwright     ← ~18,000 tokens
  - qveris         ← ~10,000 tokens
  - zai-mcp-server ← ~14,000 tokens

Recommendation: Remove 4 unused MCPs → save ~54,000 tokens per session
```

## Expected Savings

| Before (5 heavy MCPs) | After (cleanup) | Saving |
|-----------------------|-----------------|--------|
| ~56,000 tokens | ~15,000 tokens | ~73% |

At Sonnet pricing ($3/M input tokens), a developer doing 20 new sessions/day saves ~$1.20/day → **~$440/year**.

## Token Cost Stack

Three layers of optimization:

| Layer | Tool | What It Saves |
|-------|------|--------------|
| System prompt | This skill | MCP schema bloat (per-session) |
| Tool outputs | [RTK](https://github.com/colerafiz/rtk) | git/grep/find output (per-call) |
| Context window | CLAUDE.md discipline | Unnecessary file loads |

## License

MIT
