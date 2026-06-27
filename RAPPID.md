# RAPPID — how RAPP organisms are born

**RAPPID** (RAPP + **ID**entity; also *rapid*) is the speciation system for the RAPP
platform. It lets a new repo **split off the common ancestor**, rewire itself to
pull from **itself**, and keep nothing but a **traceable lineage** pointing home.

> Metaphor: there is one ancestral **grail** — `kody-w/rapp-installer`. Every new
> repo forked from it is an **organism** that *speciates*: it mutates its
> self-identity, severs every functional tie to the ancestor, and lives its own
> life. The only thing it keeps is a record of descent.

This repo, **`rapp_orion`**, is the first such organism.

---

## The model

| Term | Meaning |
|------|---------|
| **grail** | The genesis ancestor, `kody-w/rapp-installer`. Constant for all descendants. |
| **organism** | A repo that has speciated and now pulls from itself (e.g. `rapp_orion`). |
| **speciation** | The one-time act of rewriting self-identity + recording the split. |
| **self gene** | A reference that points the world at *this* repo (clone/curl/Pages/issues). Mutates. |
| **sibling** | A *different* organism the repo interoperates with (CommunityRAPP, AI-Agent-Templates, RAR). Preserved. |
| **anatomy** | Structural/branding names (`RAPP`, `brainstem`, `~/.brainstem`). Preserved. |

A speciation **mutates only the self genes** and leaves siblings, anatomy, and
binaries alone. That is the whole point: independence at the gateway, continuity
everywhere else.

### What mutates (self genes)

Every spelling of "where do I tell people to get me":

- `<owner>.github.io/<repo>` — the GitHub Pages gateway
- `<owner>%2F<repo>` — URL-encoded forms (the **Deploy to Azure** button)
- `<owner>/<repo>` — `github.com`, `raw.githubusercontent.com`, `api.github.com/repos/…`, `gh --repo`
- bare `<repo>` — prose, `*.git` URLs, the installer test assertion

This includes the in-server **feedback → GitHub Issues** target in
`rapp_brainstem/brainstem.py`, so bug reports land in the organism's own tracker.

### What is preserved

- **Siblings** — `kody-w/CommunityRAPP` (Tier 2 / Azure), `kody-w/AI-Agent-Templates`
  (remote agents), `kody-w/RAR`. They are separate live organisms, listed under
  `siblings` in `rappid.json`, and are **never** auto-rewritten. Repoint them by
  hand if you ever fork them too.
- **Anatomy & branding** — `RAPP`, `brainstem`, the `~/.brainstem` install home,
  and component directories (`rapp_brainstem/`, `community_rapp/`).
- **Binaries** — `*.zip` (the Power Platform solution), images, fonts.
- **The machinery** — `speciate.sh` and this file hold the immutable grail
  constant for *all* descendants, so the tool never rewrites them.

---

## Birthing a new organism

1. **Fork / template** the grail (or any organism) into a new repo, e.g.
   `kody-w/rapp_nova`, and clone it locally.
2. From the repo root, run the speciation:

   ```bash
   ./speciate.sh --owner kody-w --repo rapp_nova
   ```

   Preview first with `--dry-run`. Skip the prompt with `-y`. Repoint the git
   remote at the same time with `--set-remote`.
3. Review `git diff`, read `LINEAGE.md`, run `bash tests/test_installer.sh`.
4. Commit and push to the new repo. Done — `rapp_nova` now pulls from itself and
   has no functional link back to its parent.

The tool auto-detects the parent: it reads the current identity from
`rappid.json` if present, otherwise assumes the grail. So a grandchild
(`grail → orion → nova`) correctly records orion as its parent and appends a new
row to the chain.

### Files the tool produces

- **`rappid.json`** — the manifest. Single source of truth for this organism's
  identity, its siblings, and the full ancestry chain.
- **`LINEAGE.md`** — generated from the manifest; the human-readable descent.

---

## `rappid.json` shape

```jsonc
{
  "schema": "rappid/v1",
  "organism": "rapp_orion",
  "identity": {
    "owner": "kody-w",
    "repo": "rapp_orion",
    "branch": "main",
    "github_pages": "kody-w.github.io/rapp_orion",
    "clone_url": "https://github.com/kody-w/rapp_orion.git",
    "raw_base": "https://raw.githubusercontent.com/kody-w/rapp_orion/main",
    "issues_repo": "kody-w/rapp_orion"
  },
  "siblings": { "hippocampus": "kody-w/CommunityRAPP", "...": "..." },
  "preserved": ["RAPP", "brainstem", "~/.brainstem", "..."],
  "lineage": [
    {
      "parent": { "owner": "kody-w", "repo": "rapp-installer" },
      "child":  { "owner": "kody-w", "repo": "rapp_orion" },
      "role": "grail",
      "speciated_from_commit": "…",
      "speciated_at": "…Z",
      "tool": "speciate.sh"
    }
  ]
}
```

Each `lineage` entry is one speciation event. Oldest (grail) first; the last
entry's `child` is this organism. That ordered list **is** the rapid lineage —
the only thread tying the organism back to where it came from.
