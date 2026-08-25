# Identity & Lineage

`rapp_orion` is a **variant** in the RAPP species tree. Its identity follows the single
global **Eternity rappid standard** (`rapp-rappid/2.0`) defined by the species root
[`kody-w/RAPP`](https://github.com/kody-w/RAPP) — see RAPP's `CONSTITUTION.md` **Article XXXIV**
and `pages/vault/Architecture/Rappid.md`.

- **This organism:** `rappid:@kody-w/rapp_orion:00c48fc540044d96a5480e2b90d8e29d`
- **Parent (species root / godfather):** `rappid:@kody-w/rapp:9a8f0a4b5a710e20f4d819a0f37d2a4c9f113b5e78fb3c29e70b54fff48a38f9`
- **Manifest:** [`rappid.json`](./rappid.json) — schema `rapp-rappid/2.0`.

There is **one rappid format, one species tree, one godfather.** A rappid is immutable; minting
a new one is the birth of a child organism (Article XXXIV — single-parent rule). To mint or
re-initialize a variant, use RAPP's canonical flow `installer/initialize-variant.sh` — not a
local tool.

## Living twin

`hatch_twin.sh` stands up a **running local instance** ("living twin") of this organism under
`~/.brainstem/twins/<name>/`, on its own port, alongside the global brainstem. The twin is the
living counterpart of this repo's static genome; its `twin.json` carries this organism's
canonical `rappid` for provenance.

## Migration note

This repo previously carried a parallel **`rappid/v1`** system (`speciate.sh`, `RAPPID-SPEC.md`,
`LINEAGE.md`, and a bootstrap GitHub Action). That was a non-standard, parallel identity format
and has been **retired** in favor of the single Eternity standard above. Lineage now lives in
`rappid.json` as one `parent_rappid` chaining to the RAPP species root.
