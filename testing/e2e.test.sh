#!/usr/bin/env bash
# TIER 2 — the product a bootstrap produces builds, deploys (dry) and serves.
#
# placement.test.sh proves the tree a bootstrap ends with is the right tree.
# This proves it WORKS, by doing to it what its own pipelines will:
#
#   1. at the 01-product landing (the commit its one pull request merges),
#      install with the lockfile the product ships, typecheck, lint and test
#      (both suites), and check none of it rewrote a tracked file. The
#      landing's own PR runs `plan` alone (an `orun/BASE-*` branch), so THIS
#      is where a product those steps refuse is caught: before the tag, not
#      after a build has merged it;
#   2. each app's stage lane, its steps rendered by `orun plan` in the product
#      for a pull request (the verify profile: the deploy profile has no dry
#      run) — `verify-app-structure`, `build-app` (the component's
#      buildCommand), `verify-build-output` and `deploy-dry-run` (`wrangler
#      deploy --dry-run --name <reponame>-<app>-stage`). They run IN THE TREE
#      THE RUNNER STAGES for the job (testing/lib/stage-job.py), one per app,
#      with the dependency layout the pinned composition produces. Each build
#      is first shown to default its sibling's origin to that Worker's
#      workers.dev URL in stage, then built with the origin an owner's `env:`
#      would set (here the sibling served on localhost below), which must be
#      the one inlined. The build runs with a v0 key in its environment, as a
#      deploy lane with the secret stored would: it must never reach the
#      bundle (the build strips it), and the Worker-secrets step must say it
#      goes to `<reponame>-<app>-stage` from the deploy lane — a verify lane
#      holds no Cloudflare credential and pushes nothing. Each dry run must
#      fit Workers Free (3 MiB gzipped);
#   3. serve both built Workers with `wrangler dev`, their v0 calls pointed at
#      a stand-in v0 API (testing/lib/fake-v0-api.py, through the apps'
#      V0_API_BASE_URL), and run each component's OWN `smokeCommand` against
#      it, verbatim — the checks the real deploys end with, the host's
#      reaching the preview origin it was built with — and then what the
#      product promises: the host's title carries the product's name; with no
#      key the chat is refused by v0 and the dialog's key check refuses a
#      wrong key; a right one is kept in an HTTP-only cookie and the chats
#      list through it; a foreign origin is refused by the same-origin seam;
#      the proxy takes the key only from the host's origin (CORS), keeps its
#      own copy, and serves a chat's preview fetched with v0's preview token;
#      a preview's own absolute paths are sent back under it; the host's
#      assets are served and an unknown path is a 404.
#
# What it cannot do is the platform's half: create the repository, mint the
# brokered Cloudflare token, push the secrets, deploy for real and probe
# workers.dev — nor call the real v0 API.
#
# Needs: orun, node, pnpm, python3 (+PyYAML), git, curl, and the network for
# `pnpm install` and the build's Google Font (or a warm store). Several
# minutes: three installs and two builds. E2E_KEEP=1 keeps the scratch tree.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
# shellcheck source=lib/bootstrap.sh
source "$here/lib/bootstrap.sh"

for bin in orun node pnpm python3 git curl; do
  command -v "$bin" >/dev/null || { echo "e2e.test.sh needs $bin on PATH" >&2; exit 1; }
done

scratch="$(mktemp -d)"
groups=()
# wrangler dev runs under pnpm, node and workerd processes; a TERM to the
# first does not reach the rest, and waiting on it then never returns. So each
# server is started as its own process group (setsid) and the whole group is
# stopped — only the groups this script started.
cleanup() {
  local g
  for g in "${groups[@]}"; do
    kill -TERM -- "-$g" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 -- "-$g" 2>/dev/null || break; sleep 0.5; done
    kill -KILL -- "-$g" 2>/dev/null || true
  done
  if [ -n "${E2E_KEEP:-}" ]; then echo "kept: $scratch" >&2; else rm -rf "$scratch"; fi
}
trap cleanup EXIT
values="$here/fixtures/acme.json"
repo="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['reponame'])" "$values")"
sub="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['subdomain'])" "$values")"
export CI=1 WRANGLER_SEND_METRICS=false NEXT_TELEMETRY_DISABLED=1 TURBO_TELEMETRY_DISABLED=1
free_port() { python3 -c "import socket;s=socket.socket();s.bind(('127.0.0.1',0));print(s.getsockname()[1]);s.close()"; }
web_port="$(free_port)"; preview_port="$(free_port)"
web_url="http://localhost:$web_port"; preview_url="http://localhost:$preview_port"

# The landing's own checks, step for step. A product's pull requests verify
# through ci.yml's lanes (both apps built — Next's build type-checks them —
# and dry-deployed per environment, both suites run on dev), which do not
# lint, so before a tag THIS is where that is held. The builds are step 2's,
# in the lanes' own job trees.
LANDING_CHECKS=(
  "pnpm install --frozen-lockfile"
  "pnpm typecheck"
  "pnpm lint"
  "pnpm test"
  "git diff --exit-code"
)
checks() { # DIR LOG
  local dir="$1" log="$2" cmd
  for cmd in "${LANDING_CHECKS[@]}"; do
    echo "   \$ $cmd" | tee -a "$log"
    if ! (cd "$dir" && bash -c "$cmd") >> "$log" 2>&1; then
      echo "FAIL: \`$cmd\` failed in $dir" >&2; tail -40 "$log" >&2; return 1
    fi
  done
}

echo "── the offline bootstrap (testing/lib/bootstrap.sh)"
tree="$scratch/$repo"
bootstrap_offline "$root" "$tree" "$values" "$scratch/logs" > "$scratch/bootstrap.log" 2>&1 || {
  echo "FAIL: the offline bootstrap stopped" >&2; tail -40 "$scratch/bootstrap.log" >&2; exit 1; }
echo "   2 phases placed and landed"
s01="$(git -C "$tree" rev-parse HEAD~1)"

# ── 1. the product's one pull request ──────────────────────────────────────
echo "── 01-product's landing: install, typecheck, lint, test"
git -C "$tree" worktree add -q "$scratch/at-01" "$s01"
checks "$scratch/at-01" "$scratch/checks-01.log"
suites="$(sed 's/\x1b\[[0-9;]*m//g' "$scratch/checks-01.log" | grep -Ec '^@app/(web|preview)-tests:test: +Tests +[0-9]+ passed' || true)"
[ "$suites" = 2 ] || { echo "FAIL: $suites of the two suites reported passing tests" >&2; exit 1; }
# Done with it; the disk is shared.
git -C "$tree" worktree remove --force "$scratch/at-01"

# ── 2. each app's stage lane, in the job's own tree ───────────────────────
# A pull request that changes both apps: the lanes `orun plan` gives it.
git -C "$tree" checkout -q -b e2e-pr
echo "<!-- a change to the host app -->" >> "$tree/apps/web/README.md"
echo "<!-- a change to the preview proxy -->" >> "$tree/apps/preview/README.md"
git -C "$tree" -c user.email=e2e@example.invalid -c user.name=e2e commit -qam "a pull request"
(cd "$tree" && orun plan --intent intent.yaml --trigger github-pull-request --changed \
   --base main --head HEAD --env stage --output "$scratch/plan.json") > "$scratch/plan.log" 2>&1 \
  || { echo "FAIL: orun plan" >&2; tail -15 "$scratch/plan.log" >&2; exit 1; }

# The v0 key a deploy lane with the secret stored resolves (optionalSecretEnv):
# a marker no source carries, so a bundle that held it would say so.
key_marker="v0_e2e_$(python3 -c 'import secrets;print(secrets.token_hex(12))')"

lane() { # APP OVERRIDE-VAR OVERRIDE-VALUE INLINED-VAR SIBLING
  local app="$1" ovar="$2" oval="$3" ivar="$4" sibling="$5" steps work step gz
  steps="$scratch/steps-$app"
  echo "── the $app stage lane: verify-app-structure, build-app, verify-build-output, deploy-dry-run"
  python3 - "$scratch/plan.json" "$steps" "$app" <<'PY'
import json, pathlib, sys
plan = json.load(open(sys.argv[1]))
out = pathlib.Path(sys.argv[2]); out.mkdir()
job = next(j for j in plan["jobs"] if j["component"] == sys.argv[3] and j["environment"] == "stage")
for s in job["steps"]:
    if s["id"] in ("verify-app-structure", "build-app", "verify-build-output", "deploy-dry-run"):
        (out / f"{s['id']}.sh").write_text(s.get("run") or "")
    if s["id"] == "install-workspace-dependencies":
        (out / "install.sh").write_text(s.get("run") or "")
        (out / "install.wd").write_text(s.get("working-directory") or ".")
        (out / "install.scope").write_text(s.get("scope") or "job")
(out / "path").write_text(job.get("path") or f"apps/{sys.argv[3]}")
for k, v in (job.get("env") or {}).items():
    (out / "env").open("a").write(f"export {k}={json.dumps(v)}\n")
(out / "secrets").write_text("\n".join(r["asEnv"] for r in job.get("secretRefs") or []))
PY
  grep -qx V0_API_KEY "$steps/secrets" || { echo "FAIL: the $app lane does not resolve V0_API_KEY" >&2; return 1; }
  # The default origin: with nothing in the environment, the buildCommand's
  # own expansion is the sibling's Worker in this environment.
  python3 - "$steps/build-app.sh" "$ivar" > "$steps/origin.sh" <<'PY'
import re, sys
run, var = open(sys.argv[1]).read(), sys.argv[2]
m = re.search(r'(env -u V0_API_KEY %s="[^"]*")' % re.escape(var), run)
if not m:
    sys.exit(f"the build does not set {var}")
print(f"{m.group(1)} printenv {var}")
PY
  local want="https://${repo}-${sibling}-stage.${sub}.workers.dev" got
  got="$(env -u "$ovar" ORUN_ENVIRONMENT=stage bash "$steps/origin.sh")"
  [ "$got" = "$want" ] || { echo "FAIL: $app's build defaults $ivar to $got, not $want" >&2; return 1; }
  got="$(env "$ovar=$oval" ORUN_ENVIRONMENT=stage bash "$steps/origin.sh")"
  [ "$got" = "$oval" ] || { echo "FAIL: $app's build ignores $ovar ($got)" >&2; return 1; }
  echo "   $ivar: $want by default, the environment's $ovar when set"

  # The job's private tree, staged as orun stages it. The source checkout
  # carries no build output, and its dependencies are what the pinned
  # composition says: a lane-scoped install ran once in the source tree and
  # is linked in, or the job installs its own.
  work="$tree/.orun/runs/e2e/$app.stage.verify-deploy/work"
  [ -f "$steps/install.sh" ] || { echo "FAIL: the $app lane has no install step" >&2; return 1; }
  if [ "$(cat "$steps/install.scope")" = lane ]; then
    (cd "$tree" && bash -e "$steps/install.sh") > "$scratch/install-$app.log" 2>&1 \
      || { echo "FAIL: the $app lane's install step" >&2; tail -30 "$scratch/install-$app.log" >&2; return 1; }
    python3 "$here/lib/stage-job.py" "$tree" "$work" --shared-deps
    [ -L "$work/node_modules" ] || { echo "FAIL: the staged tree's node_modules is not the lane's symlink" >&2; return 1; }
    echo "   staged: $(realpath --relative-to="$tree" "$work"); install scope: lane — node_modules → the source tree's"
  else
    python3 "$here/lib/stage-job.py" "$tree" "$work"
    echo "   staged: $(realpath --relative-to="$tree" "$work"); install scope: job — installing inside it"
    echo "   ▸ install-workspace-dependencies"
    (cd "$work/$(cat "$steps/path")/$(cat "$steps/install.wd")" && bash -e "$steps/install.sh") \
      > "$scratch/install-$app.log" 2>&1 || { echo "FAIL: the $app lane's install step" >&2; tail -30 "$scratch/install-$app.log" >&2; return 1; }
    [ -d "$work/node_modules" ] && [ ! -L "$work/node_modules" ] \
      || { echo "FAIL: the job's install did not land inside its own tree" >&2; return 1; }
  fi
  [ ! -e "$work/apps/$app/.open-next" ] || { echo "FAIL: the staged tree carries build output" >&2; return 1; }
  for step in verify-app-structure build-app verify-build-output deploy-dry-run; do
    [ -f "$steps/$step.sh" ] || { echo "FAIL: the $app stage verify lane has no $step step" >&2; return 1; }
    echo "   ▸ $step"
    # The runner's per-job environment: the job's env (intent environment
    # `env:`, here with the owner's origin added), its resolved secret, and
    # ORUN_ENVIRONMENT; the step runs in the component's directory.
    if ! (cd "$work/$(cat "$steps/path")" && \
          { [ -f "$steps/env" ] && source "$steps/env"; true; } && \
          export "$ovar=$oval" V0_API_KEY="$key_marker" ORUN_ENVIRONMENT=stage && \
          bash -e "$steps/$step.sh") > "$scratch/$app-$step.log" 2>&1; then
      echo "FAIL: the $app lane's $step step" >&2; tail -40 "$scratch/$app-$step.log" >&2; return 1
    fi
  done
  if grep -rlF "$key_marker" "$work/apps/$app/.open-next" "$work/apps/$app/.next" 2>/dev/null | head -1 | grep -q .; then
    echo "FAIL: the v0 key reached $app's build output" >&2; grep -rlF "$key_marker" "$work/apps/$app/.open-next" "$work/apps/$app/.next" | head -5 >&2; return 1
  fi
  grep -q "V0_API_KEY reach $repo-$app-stage from the deploy lane" "$scratch/$app-build-app.log" \
    || { echo "FAIL: $app's build did not hand the v0 key on to the deploy lane's secrets step" >&2; grep "worker-secrets" "$scratch/$app-build-app.log" >&2; return 1; }
  grep -rqF "$oval" "$work/apps/$app/.open-next" \
    || { echo "FAIL: $app's bundle does not carry the origin it was built with ($oval)" >&2; return 1; }
  gz="$(sed -n 's/.*Total Upload: .* gzip: \([0-9.]*\) KiB.*/\1/p' "$scratch/$app-deploy-dry-run.log" | head -1)"
  python3 -c "import sys; sys.exit(0 if float(sys.argv[1]) < 3072 else 1)" "${gz:-99999}" \
    || { echo "FAIL: the $app Worker is ${gz:-?} KiB gzipped — over Workers Free's 3 MiB" >&2; return 1; }
  echo "   the v0 key never reached the bundle, and goes to $repo-$app-stage from the deploy lane;"
  echo "   $oval inlined; the dry run accepts it at ${gz} KiB gzipped"
}
lane preview V0_CLONE_ORIGIN "$web_url" NEXT_PUBLIC_V0_CLONE_ORIGIN web
lane web V0_PREVIEW_PROXY_URL "$preview_url" NEXT_PUBLIC_V0_PREVIEW_PROXY_URL preview
work_preview="$tree/.orun/runs/e2e/preview.stage.verify-deploy/work/apps/preview"
work_web="$tree/.orun/runs/e2e/web.stage.verify-deploy/work/apps/web"

# ── 3. serve both, and smoke them as the deploys do ───────────────────────
echo "── wrangler dev over both built Workers, their v0 calls on the stand-in v0 API"
v0_key="v0_live_e2e_$(python3 -c 'import secrets;print(secrets.token_hex(8))')"
setsid python3 "$here/lib/fake-v0-api.py" "$scratch/v0.port" --key "$v0_key" --chat chat_e2e \
  > /dev/null 2> "$scratch/v0.log" < /dev/null &
groups+=("$!")
for _ in $(seq 1 50); do [ -s "$scratch/v0.port" ] && break; sleep 0.1; done
v0_port="$(cat "$scratch/v0.port")"
serve() { # APP-DIR PORT LOG
  [ ! -e "$1/.dev.vars" ] || { echo "FAIL: the staged tree carries a .dev.vars" >&2; return 1; }
  (cd "$1" && exec setsid pnpm exec wrangler dev --ip 127.0.0.1 --port "$2" --inspector-port "$(free_port)" \
     --var "V0_API_BASE_URL:http://127.0.0.1:$v0_port" --persist-to "$scratch/state-$2" \
     --show-interactive-dev-session=false) > "$3" 2>&1 < /dev/null &
  groups+=("$!")
}
serve "$work_preview" "$preview_port" "$scratch/dev-preview.log"
serve "$work_web" "$web_port" "$scratch/dev-web.log"
for pair in "$preview_url|$scratch/dev-preview.log" "$web_url|$scratch/dev-web.log"; do
  url="${pair%%|*}"; log="${pair#*|}"
  for _ in $(seq 1 120); do
    curl -s -o /dev/null "$url/api/health" && break
    sleep 1
  done
  curl -s -o /dev/null "$url/api/health" || { echo "FAIL: wrangler dev never answered at $url" >&2; tail -30 "$log" >&2; exit 1; }
done

for app in preview web; do
  url="$preview_url"; [ "$app" = web ] && url="$web_url"
  echo "   ▸ $app's own smokeCommand, DEPLOYED_URL=$url"
  smoke="$(python3 -c "import yaml,sys;print(yaml.safe_load(open(sys.argv[1]))['spec']['parameters']['smokeCommand'])" "$tree/apps/$app/component.yaml")"
  DEPLOYED_URL="$url" bash -c "$smoke" || { echo "FAIL: the $app deploy's smoke refused the product" >&2; tail -20 "$scratch/dev-$app.log" >&2; exit 1; }
done

echo "   ▸ the key flow, the proxied preview, the seams and the assets"
routes_failed() {
  echo "FAIL: the routes; wrangler dev said:" >&2; tail -25 "$scratch/dev-web.log" >&2; tail -25 "$scratch/dev-preview.log" >&2
  echo "the stand-in v0 API saw:" >&2; tail -20 "$scratch/v0.log" >&2; exit 1
}
python3 - "$web_url" "$preview_url" "$values" "$v0_key" "$scratch/v0.log" <<'PY' || routes_failed
import html, json, re, sys, urllib.error, urllib.request
web, preview, values, key, v0log = sys.argv[1], sys.argv[2], json.load(open(sys.argv[3])), sys.argv[4], sys.argv[5]
name, repo = values["productname"], values["reponame"]
problems = []
def bad(m): problems.append(m)

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k):
        return None
opener = urllib.request.build_opener(NoRedirect)
def req(method, url, body=None, headers=None):
    data = json.dumps(body).encode() if body is not None else None
    hdrs = {"content-type": "application/json"} if data is not None else {}
    r = urllib.request.Request(url, data=data, method=method, headers={**hdrs, **(headers or {})})
    try:
        with opener.open(r, timeout=60) as resp:
            return resp.status, resp.headers, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.headers, e.read()
def cookie(headers, name):
    # The cookies are Secure (a production build), so no client jar sends them
    # over http://localhost; they are read and sent back by hand.
    for v in headers.get_all("set-cookie") or []:
        m = re.match(rf"\s*{re.escape(name)}=([^;]*)", v)
        if m:
            return m.group(1), v
    return None, None
def js(b):
    try:
        return json.loads(b or b"{}")
    except ValueError:
        return {}

# ── the host app ──
s, _, b = req("GET", web + "/")
page = b.decode("utf-8", "replace")
if s != 200 or "</html>" not in page:
    bad(f"the host's / answered {s}")
title = re.search(r"<title>(.*?)</title>", page, re.S)
if not title or html.unescape(title.group(1)) != name:
    bad(f"the host's <title> is {title and title.group(1)!r}, not {name!r}")
if "v0-clone" in page:
    bad("the host's page still carries the baseline's slug")
s, _, b = req("GET", web + "/api/health")
h = js(b)
if s != 200 or h != {"ok": True, "app": "web", "previewProxy": preview, "v0ApiKey": "browser"}:
    bad(f"the host's /api/health answered {s} {h}")

# No key anywhere: v0 refuses the call, and the host says so.
s, _, b = req("GET", web + "/api/chats")
if s != 401:
    bad(f"/api/chats with no key answered {s}: {b[:160]!r}")
# The dialog's key check: a wrong key is v0's 401, and keeps no cookie.
s, hd, b = req("PUT", web + "/api/settings/api-key", {"apiKey": "v0_wrong"}, {"origin": web})
if s != 401 or cookie(hd, "v0-api-key")[0]:
    bad(f"a wrong key answered {s} {b[:120]!r}")
s, hd, b = req("PUT", web + "/api/settings/api-key", {"apiKey": key}, {"origin": web})
host_cookie, raw = cookie(hd, "v0-api-key")
if s != 200 or js(b) != {"configured": True} or host_cookie != key or "httponly" not in (raw or "").lower():
    bad(f"the right key answered {s} {b[:120]!r}, cookie {raw!r}")
s, _, b = req("GET", web + "/api/chats", headers={"cookie": f"v0-api-key={key}"})
if s != 200 or js(b).get("chats") != []:
    bad(f"/api/chats with the key answered {s}: {b[:160]!r}")
# The same-origin seam: a foreign origin is refused before any v0 call.
s, _, b = req("GET", web + "/api/chats", headers={"cookie": f"v0-api-key={key}", "origin": "https://evil.example"})
if s != 403:
    bad(f"/api/chats from a foreign origin answered {s}")
for path, want, ctype in (("/acme-logo.svg", 200, "image/svg+xml"), ("/no-such-page", 404, "text/html")):
    s, hd, _ = req("GET", web + path)
    if s != want or not (hd.get("content-type") or "").startswith(ctype):
        bad(f"the host's {path} answered {s} {hd.get('content-type')}, want {want} {ctype}")

# ── the preview proxy ──
s, _, b = req("GET", preview + "/api/health")
h = js(b)
if s != 200 or h != {"ok": True, "app": "preview", "cloneOrigin": web, "v0ApiKey": "browser"}:
    bad(f"the proxy's /api/health answered {s} {h}")
s, _, b = req("GET", preview + "/")
if s != 200 or name not in html.unescape(b.decode("utf-8", "replace")):
    bad(f"the proxy's own page answered {s} without the product's name")
# The key route: CORS for the host's origin only.
s, hd, _ = req("OPTIONS", preview + "/api/api-key", headers={"origin": web, "access-control-request-method": "PUT"})
if s != 204 or hd.get("access-control-allow-origin") != web or hd.get("access-control-allow-credentials") != "true":
    bad(f"the preflight from the host answered {s} {dict(hd)}")
for method in ("OPTIONS", "PUT"):
    s, hd, _ = req(method, preview + "/api/api-key", {"apiKey": key} if method == "PUT" else None,
                   {"origin": "https://evil.example"})
    if s != 403 or hd.get("access-control-allow-origin"):
        bad(f"{method} /api/api-key from a foreign origin answered {s}")
s, hd, b = req("PUT", preview + "/api/api-key", {"apiKey": key}, {"origin": web})
proxy_name = "__Host-v0-preview-api-key"
proxy_cookie, raw = cookie(hd, proxy_name)
if s != 200 or proxy_cookie != key or hd.get("access-control-allow-origin") != web:
    bad(f"the proxy's key route answered {s} {b[:120]!r}, cookie {raw!r}")
# A chat's preview, fetched with the key and v0's preview token, served here.
chat = "/api/v0-preview/chat_e2e/"
s, _, b = req("GET", preview + chat)
if s == 200 and b"Hello from the preview" in b:
    bad("the proxy served a preview with no key")
s, hd, b = req("GET", preview + chat, headers={"cookie": f"{proxy_name}={key}"})
if s != 200 or b"Hello from the preview" not in b:
    bad(f"the proxied preview answered {s}: {b[:160]!r}")
# The preview's own absolute paths come back under it (proxy.ts).
s, hd, _ = req("GET", preview + "/assets/app.js", headers={"referer": preview + chat})
if s != 307 or not (hd.get("location") or "").endswith("/api/v0-preview/chat_e2e/assets/app.js"):
    bad(f"a preview's absolute asset answered {s} → {hd.get('location')!r}")
seen = open(v0log).read()
for line in ("GET /v2/chats", "GET /v2/chats/chat_e2e/preview", "GET /\n"):
    if line not in seen:
        bad(f"the stand-in v0 API never saw {line.strip()!r}")

if problems:
    for p in problems:
        print(f"  ✕ {p}", file=sys.stderr)
    sys.exit(1)
print("   the host: its name, health ok; no key → v0's 401; a wrong key refused, the right one kept HTTP-only,")
print("   the chats listed through it, a foreign origin 403; the assets and a 404")
print("   the proxy: health ok; the key taken from the host's origin only (CORS), its own cookie;")
print("   a chat's preview served with v0's token, none without a key; absolute paths sent back under it")
PY

echo "e2e.test.sh: ok"
