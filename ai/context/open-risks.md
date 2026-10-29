# v0-clone — open risks

What is not yet proven or not yet decided. The full write-up of every risk,
including the accepted and resolved ones, is
`specs/epics/v0-clone/risks-and-open-questions.md`; this page lists
only what is still live, so it should be short.

| ID | Risk | State | What closes it |
|---|---|---|---|
| VC-E | No live bootstrap yet: the repository created and linked, the token minted, two real `wrangler deploy`s, the secrets push and the probes are all unproven | OPEN | One bootstrap from a tag against a workspace |
| VC-F | The real v0 Platform API has not been called from a Worker; offline only a stand-in answers (the same paths, auth and preview token) | OPEN | One chat created and its preview opened on a live deployment |

Accepted, and worth knowing before you change them: VC-A (no accounts: a
stored `V0_API_KEY` is shared with every visitor — leave it unset, or put
Cloudflare Access in front of both Workers), VC-B (on workers.dev the
preview is same-site with the host; give it a domain of its own for
production), VC-C (v0 trusts at most five preview hosts), VC-D (both Workers
are under Workers Free's 3 MiB gzipped: web 2.1 MiB, preview 1.6 MiB).
