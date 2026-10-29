# 01-product — the product, built in one landing

**Places** every module: the root manifests, CI, tooling, the identity
file, the product's README and its `AGENTS.md` (what an agent reads first);
`apps/preview` (the preview proxy, its OpenNext build, its deploy contract);
`apps/web` (the host app, the same); `tests/preview` and `tests/web`
(vitest). Then brands them, lands them as ONE pull request, and watches the
ONE convergence that merge triggers.

**Budget** about 8 minutes (`expectedMinutes: 8` in `repo-blueprint.yaml`, an
estimate): turso-starter's measured shape is one Next.js Worker in about
five minutes; here each environment builds and deploys two, the preview
origin and then the host app, one after the other.

**Requires** both connections live — GitHub (the App installation on the
OWNER of the repository, the only way the platform sees its pull requests)
and Cloudflare (every deploy credential below is minted from it) — probed,
waited for up to ten minutes each, so the consent can be clicked while it
waits. No v0 key: the product serves without one.

## What runs

The run's task set-up — the epic, both milestones, both tasks — runs in the
background from the start (`background: true`), so every hook up to `task`
runs beside it; `task` is the first that waits for it.

| hook | what it does |
|---|---|
| `retouch` | the redeploy marker on the components `.baseline/tasks/01-product.TaskContract.yaml` names: `preview`, `preview-tests`, `web`, `web-tests` |
| `git-init`, `stage`, `rebrand` | the tree becomes a repository, then the product's: its slug, both Workers' names, its secret project, its name in both apps' `lib/site.ts` |
| `orun-workspace` | intent.yaml's `workspace:` becomes the product's (or `ws_SET_ME`, which fails loudly) |
| `work-tree` | intent.yaml's `work:` block — this repository's epics and tasks — is removed |
| `promotion`, `dev-lanes` | prod's promotion gate and dev's push-to-main activation deferred until `02-docs` |
| `restage`, `rebrand-verify` | the sweep: no identity of this baseline left anywhere |
| `repo` | `orun.repo/ensure@v1` creates `<githuborg>/<reponame>` (or finds it) |
| `link` | the repository becomes the workspace's; `orun cloud check` is the gate |
| `secrets` | `orun.integrations/reconcile@v1`, both keys in one hook, created side by side: `CLOUDFLARE_API_TOKEN` from the `workers-deploy` template (ONE token deploys both Workers); `CLOUDFLARE_ACCOUNT_ID`, the connection fact both bind |
| `task` | finds the phase's task and yields its key — waiting, if it must, for the background set-up |
| `land` | one PR bound to the task, its commit checked in the box first (`checks: local`: `orun validate`, then `orun plan` as the PR and as the merge would plan it, under a second); merged without waiting for the PR's CI |
| `converge` (await) | `orun.run/watch@v1` on the merge commit's run, read every 5 s; resumes it up to three times |
| `verify` (await) | `orun.http/probe@v1` on the host app's two workers.dev URLs and the preview origin's two `/api/health` |

## What the convergence does

`orun plan --changed` on the merge plans, with dev's push activation and the
promotion gate deferred:

| lane | waits on | does |
|---|---|---|
| `stage · preview` / `prod · preview` | nothing | builds the preview proxy with OpenNext, the host's origin inlined (`NEXT_PUBLIC_V0_CLONE_ORIGIN` = `https://<reponame>-web-<env>.<subdomain>.workers.dev`), hands a stored `V0_API_KEY` to the Worker as a secret (none on a fresh product), deploys `<reponame>-preview-<env>`, and smoke-tests it: `/api/health` must answer `"app":"preview"` and `"ok":true` |
| `stage · web` / `prod · web` | that environment's preview deploy (`dependsOn: preview`, `mode: enforced` on main) | builds the host app with the proxy's origin inlined (`NEXT_PUBLIC_V0_PREVIEW_PROXY_URL`), hands the key the same way, deploys `<reponame>-web-<env>`, and smoke-tests it: `/` must render to `</html>`, `/api/health` answer `"ok":true`, and the proxy origin it names answer as the preview proxy |

Stage and prod run side by side. `preview-tests` and `web-tests` verify on
dev only, on a pull request. The landing's own pull request runs `plan`
alone, and nothing waits for it — the same plan ran in the box before the
push: the baseline's own CI installed, type-checked, linted, tested and
built this exact tree before the tag was cut.

## Verified

The convergence run for the merge commit is green — each host app's smoke
reached the preview origin it was built with;
`https://<reponame>-web-{stage,prod}.<subdomain>.workers.dev` and
`https://<reponame>-preview-{stage,prod}.<subdomain>.workers.dev/api/health`
answer.

## Troubleshooting

| symptom | cause → fix |
|---|---|
| parks on the `providers` probe | GitHub (on the repository's owner) or Cloudflare is not connected to the workspace. Connect it (console → Integrations), then re-run the phase — the probe is a wait, not a failure |
| stops at `link` | the repository is not linked to the workspace and the credential cannot link it. Allow-list it (console → Settings → Git repos) and re-run the phase |
| `land`: `the landing's own check failed — orun plan for …` | the placed tree does not plan; the next line is orun's error. Nothing was pushed. Fix it and re-run the phase |
| deploy lane: Authentication error (10000) | the connection's token lacks Workers Scripts write. Re-issue it with the permission groups the console's Connect recipe lists, re-connect, re-run the phase |
| web lane shows as not run | that environment's preview deploy failed — read its lane; the web lane waits on it |
| web smoke fails after `/api/health` | the proxy origin the host names did not answer as the preview proxy: its deploy failed, or `V0_PREVIEW_PROXY_URL` names a domain not attached to it yet |
| `build-app` fails: `Symlink apps/<app>/node_modules/next is invalid, it points out of the filesystem root` | the product's `intent.yaml` pins stack-tectonic ≥ 0.20.0 (lane-scoped install). Pin 0.19.0 — `intent.yaml`'s comment says why |
| smoke fails right after the FIRST deploy | workers.dev route propagation; the composition retries the first deploy and the smoke with backoff (stack-tectonic ≥ 0.19.0). A convergence resume clears what is left |
| the watch says green, the probe says 404 | another workflow ran on the push and the watch took its run. Only `ci.yml` may run on a push to main |
| convergence failed AFTER the PR merged; re-running lands nothing | the hooks did not run (`--run-hooks`), or the contract names no component — `node tooling/bootstrap/retouch.mjs --check --affects .baseline/tasks/01-product.TaskContract.yaml` in the product's tree says which |
