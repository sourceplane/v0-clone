# Risks and open questions — v0-clone

| ID | Risk | Mitigation / decision |
|---|---|---|
| VC-A | Upstream has no user accounts: with `V0_API_KEY` stored, everyone who reaches the Worker shares the owner's v0 workspace and credits | The key is optional and unset by default, so each visitor uses their own through the dialog. The README says to put Cloudflare Access in front of both Workers before storing a shared key |
| VC-B | Both Workers live under one `<subdomain>.workers.dev`, so the preview origin is cross-origin but same-site with the host (upstream recommends different registrable domains for strong isolation) | Recorded; the README's "Custom domains" says to give the preview proxy a domain of its own for production |
| VC-C | The v0 trusted preview hosts list holds at most five; each environment's preview Worker registers its hostname | stage and prod take two; the README says how to prune |
| VC-D | The v0 SDK, `ai` and `streamdown` on workerd | Proven in VC1 under `wrangler dev`; sizes recorded |
