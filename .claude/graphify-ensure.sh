#!/bin/bash
# Make sure graphify + its Claude skill exist in every fresh session, then refresh the graph.
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
if ! command -v graphify >/dev/null 2>&1; then
  (command -v uv >/dev/null 2>&1 && uv tool install graphifyy -q) \
    || pip install -q graphifyy >/dev/null 2>&1 \
    || pip install -q --user graphifyy >/dev/null 2>&1
  export PATH="$HOME/.local/bin:$PATH"
fi
command -v graphify >/dev/null 2>&1 || exit 0
[ -f "$HOME/.claude/skills/graphify/SKILL.md" ] || graphify install >/dev/null 2>&1
[ -f graphify-out/graph.json ] && graphify update . >/dev/null 2>&1
exit 0
