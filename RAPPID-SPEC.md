# RAPPID Speciation — Specification (`rappid/v1`)

Status: stable · Applies to `speciate.sh`, `rappid.json`, `LINEAGE.md`,
`.github/workflows/speciate.yml`. Companion guide: `RAPPID.md`.

RAPPID is the protocol by which a RAPP repository **splits off an ancestor and
becomes a self-contained organism** that pulls from itself, retaining only a
traceable record of descent. This document specifies the data formats, the
mutation rules, the algorithm, and the invariants. Where this spec and prose
docs disagree, this spec governs.

---

## 1. Terms

| Term | Definition |
|------|------------|
| **grail** | The genesis ancestor `kody-w/rapp-installer`. Has no parent and no `rappid.json`. The constant origin of every lineage. |
| **organism** | A repository that has speciated and now points its gateway at itself (e.g. `kody-w/rapp_orion`). |
| **hatchery** | Any organism (or the grail) marked as a GitHub *Template repository*, from which new organisms are generated. |
| **speciation** | The act of rewriting an organism's self-identity and appending one lineage event. |
| **self-gene** | A reference whose purpose is to point the world at *this* repo (clone/raw/Pages/encoded/issues/`gh --repo`/bare repo token). Mutated. |
| **sibling** | A *different* organism this repo interoperates with (`CommunityRAPP`, `AI-Agent-Templates`, `RAR`). Preserved. |
| **anatomy** | Structural/branding names (`RAPP`, `brainstem`, `~/.brainstem`, component dirs). Preserved. |
| **protected** | Machinery/docs that must never be self-mutated (§6). |

---

## 2. Invariants (normative)

- **I1 — The ancestor is never written.** No speciation writes to, pushes to, or
  runs a workflow inside any ancestor. `git push` (manual or CI) targets the
  organism's own `origin` only. Ancestors appear solely as read-only strings in
  lineage records.
- **I2 — Idempotent.** Speciating when the resolved target identity already
  equals the current identity is a no-op (no file changes, no lineage event).
- **I3 — Self-protection by construction.** When a repo's `origin` already equals
  its content identity (the grail, or an already-speciated organism), a no-input
  speciation is a no-op (follows from I2 + §4).
- **I4 — Lineage is append-only.** Events are ordered oldest-first; existing
  events are never modified or removed; the last event's `child` equals the
  current `identity`.
- **I5 — Siblings and anatomy are preserved.** Never auto-rewritten.
- **I6 — Binaries are never opened.** Non-text assets are skipped (§6).
- **I7 — Machinery is inert under mutation.** Protected files (§6) are never
  rewritten, so the grail constant and the spec survive every generation.

---

## 3. Roles a repo can hold

```
grail  (kody-w/rapp-installer)        ── read-only ancestor, no rappid.json
  │  "Use this template"
  ▼
hatchery organism (e.g. rapp_orion)   ── speciated; optionally a Template repo
  │  "Use this template"
  ▼
organism (e.g. someone/their-rapp)    ── speciates on first push, chains lineage
```

A repo's role is not encoded in its URL. It is determined by metadata
(`is_template`, `template_repository`, `fork`) and by comparing `origin` to the
content identity (§4). The grail is kept clean by making a *descendant* the
hatchery; touching the grail is never required (see `RAPPID.md`).

---

## 4. Identity resolution

**Target (new) identity** — the organism being produced:
1. If `--owner` / `--repo` are given, they win (each independently).
2. Any omitted value is derived from `git remote get-url origin`, parsed as
   GitHub `owner/repo`:
   - strip a trailing `.git`;
   - strip one of `https://github.com/`, `http://github.com/`,
     `git@github.com:`, `ssh://git@github.com/`;
   - the result MUST be a clean `owner/repo` (exactly one `/`, no residual
     scheme/host/space). Non-GitHub or ambiguous remotes are rejected.
3. If still unresolved, abort with a message requesting explicit flags.

**Parent (old) identity** — what the content currently claims:
1. If `--from-owner` / `--from-repo` are given, they win.
2. Else if `rappid.json` exists, use its `identity.owner` / `identity.repo`.
3. Else (no manifest) assume the **grail** `kody-w/rapp-installer`.

If parent == target, the run is a no-op (I2).

---

## 5. Mutation rules

The parent identity is rewritten to the target identity by **four ordered**
substitutions applied per file, most-specific first, with literal quoting of
`owner`/`repo`. Let `O/R` = parent owner/repo, `O'/R'` = target.

| # | Rule | Pattern → Replacement | Covers |
|---|------|-----------------------|--------|
| 1 | Pages | `O.github.io/R` → `O'.github.io/R'` | GitHub Pages host/path |
| 2 | Encoded | `O%2FR` → `O'%2FR'` | URL-encoded (Deploy-to-Azure button) |
| 3 | Slug | `O/R` → `O'/R'` | `github.com`, `raw`, `api/repos`, `gh --repo` |
| 4 | Bare | `\bR\b` → `R'` | prose, `*.git`, test assertions |

Ordering guarantees qualified forms (1–3) are consumed before the bare mopup (4).

**Bare-rule guard (`BARE_OK`).** Rule 4 is disabled when `R'` contains `R` (or
vice-versa) as a substring, to avoid re-corrupting freshly written slugs. Rules
1–3 always run.

The same four substitutions are used for both counting (read-only) and the
in-place rewrite, so the reported count and the applied change cannot diverge.

---

## 6. Scope of files

Applied to every **git-tracked** path EXCEPT:

- **Protected** (never mutated): `rappid.json`, `LINEAGE.md`, `speciate.sh`,
  `hatch_twin.sh`, `RAPPID.md`, `RAPPID-SPEC.md`,
  `.github/workflows/speciate.yml`.
- **Binary / non-text**: `*.zip`, common image/font/media extensions, and any
  file Git treats as binary (probed with `grep -I`).
- Empty files (nothing to change).

Protected files legitimately retain ancestor strings: the grail constant
(`speciate.sh`), canonical examples (`RAPPID.md`, this spec), and lineage records
(`rappid.json`, `LINEAGE.md`). This is correct, not leakage.

---

## 7. `rappid.json` (schema `rappid/v1`)

Authoritative identity + ancestry. One object:

```jsonc
{
  "schema": "rappid/v1",
  "organism": "<repo>",                      // == identity.repo
  "identity": {
    "owner": "<owner>",
    "repo": "<repo>",
    "branch": "<default-branch>",
    "github_pages": "<owner>.github.io/<repo>",
    "clone_url":  "https://github.com/<owner>/<repo>.git",
    "raw_base":   "https://raw.githubusercontent.com/<owner>/<repo>/<branch>",
    "issues_repo": "<owner>/<repo>"
  },
  "siblings": { "<key>": "<owner>/<repo>", ... },   // preserved; carried forward
  "preserved": [ "RAPP", "brainstem", "~/.brainstem", ... ],
  "lineage": [ <event>, ... ]                        // append-only, oldest first
}
```

**lineage event:**

```jsonc
{
  "parent": { "owner": "<o>", "repo": "<r>" },
  "child":  { "owner": "<o'>", "repo": "<r'>" },
  "role": "grail" | "parent",     // "grail" iff this was the first split
  "speciated_from_commit": "<full-sha-at-split>",
  "speciated_at": "<ISO-8601 UTC, e.g. 2026-06-27T02:26:22Z>",
  "tool": "speciate.sh"
}
```

The grail has **no** `rappid.json`. The first descendant's lineage has exactly
one event with `role: "grail"`. `siblings`/`preserved` carry forward from the
parent manifest when present, else seed from tool defaults.

---

## 8. `LINEAGE.md`

Generated from `rappid.json`; never hand-edited. Contains: the current identity
and gateway, the line of descent (`grail → … → this`), a table of speciation
events (parent, role, child, short commit, timestamp), and the sibling list.

---

## 9. Speciation algorithm

1. Require `git`, `perl`, `python3`; require a Git work tree; `cd` to its root.
2. Resolve target and parent identity (§4).
3. If parent == target → report no-op and exit 0 (I2).
4. Compute `BARE_OK` (§5), capture `HEAD` SHA and a UTC timestamp.
5. For each tracked, non-protected, text file: count (read-only) the four
   substitutions; if > 0, rewrite in place (failure is fatal — never silently
   left stale).
6. Unless `--dry-run`: write `rappid.json` (new identity; carry forward
   siblings/preserved; append the lineage event) and regenerate `LINEAGE.md`.
7. Optionally (`--set-remote`) repoint `origin` to the new clone URL (local only).

`--dry-run` performs steps 1–5 read-only and writes nothing. Confirmation is
prompted unless `-y/--yes` or no TTY is available.

---

## 10. Bootstrap Action (`.github/workflows/speciate.yml`)

Contract for zero-touch hatching:

- **Triggers:** `push` to `main`/`master`, and `workflow_dispatch`.
- **Permissions:** `contents: write`.
- **Guard:** runs only if `github.event.repository.is_template != true` **and**
  `…​.fork != true` (skip templates and forks; `!= true` so a missing field
  defaults to running, made safe by I2/I3).
- **Steps:** checkout → `./speciate.sh -y` (no flags ⇒ origin-derived identity)
  → if the work tree changed, commit as `github-actions[bot]` and `git push` to
  the repo's own `origin`. If push is denied, fail with the remediation
  (enable read/write workflow permissions, or run `speciate.sh` locally).
- **Identity-neutral:** contains no owner/repo literals, so it propagates to
  every descendant unchanged and is itself a protected file (§6).

By I1, this can only ever write to the repo it runs in — never an ancestor.

---

## 11. Non-goals

- **Branding/rename** (`RAPP`, `RAPP Installer`, `brainstem`): out of scope;
  preserved. Rename manually if desired.
- **Sibling repointing**: siblings are recorded and preserved, never auto-forked.
- **GitHub Pages enablement / repo settings**: not automated; documented manual
  steps (mark as Template, set workflow permissions).
- **Non-GitHub hosts**: origin-derivation is GitHub-only; use explicit flags
  elsewhere.
- **Grail edits**: never performed by tooling; if ever needed, delivered as a
  reviewable checklist for a human to run (see `RAPPID.md` / `never-write` rule).

---

## 12. Living twins (runtime, `rappid-twin/v1`)

A speciated organism has two bodies: the **static genome** (the published repo,
served as `raw.githubusercontent` data — it does not run) and zero or more
**living twins** (running brainstem instances hatched from that genome).
`hatch_twin.sh` produces a twin:

- copies the organism's `rapp_brainstem/` genome into
  `~/.brainstem/twins/<name>/` (excluding `agents/experimental/`, `__pycache__/`);
- stamps the twin dir with `rappid.json` + `LINEAGE.md` (identity provenance) and
  shares the global brainstem's Copilot auth (`.copilot_token`/`.copilot_session`);
- writes `twin.json` (the living↔static link);
- launches the organism's **own** engine on its own free port (default ≥ 7072),
  **alongside — never replacing —** the global brainstem, then waits for `/health`.

`twin.json`:

```jsonc
{
  "schema": "rappid-twin/v1",
  "kind": "local-living-twin",
  "organism": "<repo>",
  "identity":      { "owner": "<o>", "repo": "<r>", "branch": "<b>" },
  "static_genome": { "clone_url": "…", "raw_base": "…",
                     "github_pages": "…", "source_commit": "<sha>" },
  "runtime":       { "engine": "own", "twin_dir": "…",
                     "host": "http://localhost:<port>", "port": <n>,
                     "venv_python": "…" },
  "hatched_at": "<ISO-8601 UTC>",
  "tool": "hatch_twin.sh"
}
```

Invariant **I1** holds for twins: a twin runs locally and writes only under its
own twin dir; it never modifies the static genome or any ancestor.
```
