# Risks and open questions — v0-clone

| ID | Risk | Mitigation / decision |
|---|---|---|
| VC-A | Upstream has no user accounts: with `V0_API_KEY` stored, everyone who reaches the Worker shares the owner's v0 workspace and credits | The key is optional and unset by default, so each visitor uses their own through the dialog. The README says to put Cloudflare Access in front of both Workers before storing a shared key |
| VC-B | Both Workers live under one `<subdomain>.workers.dev`, so the preview origin is cross-origin but same-site with the host (upstream recommends different registrable domains for strong isolation) | Recorded; the README's "Custom domains" says to give the preview proxy a domain of its own for production |
| VC-C | The v0 trusted preview hosts list holds at most five; each environment's preview Worker registers its hostname | stage and prod take two; the README says how to prune |
| VC-D | The v0 SDK, `ai` and `streamdown` on workerd | Proven in VC1 under `wrangler dev`; sizes recorded |
| VC-E | No live bootstrap from a tag yet: the repository, the link, the brokered token, two real deploys, the secrets push and the probes | OPEN — Baseline CI proves everything short of the platform offline (placement, rename, the plan's order, both builds in orun's staged job trees, both smokes against `wrangler dev`) |
| VC-F | The real v0 Platform API, called from a Worker | OPEN — the stand-in (`testing/lib/fake-v0-api.py`) answers the same paths with the same auth and preview token; one live chat and preview closes it |
