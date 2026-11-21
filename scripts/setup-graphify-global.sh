#!/bin/bash
# Einmal-Setup (macOS/Linux): Graphify global aktiv + optional Craft Anything CLI.
# Aendert ~/.claude/settings.json und ~/.claude/CLAUDE.md per MERGE (Backup *.bak.<zeit>).
# Installiert KEIN MarkItDown (Tool aus dem TikTok-Video ist unbestaetigt).
set -u
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
CL="$HOME/.claude"; TS=$(date +%Y%m%d%H%M%S)
mkdir -p "$CL/hooks"

echo "== 1/4 Graphify installieren"
if ! command -v graphify >/dev/null 2>&1; then
  if command -v uv >/dev/null 2>&1; then uv tool install graphifyy
  elif command -v pipx >/dev/null 2>&1; then pipx install graphifyy
  else echo "FEHLER: weder uv noch pipx gefunden (brew install uv)"; exit 1; fi
fi
command -v graphify || { echo "FEHLER: graphify nicht im PATH"; exit 1; }
graphify install
ls -l "$CL/skills/graphify/SKILL.md" || { echo "FEHLER: SKILL.md fehlt"; exit 1; }

echo "== 2/4 Ensure-Skript"
cat > "$CL/hooks/graphify-ensure.sh" <<'EOF'
#!/bin/bash
# Installiert graphify + Skill falls fehlend (SessionStart). graphify wird ueber PATH gefunden.
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
if ! command -v graphify >/dev/null 2>&1; then
  (command -v uv >/dev/null 2>&1 && uv tool install graphifyy -q) \
    || (command -v pipx >/dev/null 2>&1 && pipx install graphifyy >/dev/null 2>&1) \
    || pip install -q --user graphifyy >/dev/null 2>&1
fi
command -v graphify >/dev/null 2>&1 || exit 0
[ -f "$HOME/.claude/skills/graphify/SKILL.md" ] || graphify install >/dev/null 2>&1
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null && [ -f graphify-out/graph.json ] && graphify update . >/dev/null 2>&1
exit 0
EOF
chmod +x "$CL/hooks/graphify-ensure.sh"

echo "== 3/4 settings.json mergen"
[ -f "$CL/settings.json" ] && cp "$CL/settings.json" "$CL/settings.json.bak.$TS"
python3 - "$CL/settings.json" <<'EOF'
import json, sys, os
p = sys.argv[1]
d = json.load(open(p)) if os.path.exists(p) and os.path.getsize(p) else {}
cmd = 'bash "$HOME/.claude/hooks/graphify-ensure.sh"'
ss = d.setdefault("hooks", {}).setdefault("SessionStart", [])
if not any(h.get("command") == cmd for e in ss for h in e.get("hooks", [])):
    ss.append({"matcher": "startup|resume", "hooks": [{"type": "command", "command": cmd, "timeout": 300}]})
json.dump(d, open(p, "w"), indent=2)
print("SessionStart-Hook gesetzt, Rest unveraendert")
EOF
python3 -c "import json;json.load(open('$CL/settings.json'));print('settings.json valide')"

[ -f "$CL/CLAUDE.md" ] && cp "$CL/CLAUDE.md" "$CL/CLAUDE.md.bak.$TS"
if ! grep -q "graphify is always on" "$CL/CLAUDE.md" 2>/dev/null; then
cat >> "$CL/CLAUDE.md" <<'EOF'

## graphify is always on
- Der graphify-Skill ist in jeder Session aktiv (Hook: ~/.claude/hooks/graphify-ensure.sh installiert ihn bei Bedarf).
- Bei Fragen zum Code: zuerst `graphify query "<frage>"`, wenn graphify-out/graph.json existiert; erst danach grep/Dateien lesen.
- Nach Codeaenderungen `graphify update .`. In neuen Projekten einmal `graphify claude install && graphify update .`.
EOF
fi
grep -n "graphify is always on" "$CL/CLAUDE.md"

echo "== 4/4 Craft Anything CLI (optional, Rust noetig, Build ~7 min)"
if command -v cargo >/dev/null 2>&1; then
  D=$(mktemp -d); git clone --depth 1 https://github.com/storytold/craft-anything "$D/ca" \
    && (cd "$D/ca" && cargo install --path apps/craft-anything-cli --locked) \
    && craft-anything-cli doctor | head -c 600; echo
else
  echo "cargo fehlt -> uebersprungen (brew install rustup && rustup default stable, Skript erneut starten)"
fi

echo "== Beweis"
uname -sm; whoami; command -v graphify craft-anything-cli; ls "$CL/skills/graphify"
