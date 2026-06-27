#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# hatch_twin.sh — hatch a LOCAL LIVING TWIN of this organism.
#
# An organism has two bodies:
#   • the STATIC genome — the published GitHub repo, served as raw.githubusercontent
#     data. It does not run; it is the source of truth.
#   • the LIVING twin   — a running brainstem instance, hatched from that genome
#     into the global brainstem home (~/.brainstem/twins/<repo>/), on its own port.
#
# This is the runtime counterpart of speciate.sh: speciate.sh hatches a new static
# genome (identity split on GitHub); hatch_twin.sh hatches the living twin of an
# existing genome. The twin runs the organism's OWN engine, alongside — never
# replacing — the global brainstem.
#
# Usage:
#   ./hatch_twin.sh [--port N] [--name NAME] [--no-launch] [-h]
#
#   --port N     Port for the twin (default: first free at/above 7072)
#   --name NAME  Twin directory name under ~/.brainstem/twins (default: repo name)
#   --no-launch  Build the twin loadout but do not start the server
#   -h, --help   Show this help
#
# Reads identity from rappid.json (the static genome it mirrors). Requires git,
# python3, and a global brainstem home with a venv (~/.brainstem/venv).
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; BLUE=$'\033[0;34m'; DIM=$'\033[2m'; NC=$'\033[0m'
ok()   { printf '%s✓%s %s\n' "$GREEN" "$NC" "$*"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$NC" "$*"; }
die()  { printf '%s✗ %s%s\n' "$RED" "$*" "$NC" >&2; exit 1; }
hr()   { printf '%s────────────────────────────────────────────────────────%s\n' "$DIM" "$NC"; }

PORT="" TWIN_NAME="" LAUNCH=1
while [ $# -gt 0 ]; do
  case "$1" in
    --port) PORT="${2:-}"; shift 2;;
    --name) TWIN_NAME="${2:-}"; shift 2;;
    --no-launch) LAUNCH=0; shift;;
    -h|--help) sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) die "Unknown argument: $1 (try --help)";;
  esac
done

command -v git     >/dev/null 2>&1 || die "git is required"
command -v python3 >/dev/null 2>&1 || die "python3 is required"
git rev-parse --show-toplevel >/dev/null 2>&1 || die "not inside a git repository"
ROOT="$(git rev-parse --show-toplevel)"
RB="$ROOT/rapp_brainstem"
[ -d "$RB" ] || die "no rapp_brainstem/ in this repo — nothing to hatch"
[ -f "$ROOT/rappid.json" ] || die "no rappid.json — run ./speciate.sh first to establish identity"

BRAINSTEM_HOME="${BRAINSTEM_HOME:-$HOME/.brainstem}"
VENV_PY="$BRAINSTEM_HOME/venv/bin/python"
GLOBAL_ENGINE="$BRAINSTEM_HOME/src/rapp_brainstem"   # source of shared auth
[ -x "$VENV_PY" ] || die "global brainstem venv not found at $VENV_PY — install the brainstem first"

# ── identity from the static genome ───────────────────────────────────────────
read_id() { python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["identity"].get(sys.argv[2],""))' "$ROOT/rappid.json" "$1"; }
OWNER="$(read_id owner)"; REPO="$(read_id repo)"; BRANCH="$(read_id branch)"
CLONE_URL="$(read_id clone_url)"; RAW_BASE="$(read_id raw_base)"; PAGES="$(read_id github_pages)"
[ -n "$REPO" ] || die "could not read identity.repo from rappid.json"
SRC_COMMIT="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

TWIN_NAME="${TWIN_NAME:-$REPO}"
TWIN_DIR="$BRAINSTEM_HOME/twins/$TWIN_NAME"

# ── pick a free port ──────────────────────────────────────────────────────────
port_busy() { lsof -iTCP:"$1" -sTCP:LISTEN -n >/dev/null 2>&1; }
if [ -z "$PORT" ]; then
  PORT=7072; while port_busy "$PORT"; do PORT=$((PORT + 1)); done
fi

hr
printf '%sHatching local living twin%s\n' "$BLUE" "$NC"
printf '  organism        %s%s/%s%s\n' "$GREEN" "$OWNER" "$REPO" "$NC"
printf '  static genome   %s\n' "$RAW_BASE"
printf '  twin dir        %s\n' "${TWIN_DIR/#$HOME/~}"
printf '  port            %s\n' "$PORT"
hr

# ── stop a previous twin of the same name, if running ─────────────────────────
if [ -f "$TWIN_DIR/twin.pid" ]; then
  oldpid="$(cat "$TWIN_DIR/twin.pid" 2>/dev/null || true)"
  if [ -n "$oldpid" ] && kill -0 "$oldpid" 2>/dev/null; then
    kill "$oldpid" 2>/dev/null && ok "stopped previous twin (pid $oldpid)" && sleep 1
  fi
fi

# ── build the twin loadout: a full copy of the organism's living genome ───────
mkdir -p "$TWIN_DIR"
# copy the rapp_brainstem genome, then strip what must not run / be stale
( cd "$RB" && tar cf - . ) | ( cd "$TWIN_DIR" && tar xf - )
rm -rf "$TWIN_DIR/agents/experimental" 2>/dev/null || true
find "$TWIN_DIR" -type d -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null || true
rm -f "$TWIN_DIR/.env" 2>/dev/null || true
[ -f "$RB/.env.example" ] && cp "$RB/.env.example" "$TWIN_DIR/.env"
# stamp identity/lineage provenance at the twin root
cp "$ROOT/rappid.json" "$TWIN_DIR/rappid.json" 2>/dev/null || true
[ -f "$ROOT/LINEAGE.md" ] && cp "$ROOT/LINEAGE.md" "$TWIN_DIR/LINEAGE.md"
ok "copied living genome into the twin"

# ── share the global brainstem's Copilot auth so the twin can think ───────────
authed=0
for a in .copilot_token .copilot_session; do
  if [ -f "$GLOBAL_ENGINE/$a" ]; then cp "$GLOBAL_ENGINE/$a" "$TWIN_DIR/$a" && authed=1; fi
done
if [ "$authed" = 1 ]; then ok "shared Copilot auth from the global brainstem"
else warn "no shared token found — the twin will fall back to 'gh auth token' / device login"; fi

# ── write the twin marker: the living <-> static link ─────────────────────────
OWNER="$OWNER" REPO="$REPO" BRANCH="$BRANCH" CLONE_URL="$CLONE_URL" RAW_BASE="$RAW_BASE" \
PAGES="$PAGES" SRC_COMMIT="$SRC_COMMIT" STAMP="$STAMP" PORT="$PORT" TWIN_DIR="$TWIN_DIR" \
VENV_PY="$VENV_PY" python3 - <<'PY'
import json, os
m = {
  "schema": "rappid-twin/v1",
  "kind": "local-living-twin",
  "organism": os.environ["REPO"],
  "identity": {"owner": os.environ["OWNER"], "repo": os.environ["REPO"], "branch": os.environ["BRANCH"]},
  # the published counterpart this living twin mirrors:
  "static_genome": {
    "clone_url": os.environ["CLONE_URL"],
    "raw_base": os.environ["RAW_BASE"],
    "github_pages": os.environ["PAGES"],
    "source_commit": os.environ["SRC_COMMIT"],
  },
  "runtime": {
    "engine": "own",                       # runs the organism's own brainstem.py
    "twin_dir": os.environ["TWIN_DIR"],
    "host": f"http://localhost:{os.environ['PORT']}",
    "port": int(os.environ["PORT"]),
    "venv_python": os.environ["VENV_PY"],
  },
  "hatched_at": os.environ["STAMP"],
  "tool": "hatch_twin.sh",
}
with open(os.path.join(os.environ["TWIN_DIR"], "twin.json"), "w") as fh:
    json.dump(m, fh, indent=2); fh.write("\n")
PY
ok "wrote twin.json (living ↔ static link)"

if [ "$LAUNCH" = 0 ]; then
  hr; ok "twin built at ${TWIN_DIR/#$HOME/~} (not launched — --no-launch)"; exit 0
fi

# ── launch the twin's own engine, detached, on its port ───────────────────────
cd "$TWIN_DIR"
PORT="$PORT" nohup "$VENV_PY" brainstem.py </dev/null >"$TWIN_DIR/twin.log" 2>&1 &
TWIN_PID=$!
echo "$TWIN_PID" > "$TWIN_DIR/twin.pid"
disown "$TWIN_PID" 2>/dev/null || true

# ── wait for health ───────────────────────────────────────────────────────────
printf '  starting twin (pid %s)' "$TWIN_PID"
ready=0
for _ in $(seq 1 20); do
  if curl -s --max-time 2 "localhost:$PORT/health" >/dev/null 2>&1; then ready=1; break; fi
  if ! kill -0 "$TWIN_PID" 2>/dev/null; then break; fi
  printf '.'; sleep 1
done
printf '\n'
hr
if [ "$ready" = 1 ]; then
  ok "twin is LIVE → http://localhost:$PORT"
  printf '  %shealth:%s\n' "$DIM" "$NC"
  curl -s "localhost:$PORT/health" | python3 -m json.tool 2>/dev/null | sed 's/^/    /' || true
  printf '\n%sLocal living twin of %s/%s is running.%s\n' "$GREEN" "$OWNER" "$REPO" "$NC"
  printf '  static genome (GitHub): %s\n' "$RAW_BASE"
  printf '  living twin (local):    http://localhost:%s   %slog: %s/twin.log%s\n' "$PORT" "$DIM" "${TWIN_DIR/#$HOME/~}" "$NC"
  printf '  stop it:                kill %s%s%s\n' "$DIM" "$TWIN_PID" "$NC"
else
  warn "twin did not become healthy in time — inspect $TWIN_DIR/twin.log"
  tail -20 "$TWIN_DIR/twin.log" 2>/dev/null | sed 's/^/    /'
  exit 1
fi
