# BOOTSTRAP — a new product from this baseline, in one landing

How to go from **nothing** to an **AI app builder live on stage and prod —
Vercel's v0 clone, its host app and its isolated preview origin on two
Workers, serving from its first deploy with each visitor's own v0 key —
documented**, with ONE provider consent.

There is one artifact: **`repo-blueprint.yaml`**. It declares what to place,
in what order, what each phase needs first, and what to say while it runs.
`orun new` is the whole runtime — the phases below are its `--phase` names,
not separate workflows. The console card the platform renders is
**`blueprint.yaml`**; it names the build document and states the inputs, the
brokered secrets and the programme, and `testing/manifest.test.sh` holds it
to what the build document does.

Target wall-clock: **about nine minutes** — an estimate summed from the
phases (8 + 1) until a bootstrap measures it; no build of this baseline has
been timed. The shape: the task set-up in the background while ONE landing
is placed, branded and checked in the box (`orun validate` and `orun plan`,
no runner waited for), then one convergence — in each environment the
preview origin built and deployed, then the host app built with its origin
and deployed, stage and prod side by side — then a short docs landing that
restores the promotion gate.

## 0. What you need

- GitHub org access (repository creation) and a machine with `git`, `node`
  (≥ 22), `pnpm` (10.12.1), `python3` with PyYAML, `curl`, and the `orun`
  CLI **≥ v2.88.0** — the floor for RUNNING the bootstrap (the phase overlay,
  landings that commit per phase, `githubOwner` on the doctor probe, a probe
  deferred for a project not yet created, `from: workspace`, the deploy
  credentials minted in one `secrets` reconcile, the task set-up run in the
  background (`background: true`), and landings checked in the box before
  they merge (`checks: local`)). The product's own `ci.yml` pins its lanes
  separately (v2.78.4).
- A Cloudflare account (the free plan is enough for two Workers with static
  assets per environment: they are 2.1 and 1.6 MiB gzipped) and its
  **Account API token** with Workers Scripts Write (the console's Connect
  recipe lists the exact permission groups). It is the ONLY provider
  credential this baseline needs: the brokered `workers-deploy` scope covers
  both Workers' deploys.
- No v0 key. The product serves without one — each visitor connects their
  own in the browser — and an owner who wants one key for everyone stores it
  after the bootstrap (§4).
- An Orun Cloud workspace for the product — `orunWorkspace`, or the
  workspace the build runs in (ORUN_WORKSPACE) when that is unset — with an
  **admin-role API key** for headless runs (secret writes below admin are
  masked as `not_found`).
- **The repository allow-listed in the workspace** (console → Settings → Git
  repos), unless the credential can write links. `01-product`'s `link` step
  stops and names the fix if it is not.

## 1. One command: `--resume`

The whole bootstrap, unattended. `--resume` places every phase not already
derived as done, in order, honouring each phase's barrier:

```bash
git clone --depth 1 --branch <baseline-tag> https://github.com/sourceplane/v0-clone
cd v0-clone

orun new --blueprint repo-blueprint.yaml \
  --out ~/sites/acme-builder --run-hooks --resume \
  --set reponame=acme-builder --set productname="Acme Builder" \
  --set githuborg=acme-inc \
  --set orunWorkspace=ws_XXXXXXXX \
  --set subdomain=<workers-dev-subdomain>
```

`subdomain` is the workers.dev subdomain of the Cloudflare account you deploy
into (Workers & Pages → your subdomain). A build started from the console, or
with `orun baseline new --from bst_…`, never asks for it: the platform reads
it from the workspace's Cloudflare connection, the same one the deploy tokens
mint from. Only a hand-run build like this one passes it.

**`--run-hooks` is the difference between placing files and bootstrapping a
product.** Without it `orun new` writes the tree and stops: no repository, no
landing, no convergence watch, no probe. That is deliberate — it is what
makes the offline bootstrap in `testing/` possible with no workspace and no
provider.

`--resume` is safe to re-run from anywhere, a fresh container with a fresh
`--out` included: **phase state is derived from the tree, never stored.** A
phase whose files are present but branded derives as `drifted`, and
`--resume` leaves it placed rather than reverting the product's identity.

## 1b. Or phase by phase

| phase | what it lands | verified by |
|---|---|---|
| `01-product` | the repository, created and linked; the WHOLE product in one PR — intent, CI, tooling, identity, both apps and their tests; the brokered Cloudflare secrets (the deploy token, the account id) | its commit validated and planned in the box (as the PR and as the merge), then merged; the convergence green (the preview origin built, deployed and smoke-tested, then the host app with its origin); all four workers.dev URLs answering |
| `02-docs` | `ai/context/deployment.md` from probed facts; prod's promotion gate and dev's push lanes restored | the render's own probes, recorded; the commit checked in the box and merged |

```bash
orun new --blueprint repo-blueprint.yaml --out ~/sites/acme-builder --run-hooks \
  --phase 01-product --values ~/acme-builder.values.yaml
# … then 02-docs
```

`02-docs` reads the identity back from `.rebrand/values.json` in the placed
tree, but the blueprint's **required** inputs — `reponame`, `productname`,
`githuborg` — are validated before anything runs, so pass them every time (a
`--values` file is easier). The domain is not one of them: both apps go live
on workers.dev, and `productdomain` defaults to empty, which brands the
reserved placeholder `<reponame>.example.com` into `BASE_DOMAIN` for an owner
to replace when they attach domains (README, "Custom domains"). Pass
`--set productdomain=` only for a product that already has its domain.
The full guide, one page per phase: [docs/phases/README.md](docs/phases/README.md).

| flag | what it does |
|---|---|
| `--status` | derives and prints every phase's state and writes nothing. It parses the document, validates each hook against the action registry and compiles every template; it needs no credential and no network |
| `--phase <name>` | places exactly that phase; its `requires.phases` still gates |
| `--until <name>` | places every phase through that one and stops |

What lands in the product is PRODUCT-ONLY: both apps, their tests, its CI,
its tooling, its README, its `AGENTS.md` and its two context pages. None of
this repository's machinery (`.baseline/`, the blueprints, `tooling/rebrand`,
`tooling/bootstrap`, `tooling/catalog`, `hooks/`, `testing/`, `docs/phases/`,
`specs/`, `tasks/`, this file) ships, and no file that ships names one of
them. That
promise is a test: `testing/leak.test.sh` derives what every phase would
place and gates the set and its sources, and `testing/placement.test.sh`
gates the same rules over a placed, branded tree.

## 2. Why one landing is safe: the plan carries the order

The host app frames the preview origin, and its deploy's smoke checks that
the origin it was built with answers as the preview proxy — so the preview
must be live first. That order would once have needed a landing of its own.
It does not, because the product's plan holds it:

- `apps/web/component.yaml` declares `dependsOn: preview` with
  `mode: enforced`, and `modeRules` making it advisory on
  `github-pull-request`. On the merge the host's deploy waits for its
  environment's preview deploy; on a pull request nothing deploys, so
  nothing waits.
- Each build is told the other's origin, the sibling Worker's workers.dev
  URL in the same environment — both names are known at plan time, so
  neither build needs anything the other's deploy produces.

`testing/phases.test.sh` fails if the edge or either origin goes missing;
`testing/placement.test.sh` plans the product's own merge and asserts each
environment's preview lane runs before its host lane.

## 3. Headless / container mode

The blueprint's source is this repository (`sources: [{kind: dir, path: .}]`),
so the container contract is a shallow clone at a pinned tag plus two
tokens:

```bash
export ORUN_TOKEN=…          # orun auth, headless
export GITHUB_TOKEN=…        # fine-grained PAT (below)

git clone --depth 1 --branch <baseline-tag> https://github.com/sourceplane/v0-clone
cd v0-clone
orun new --blueprint repo-blueprint.yaml \
  --out /work/acme-builder --run-hooks --resume --progress json \
  --values /work/acme-builder.values.yaml
```

| requirement | detail |
|---|---|
| `GITHUB_TOKEN` | fine-grained PAT: **read** on this repository; on the PRODUCT's repository **contents write**, **pull-requests write**, **actions read+write** (`orun.run/watch@v1` resumes runs with `gh run rerun`), **checks read**; **repository create** on the owner if `01-product` creates it (or pre-create it — supported) |
| classic token caveat | a classic PAT or gh OAuth token also needs the `workflow` scope to push `.github/workflows/` |
| pinning | the clone's `--branch <tag>` pins everything: the blueprint, its modules and its hooks' scripts all come from that one commit |

## 4. After the product is live

- **Connect v0**: nothing to do for bring-your-own-key — each visitor saves
  their own key through the app's dialog. For one key for everyone, first
  put Cloudflare Access in front of both Workers (the product's README, its
  security warning), then store `V0_API_KEY` as the product's Orun secret
  per environment and deploy that environment by hand (Orunbase's Deploy
  button, or Run workflow on `ci.yml`): both builds hand it to their Worker
  as a Worker secret.
- **Change the app**: `apps/web/app` and `apps/web/components` (the host),
  `apps/preview/app` (the preview origin); the product's name is each app's
  `lib/site.ts`. Every merge to `main` redeploys.
- **Add sign-in**: replace `authorizeProxyRequest` (`apps/web/lib/proxy.ts`,
  `apps/preview/lib/authorize.ts`) with a session check.
- **Custom domains**: attach one to each Worker in Cloudflare — the preview
  proxy's on a different registrable domain from the host's — then set
  `V0_PREVIEW_PROXY_URL` and `V0_CLONE_ORIGIN` under the environment's `env:`
  in `intent.yaml` and redeploy both (the product's README, "Custom
  domains"). There is no domain phase: attaching a domain needs zone
  permissions the brokered `workers-deploy` token does not carry.
- **Refresh the record**: re-run `--phase 02-docs`; it is idempotent.

## 5. Testing this baseline

`.github/workflows/baseline.yml` runs three tiers on every pull request, and
each runs locally the same way:

```bash
for t in manifest phases coverage rebrand retouch bootstrap-defer; do bash testing/$t.test.sh; done
bash testing/leak.test.sh        # needs orun
bash testing/placement.test.sh   # needs orun >= ci.yml's pin, node, pnpm: the offline bootstrap and the product's own plan
bash testing/e2e.test.sh         # + network for pnpm: both apps built in their job trees, dry-deployed and served
```

The offline bootstrap (`testing/lib/bootstrap.sh`) places both phases in
order and finishes each with the blueprint's OWN `run:` hooks — read out of
`repo-blueprint.yaml`, not transcribed — so the retouch marker, the rebrand,
the re-tenant, the deferrals and their restore, and the deployment record
all run exactly as a real bootstrap runs them. Only the platform's typed
actions (task, repo, link, reconcile, land, watch, secrets,
probe) are stood in for, a landing becoming a commit, and the v0 API by a
stand-in (`testing/lib/fake-v0-api.py`) that answers the same paths with the
same auth and preview token. What no offline test can do is the platform's
half: the token minted, the deploys, the probes — and the real v0 API.

## 6. Cutting a baseline tag (maintainers)

Every product built from this repository resolves a `baseline-vN` tag, so
the tag is cut by a workflow rather than by hand:

```bash
gh workflow run tag.yml -f version=baseline-v1          # from main
gh workflow run tag.yml -f version=baseline-v1 -f ref=<sha>
```

It refuses a version that is not `baseline-v<N>` and a tag that already
exists: a baseline tag is never moved. Then move the registry row in
orun-cloud's `infra/baselines-registry/baselines.yaml` by pull request —
after the tag exists, because the registry's sync fetches `blueprint.yaml`
at the tag and refuses the whole catalogue if it 404s.

## Troubleshooting

| Symptom | Cause → fix |
|---|---|
| `01-product` parks: `waiting for github for <org>` | the workspace's GitHub connection is to another account. Connect the App installation on `<org>` (console → Integrations → GitHub), then `--resume` |
| `01-product` waits on the `providers` probe, then stops | Cloudflare is not connected. Connect it (console → Integrations), then re-run the phase — the probe is a wait, not a failure |
| `01-product` stops at `link` | the repository is not linked to the workspace and the credential cannot link it. Allow-list it (console → Settings → Git repos) and re-run the phase |
| Secret WRITE fails `not_found` while listings work | the API key's role is below admin; re-mint it with the admin role |
| deploy lane: Authentication error (10000) | the connection's token lacks Workers Scripts write; re-issue it, re-connect, re-run `01-product` |
| web lane waits, then shows as not run | that environment's preview deploy failed — read its lane; the host waits on it |
| web smoke fails on the proxy's `/api/health` | the preview Worker is not answering at the origin the host was built with: it failed to deploy, or `V0_PREVIEW_PROXY_URL` names a domain not attached to it yet |
| `land` stops: `the landing's own check failed — orun plan for …` | the product's tree does not plan — the line after it is orun's own error (an unknown component type, a composition that does not resolve). Nothing was pushed. Fix the tree (or the baseline) and re-run the phase |
| `land` waits on CI after all | the product's repository requires a status check on `main` (branch protection or a ruleset), so GitHub refused the early merge; the landing waits for the check as a `checks: ci` landing would, then merges |
| Convergence failed AFTER the PR merged; re-running lands nothing | expected on its own — the files are on main. Re-run the phase (`--phase 01-product`, `--redo 01-product`, or the console's Retry): its `retouch` hook gives the landing a diff and both apps and their tests re-plan |
| the app opens its key dialog | expected with no `V0_API_KEY`: each visitor saves their own key (After the product is live, above) |
| a preview says the key is missing, or answers 500 | the visitor's key reached the host but not the proxy: the dialog hands it on from the host's origin only, so a host on another origin than the proxy was built with (`V0_CLONE_ORIGIN`) is refused — redeploy the preview with the host's origin |
| The product's `intent.yaml` says `workspace: ws_SET_ME` | `orunWorkspace` was empty and the build ran outside a workspace; set it and re-run `01-product` |
| A bootstrap stopped before `02-docs`; prod no longer waits on stage | the gate is deferred, not dropped: run `02-docs`, or `node tooling/bootstrap/promotion.mjs --restore --file <product>/intent.yaml` |
| `✕ input "productname" is required` | all three required inputs (`reponame`, `productname`, `githuborg`) must be set on every invocation, single-phase ones included |
| `unknown flag: --phase`, `has no parameter "checks"`, `has no parameter "secrets"` or another parse error in the blueprint | the CLI is below the v2.88.0 floor |
| a build-app step: `Symlink apps/<app>/node_modules/next is invalid, it points out of the filesystem root` | the product's intent pins stack-tectonic ≥ 0.20.0, whose lane-scoped install links each job's node_modules out of its tree, which Next 16's Turbopack refuses. Pin 0.19.0 (`intent.yaml` says why) |
| the convergence reported green, then `verify` got 404 | a second workflow ran on the push to main and the watch took its run. Only `ci.yml` may run on a push to main |
