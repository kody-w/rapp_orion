#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# speciate.sh — RAPPID speciation tool
#
# Births a new RAPP organism off the current one. A "speciation" rewrites the
# organism's GATEWAY SELF-IDENTITY (the public installer repo it tells the world
# to clone / curl / open) so the new organism pulls from ITSELF, then records an
# immutable lineage event for traceability back to the common ancestor.
#
# What it MUTATES (the "self" genes):
#   - <owner>.github.io/<repo>        GitHub Pages host/path
#   - <owner>%2F<repo>                URL-encoded (e.g. the Deploy-to-Azure button)
#   - <owner>/<repo>                  github.com / raw / api / `gh --repo`
#   - bare <repo> token              prose, *.git URLs, test assertions
#
# What it PRESERVES (not "self"):
#   - Sibling organisms (CommunityRAPP, AI-Agent-Templates, RAR, …) declared in
#     rappid.json "siblings" — separate repos, carried forward untouched.
#   - Branding & anatomy ("RAPP", "brainstem", "~/.brainstem", component dirs).
#   - Binary assets (*.zip, images, fonts) — never opened.
#   - The speciation machinery itself (speciate.sh, RAPPID.md) — these hold the
#     genesis "grail" constant for ALL descendants and must never drift.
#
# It writes/updates:
#   - rappid.json   organism manifest: current identity + full ancestry chain
#   - LINEAGE.md    human-readable descent, generated from the manifest
#
# Usage:
#   ./speciate.sh [--owner <gh-owner>] [--repo <gh-repo>] [options]
#
# Identity is optional: when --owner/--repo are omitted they are derived from
# this repo's own `git remote origin`. That is what lets the bootstrap Action
# speciate with zero inputs, and what makes the grail (or an already-speciated
# organism) a safe no-op — its origin already equals its content identity.
#
# Run with --help for the full option list.
#
# Requires: bash (3.2+ ok), git, perl, python3 — all present on a stock macOS.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# The genesis ancestor. The very first split (before any rappid.json exists) is
# assumed to come from here. This constant is the same for every descendant.
GRAIL_OWNER="kody-w"
GRAIL_REPO="rapp-installer"

# Siblings seeded into the manifest on the first split (kept, never mutated).
DEFAULT_SIBLINGS_JSON='{"hippocampus":"kody-w/CommunityRAPP","agent_templates":"kody-w/AI-Agent-Templates","rar":"kody-w/RAR"}'

# Files that must never be identity-mutated (machinery + generated artifacts).
is_protected() {
  case "$1" in
    rappid.json|LINEAGE.md|speciate.sh|hatch_twin.sh|RAPPID.md|RAPPID-SPEC.md|.github/workflows/speciate.yml) return 0;;
    *) return 1;;
  esac
}

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; BLUE=$'\033[0;34m'; DIM=$'\033[2m'; NC=$'\033[0m'
say()  { printf '%s\n' "$*"; }
ok()   { printf '%s✓%s %s\n' "$GREEN" "$NC" "$*"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$NC" "$*"; }
die()  { printf '%s✗ %s%s\n' "$RED" "$*" "$NC" >&2; exit 1; }
hr()   { printf '%s────────────────────────────────────────────────────────%s\n' "$DIM" "$NC"; }

usage() {
  cat <<'EOF'
speciate.sh — birth a new RAPP organism off the current one

Usage:
  ./speciate.sh [--owner <gh-owner>] [--repo <gh-repo>] [options]

Identity (optional — derived from `git remote origin` when omitted):
  --owner OWNER     GitHub owner/org for this organism
  --repo  REPO      GitHub repo name for this organism

Options:
  --branch BRANCH   Default branch for raw/clone URLs   (default: detected/main)
  --from-owner O    Override detected parent owner       (default: manifest/grail)
  --from-repo  R    Override detected parent repo         (default: manifest/grail)
  --role ROLE       Lineage role for the parent  (default: "grail" first split,
                    else "parent")
  --set-remote      Also point `git remote origin` at the new repo
  --dry-run         Show what would change; write nothing
  -y, --yes         Don't prompt for confirmation
  -h, --help        Show this help

Examples:
  # Hatch using this repo's own origin (what the bootstrap Action runs):
  ./speciate.sh -y

  # Split off the grail explicitly into a self-contained organism:
  ./speciate.sh --owner kody-w --repo rapp_orion

  # Preview only:
  ./speciate.sh --owner acme --repo rapp_nova --dry-run
EOF
  exit "${1:-0}"
}

# ── parse args ────────────────────────────────────────────────────────────────
NEW_OWNER="" NEW_REPO="" BRANCH="" FROM_OWNER="" FROM_REPO="" ROLE=""
DRY_RUN=0 ASSUME_YES=0 SET_REMOTE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --owner) NEW_OWNER="${2:-}"; shift 2;;
    --repo) NEW_REPO="${2:-}"; shift 2;;
    --branch) BRANCH="${2:-}"; shift 2;;
    --from-owner) FROM_OWNER="${2:-}"; shift 2;;
    --from-repo) FROM_REPO="${2:-}"; shift 2;;
    --role) ROLE="${2:-}"; shift 2;;
    --set-remote) SET_REMOTE=1; shift;;
    --dry-run) DRY_RUN=1; shift;;
    -y|--yes) ASSUME_YES=1; shift;;
    -h|--help) usage 0;;
    *) die "Unknown argument: $1  (try --help)";;
  esac
done

command -v git     >/dev/null 2>&1 || die "git is required"
command -v perl    >/dev/null 2>&1 || die "perl is required"
command -v python3 >/dev/null 2>&1 || die "python3 is required"
git rev-parse --show-toplevel >/dev/null 2>&1 || die "not inside a git repository"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

# ── derive identity from `git remote origin` when not given explicitly ────────
# Explicit flags always win; anything omitted falls back to origin. This makes a
# no-input run (`./speciate.sh -y`, as the bootstrap Action does) speciate to the
# repo's OWN identity, and makes the grail / an already-speciated organism a
# no-op because origin already equals the content identity.
origin_url="$(git remote get-url origin 2>/dev/null || true)"
if [ -n "$origin_url" ]; then
  slug="$origin_url"
  slug="${slug%.git}"                       # drop trailing .git
  slug="${slug#https://github.com/}"        # https remote
  slug="${slug#http://github.com/}"
  slug="${slug#git@github.com:}"            # scp-style ssh remote
  slug="${slug#ssh://git@github.com/}"      # ssh:// remote
  # Accept only a clean "owner/repo": reject leftover scheme/host/extra path.
  case "$slug" in
    */*/*|*:*|*' '*|'') slug="" ;;
  esac
  if [ -n "$slug" ]; then
    : "${NEW_OWNER:=${slug%%/*}}"
    : "${NEW_REPO:=${slug##*/}}"
  fi
fi
[ -n "$NEW_OWNER" ] || die "could not determine owner — pass --owner (no usable 'origin' remote found)"
[ -n "$NEW_REPO" ]  || die "could not determine repo — pass --repo (no usable 'origin' remote found)"

MANIFEST="$ROOT/rappid.json"
HAD_MANIFEST=0; [ -f "$MANIFEST" ] && HAD_MANIFEST=1

# ── determine the parent (current) identity ───────────────────────────────────
if [ -n "$FROM_OWNER" ] && [ -n "$FROM_REPO" ]; then
  OLD_OWNER="$FROM_OWNER"; OLD_REPO="$FROM_REPO"
elif [ "$HAD_MANIFEST" = 1 ]; then
  OLD_OWNER="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["identity"]["owner"])' "$MANIFEST")"
  OLD_REPO="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["identity"]["repo"])' "$MANIFEST")"
else
  OLD_OWNER="$GRAIL_OWNER"; OLD_REPO="$GRAIL_REPO"
fi

# default role / branch
if [ -z "$ROLE" ]; then
  if [ "$HAD_MANIFEST" = 1 ]; then ROLE="parent"; else ROLE="grail"; fi
fi
if [ -z "$BRANCH" ]; then
  if [ "$HAD_MANIFEST" = 1 ]; then
    BRANCH="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["identity"].get("branch","main"))' "$MANIFEST")"
  else
    BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || echo main)"
  fi
fi

if [ "$OLD_OWNER/$OLD_REPO" = "$NEW_OWNER/$NEW_REPO" ]; then
  ok "Already speciated as $NEW_OWNER/$NEW_REPO — nothing to mutate."
  exit 0
fi

# Guard: a bare-token rewrite is unsafe if the new repo name contains the old one
# as a substring (it would re-corrupt freshly written URLs). Disable rule 4 then.
BARE_OK=1
case "$NEW_REPO" in *"$OLD_REPO"*) BARE_OK=0;; esac
case "$OLD_REPO" in *"$NEW_REPO"*) BARE_OK=0;; esac
[ "$BARE_OK" = 0 ] && warn "old/new repo names overlap — skipping bare-token rewrites (qualified URLs still mutate)"

COMMIT="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ── header ────────────────────────────────────────────────────────────────────
hr
say "${BLUE}RAPPID speciation${NC}"
say "  parent  ${DIM}(${ROLE})${NC}  ${OLD_OWNER}/${OLD_REPO}"
say "  child              ${GREEN}${NEW_OWNER}/${NEW_REPO}${NC}  ${DIM}@ ${BRANCH}${NC}"
say "  from commit        ${COMMIT:0:12}"
[ "$DRY_RUN" = 1 ] && say "  ${YELLOW}DRY RUN — no files will be written${NC}"
hr

# ── the mutation engine (perl: ordered, specificity-first) ────────────────────
# Two clean passes per file. A READ-ONLY count pass prints the substitution count
# alone on stdout (never merged with errors), then — only when there are hits and
# we are not in --dry-run — an in-place rewrite whose success is checked with an
# explicit `|| die` (a failed edit is fatal, never silently reported as success).
# The four rules run top-to-bottom on the slurped file, so qualified forms are
# consumed before the bare-token mopup.
export OLD_OWNER OLD_REPO NEW_OWNER NEW_REPO BARE_OK
SUBS='
  my $oo=$ENV{OLD_OWNER}; my $orp=$ENV{OLD_REPO};
  my $no=$ENV{NEW_OWNER}; my $nr=$ENV{NEW_REPO};
  my $n=0;
  $n += s{\Q$oo\E\.github\.io/\Q$orp\E}{$no.".github.io/".$nr}ge;   # 1 pages
  $n += s{\Q$oo\E%2F\Q$orp\E}{$no."%2F".$nr}ge;                     # 2 url-encoded
  $n += s{\Q$oo\E/\Q$orp\E}{$no."/".$nr}ge;                        # 3 owner/repo
  $n += s{\b\Q$orp\E\b}{$nr}g if $ENV{BARE_OK} eq "1";              # 4 bare repo token
'

CHANGED=0
HITS_TOTAL=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  is_protected "$f" && continue
  grep -Iq . "$f" 2>/dev/null || continue          # skip binary / empty
  # count pass — read-only; the number comes back alone on stdout
  if ! hits="$(perl -0777 -ne "$SUBS"'print $n;' "$f" 2>/dev/null)"; then
    die "failed to scan $f"
  fi
  hits="${hits//[!0-9]/}"; : "${hits:=0}"
  [ "$hits" -gt 0 ] || continue
  CHANGED=$((CHANGED + 1)); HITS_TOTAL=$((HITS_TOTAL + hits))
  printf '  %s%4d%s  %s\n' "$GREEN" "$hits" "$NC" "$f"
  # rewrite pass — in place; a write failure aborts rather than leaving it stale
  if [ "$DRY_RUN" = 0 ]; then
    perl -0777 -i -pe "$SUBS" "$f" || die "failed to rewrite $f (left unchanged)"
  fi
done < <(git ls-files)

hr
ok "$HITS_TOTAL self-identity references rewritten across $CHANGED files"

if [ "$DRY_RUN" = 1 ]; then
  warn "dry run — manifest and lineage NOT written, files NOT changed"
  exit 0
fi

# ── confirm before persisting identity ────────────────────────────────────────
if [ "$ASSUME_YES" = 0 ]; then
  if [ -t 0 ] || [ -r /dev/tty ]; then
    printf '%sRecord this speciation in the lineage and write rappid.json? [y/N] %s' "$YELLOW" "$NC"
    read -r reply </dev/tty 2>/dev/null || reply=""
    case "$reply" in
      y|Y|yes|YES) ;;
      *) die "aborted — files were mutated; run 'git checkout .' to undo, or re-run with -y";;
    esac
  fi
fi

# ── write manifest + lineage (python3, stdlib only) ───────────────────────────
export BRANCH ROLE COMMIT STAMP HAD_MANIFEST DEFAULT_SIBLINGS_JSON MANIFEST
python3 - <<'PY'
import json, os

owner, repo, branch = os.environ["NEW_OWNER"], os.environ["NEW_REPO"], os.environ["BRANCH"]
manifest_path = os.environ["MANIFEST"]

prior = {}
if os.environ["HAD_MANIFEST"] == "1" and os.path.exists(manifest_path):
    with open(manifest_path) as fh:
        prior = json.load(fh)

lineage = list(prior.get("lineage", []))
lineage.append({
    "parent": {"owner": os.environ["OLD_OWNER"], "repo": os.environ["OLD_REPO"]},
    "child":  {"owner": owner, "repo": repo},
    "role": os.environ["ROLE"],
    "speciated_from_commit": os.environ["COMMIT"],
    "speciated_at": os.environ["STAMP"],
    "tool": "speciate.sh",
})

siblings = prior.get("siblings") or json.loads(os.environ["DEFAULT_SIBLINGS_JSON"])

manifest = {
    "schema": "rappid/v1",
    "organism": repo,
    "identity": {
        "owner": owner,
        "repo": repo,
        "branch": branch,
        "github_pages": f"{owner}.github.io/{repo}",
        "clone_url": f"https://github.com/{owner}/{repo}.git",
        "raw_base": f"https://raw.githubusercontent.com/{owner}/{repo}/{branch}",
        "issues_repo": f"{owner}/{repo}",
    },
    # Separate, independently-evolving organisms. Kept, never auto-mutated.
    "siblings": siblings,
    # Anatomy/branding deliberately preserved across speciation.
    "preserved": ["RAPP", "brainstem", "~/.brainstem", "rapp_brainstem/", "community_rapp/"],
    # Oldest ancestor first. Read top-to-bottom for the line of descent.
    "lineage": lineage,
}
with open(manifest_path, "w") as fh:
    json.dump(manifest, fh, indent=2)
    fh.write("\n")

def slug(e, side):
    return f'{e[side]["owner"]}/{e[side]["repo"]}'

chain = []
for e in lineage:
    if not chain:
        chain.append(slug(e, "parent"))
    chain.append(slug(e, "child"))

lines = [
    "# Lineage",
    "",
    f"**This organism:** `{owner}/{repo}` — *{repo}*  ",
    f"**Gateway:** https://{owner}.github.io/{repo}",
    "",
    "Each RAPP organism descends from the common **grail** ancestor by *speciation*",
    "(`speciate.sh`): the gateway self-identity is rewritten so the organism pulls",
    "from itself, and the split is recorded below. There is no functional dependency",
    "back up the chain — only this traceable record of descent.",
    "",
    "## Line of descent",
    "",
    "```",
    "  " + "\n    ↓\n  ".join(chain),
    "```",
    "",
    "## Speciation events",
    "",
    "| # | parent | role | → | child | from commit | at (UTC) |",
    "|---|--------|------|---|-------|-------------|----------|",
]
for i, e in enumerate(lineage, 1):
    lines.append(
        f'| {i} | `{slug(e,"parent")}` | {e.get("role","")} | → | `{slug(e,"child")}` '
        f'| `{e.get("speciated_from_commit","")[:12]}` | {e.get("speciated_at","")} |'
    )
lines += ["", "## Siblings (independent organisms, not ancestors)", ""]
for k, v in siblings.items():
    lines.append(f"- **{k}** — `{v}`")
lines += ["", "_Generated by `speciate.sh` from `rappid.json`. Do not edit by hand._"]

with open(os.path.join(os.path.dirname(manifest_path), "LINEAGE.md"), "w") as fh:
    fh.write("\n".join(lines) + "\n")
PY

ok "wrote rappid.json"
ok "wrote LINEAGE.md"

# ── optional: repoint git origin ──────────────────────────────────────────────
if [ "$SET_REMOTE" = 1 ]; then
  NEW_REMOTE="https://github.com/${NEW_OWNER}/${NEW_REPO}.git"
  git remote set-url origin "$NEW_REMOTE" && ok "git remote origin → $NEW_REMOTE"
fi

hr
say "${GREEN}Speciation complete.${NC} ${NEW_OWNER}/${NEW_REPO} now pulls from itself."
say "Next:"
say "  ${DIM}1.${NC} review the diff:      ${DIM}git diff${NC}"
say "  ${DIM}2.${NC} confirm lineage:      ${DIM}cat LINEAGE.md${NC}"
say "  ${DIM}3.${NC} run the test suite:   ${DIM}bash tests/test_installer.sh${NC}"
say "  ${DIM}4.${NC} commit + push to:     ${DIM}${NEW_OWNER}/${NEW_REPO}${NC}"
[ "$SET_REMOTE" = 0 ] && say "  ${DIM}(remote unchanged — pass --set-remote to repoint origin)${NC}"
