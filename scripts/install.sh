#!/usr/bin/env bash
# cc-token-optimizer installer
# Usage: curl -fsSL https://raw.githubusercontent.com/.../install.sh | bash

set -e

SKILL_DIR="${HOME}/.claude/skills/cc-token-audit"
REPO="https://raw.githubusercontent.com/YOUR_USERNAME/cc-token-optimizer/main"

echo "Installing cc-token-audit skill..."
mkdir -p "$SKILL_DIR"
curl -fsSL "$REPO/skills/cc-token-audit/SKILL.md" -o "$SKILL_DIR/SKILL.md"
echo "Installed to $SKILL_DIR"
echo ""
echo "Usage: /cc-token-audit"
echo "Or ask Claude: run a token audit"
