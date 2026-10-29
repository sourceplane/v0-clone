# Epics

Orun-style work programs. Each epic is a folder carrying `epic.yaml` (the
declaration the platform reads: slug, key prefix, milestones with exit
criteria and task keys) beside its doc set. The pull request that adds the
folder is the adoption; the merge creates the epic in the workspace.

| Epic | Cluster | Status | What it is |
|------|---------|--------|------------|
| [`v0-clone/`](./v0-clone/) | **VC** | In progress | Vercel's v0 clone — a v0-style app builder over the v0 Platform API — equivalent in code and function on TWO Cloudflare Workers (the host app and its isolated preview origin) — and an Orun baseline that instantiates it in one landing |

As-built ≠ intent: what shipped lives in each epic's `IMPLEMENTATION-STATUS.md`.
