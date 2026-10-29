#!/usr/bin/env bash
# THE REBRAND WRITES EACH VALUE ONCE, AND WHAT IT WROTE STAYS WRITTEN.
#
# Drives the real tooling/rebrand/rebrand.mjs over one-file trees and compares
# the file. Each case is a shape this baseline's identity actually takes in the
# tree — the source link, the name seam in each app, both Workers' names in
# the components and the wrangler configs, the sibling origin each build
# inlines, the placeholder domain, a secret ref — beside the upstream's own
# identity, which it must leave alone (its `examples/v0-clone` links and the
# `V0_CLONE_ORIGIN` variable upstream named after itself) — and the
# survival cases run through three passes, so a value an earlier rebrand
# wrote (a re-run phase re-runs the rebrand over everything placed) comes
# out of every later one unchanged.
#
# The identity is PINNED (fixtures/baseline-identity.v0-clone.json)
# rather than read from .baseline/identity.json: what this tests is the engine,
# and its fixtures spell the identity out literally.
#
# Needs: node, git. No network.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
rebrand="$here/../tooling/rebrand/rebrand.mjs"
identity="$here/fixtures/baseline-identity.v0-clone.json"

fail=0
# check NAME VALUES-JSON FILE CONTENT WANT [PASSES]
check() {
  local name="$1" values="$2" file="$3" content="$4" want="$5" passes="${6:-1}"
  local tmp got out i
  tmp="$(mktemp -d)"
  git -C "$tmp" init -q
  mkdir -p "$tmp/$(dirname "$file")" "$tmp/.rebrand"
  printf '%s\n' "$content" > "$tmp/$file"
  printf '%s\n' "$values" > "$tmp/.rebrand/values.json"
  for ((i = 1; i <= passes; i++)); do
    git -C "$tmp" add -A
    if ! out="$(cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --values .rebrand/values.json --allow-dirty 2>&1)"; then
      echo "   ✕  $name: rebrand pass $i failed:" >&2
      printf '%s\n' "$out" | sed 's/^/        /' >&2
      fail=1
      rm -rf "$tmp"
      return
    fi
  done
  got="$(cat "$tmp/$file")"
  rm -rf "$tmp"
  if [ "$got" = "$want" ]; then
    echo "   ok  $name"
  else
    echo "   ✕  $name:" >&2
    echo "        got:  $got" >&2
    echo "        want: $want" >&2
    fail=1
  fi
}

acme='{"reponame":"acme-builder","productname":"Acme Builder","productdomain":"acme.dev","githuborg":"acme-inc","subdomain":"acme","orunWorkspace":"ws_79BDXAZQ"}'

echo "── rebrand: the product's own identity"
check "the source link names the product's owner and repository" \
  "$acme" docs/source.md \
  'Source: https://github.com/sourceplane/v0-clone' \
  'Source: https://github.com/acme-inc/acme-builder'
check "the host app's name seam takes the product's name" \
  "$acme" apps/web/lib/site.ts 'export const SITE_NAME = "My App Builder"' \
  'export const SITE_NAME = "Acme Builder"'
check "…and the preview origin's, the same rule" \
  "$acme" apps/preview/lib/site.ts 'export const SITE_NAME = "My App Builder"' \
  'export const SITE_NAME = "Acme Builder"'
check "…and stays a valid string for a name with an apostrophe and an ampersand" \
  '{"reponame":"sams-apps","productname":"Sam'"'"'s Apps & Notebooks","productdomain":"sam.dev"}' \
  apps/web/lib/site.ts 'export const SITE_NAME = "My App Builder"' \
  'export const SITE_NAME = "Sam'"'"'s Apps & Notebooks"'
check "a slug in prose is the product's" \
  "$acme" apps/web/lib/proxy.ts ' * v0-clone has no user accounts: every visitor shares the deployer'"'"'s v0' \
  ' * acme-builder has no user accounts: every visitor shares the deployer'"'"'s v0'

echo "── rebrand: the upstream's identity is left alone"
check "upstream's name in prose is its credit" \
  "$acme" apps/web/README.md 'The v0 clone'"'"'s host: Vercel'"'"'s v0 clone, on a Worker.' \
  'The v0 clone'"'"'s host: Vercel'"'"'s v0 clone, on a Worker.'
check "a link into upstream's examples/v0-clone keeps its path" \
  "$acme" apps/web/README.md 'Upstream: [vercel/v0-sdk `examples/v0-clone/apps/web`](https://github.com/vercel/v0-sdk/tree/main/examples/v0-clone/apps/web)' \
  'Upstream: [vercel/v0-sdk `examples/v0-clone/apps/web`](https://github.com/vercel/v0-sdk/tree/main/examples/v0-clone/apps/web)'
check "upstream's V0_CLONE_ORIGIN variable keeps its name" \
  "$acme" apps/preview/lib/origins.ts '  const configured = process.env.NEXT_PUBLIC_V0_CLONE_ORIGIN // V0_CLONE_ORIGIN' \
  '  const configured = process.env.NEXT_PUBLIC_V0_CLONE_ORIGIN // V0_CLONE_ORIGIN'

echo "── rebrand: both Workers"
check "the host's worker name is re-prefixed, the environment suffix kept" \
  "$acme" apps/web/component.yaml 'workerName: v0-clone-web' \
  'workerName: acme-builder-web'
check "…and the preview's" \
  "$acme" apps/preview/component.yaml 'workerName: v0-clone-preview' \
  'workerName: acme-builder-preview'
check "the wrangler config's worker name" \
  "$acme" apps/preview/wrangler.jsonc '  "name": "v0-clone-preview",' \
  '  "name": "acme-builder-preview",'
check "the environment URLs: worker name and subdomain" \
  "$acme" intent.yaml '    url: https://v0-clone-web-stage.your-workers-subdomain.workers.dev' \
  '    url: https://acme-builder-web-stage.acme.workers.dev'
check "the host's build inlines the product's preview Worker" \
  "$acme" apps/web/component.yaml \
  '    buildCommand: env -u V0_API_KEY NEXT_PUBLIC_V0_PREVIEW_PROXY_URL="${V0_PREVIEW_PROXY_URL:-https://v0-clone-preview-${ORUN_ENVIRONMENT}.your-workers-subdomain.workers.dev}" pnpm exec turbo run build --filter=@app/web' \
  '    buildCommand: env -u V0_API_KEY NEXT_PUBLIC_V0_PREVIEW_PROXY_URL="${V0_PREVIEW_PROXY_URL:-https://acme-builder-preview-${ORUN_ENVIRONMENT}.acme.workers.dev}" pnpm exec turbo run build --filter=@app/web'
check "…and the preview's the product's host Worker, under upstream's variable" \
  "$acme" apps/preview/component.yaml \
  '    buildCommand: env -u V0_API_KEY NEXT_PUBLIC_V0_CLONE_ORIGIN="${V0_CLONE_ORIGIN:-https://v0-clone-web-${ORUN_ENVIRONMENT}.your-workers-subdomain.workers.dev}" pnpm exec turbo run build --filter=@app/preview' \
  '    buildCommand: env -u V0_API_KEY NEXT_PUBLIC_V0_CLONE_ORIGIN="${V0_CLONE_ORIGIN:-https://acme-builder-web-${ORUN_ENVIRONMENT}.acme.workers.dev}" pnpm exec turbo run build --filter=@app/preview'
check "the Worker the build hands its secret to, per environment" \
  "$acme" apps/preview/component.yaml \
  '    buildCommand: node ../../tooling/wire/worker-secrets.mjs --secret V0_API_KEY --worker "v0-clone-preview-${ORUN_ENVIRONMENT}" --config wrangler.jsonc' \
  '    buildCommand: node ../../tooling/wire/worker-secrets.mjs --secret V0_API_KEY --worker "acme-builder-preview-${ORUN_ENVIRONMENT}" --config wrangler.jsonc'

echo "── rebrand: the domain, the slug, the secrets"
check "the placeholder domain is the product's domain, not a renamed slug" \
  "$acme" intent.yaml '      BASE_DOMAIN: v0-clone.example.com' \
  '      BASE_DOMAIN: acme.dev'
check "no domain given: the reserved placeholder, for an owner to replace later" \
  '{"reponame":"acme-builder","productname":"Acme Builder","githuborg":"acme-inc","subdomain":"acme"}' \
  intent.yaml '      BASE_DOMAIN: v0-clone.example.com' \
  '      BASE_DOMAIN: acme-builder.example.com'
check "an empty domain is no domain" \
  '{"reponame":"acme-builder","productname":"Acme Builder","productdomain":""}' \
  intent.yaml '      BASE_DOMAIN: v0-clone.example.com' \
  '      BASE_DOMAIN: acme-builder.example.com'
check "the repo slug" \
  "$acme" package.json '  "name": "v0-clone",' \
  '  "name": "acme-builder",'
check "the optional key's secret ref names the product's workspace and project" \
  "$acme" apps/web/component.yaml \
  '    V0_API_KEY: "secret://v0-clone/v0-clone/{{ .environment }}/V0_API_KEY"' \
  '    V0_API_KEY: "secret://ws_79BDXAZQ/acme-builder/{{ .environment }}/V0_API_KEY"'
check "org-owned identity is not renamed" \
  "$acme" intent.yaml 'apiVersion: sourceplane.io/v1 # mail ops@sourceplane.ai' \
  'apiVersion: sourceplane.io/v1 # mail ops@sourceplane.ai'
check "without githuborg the source link keeps the baseline's owner" \
  '{"reponame":"acme-builder","productname":"Acme Builder","productdomain":"acme.dev"}' \
  docs/source.md 'Source: https://github.com/sourceplane/v0-clone' \
  'Source: https://github.com/sourceplane/acme-builder'

echo "── rebrand: a written value is not rewritten, in any later pass"
contains='{"reponame":"v0-clone-2","productname":"My App Builder 2","productdomain":"v0-clone.example.com.au","githuborg":"sourceplane","subdomain":"your-workers-subdomain-2"}'
check "a repo slug containing the baseline's slug survives three passes" \
  "$contains" package.json '  "name": "v0-clone",' \
  '  "name": "v0-clone-2",' 3
check "a worker name built on it survives three passes" \
  "$contains" apps/web/component.yaml 'workerName: v0-clone-web' \
  'workerName: v0-clone-2-web' 3
check "…and the preview's" \
  "$contains" apps/preview/component.yaml 'workerName: v0-clone-preview' \
  'workerName: v0-clone-2-preview' 3
check "a domain containing the baseline's domain survives three passes" \
  "$contains" intent.yaml 'BASE_DOMAIN: v0-clone.example.com' \
  'BASE_DOMAIN: v0-clone.example.com.au' 3
check "a subdomain containing the placeholder survives three passes" \
  "$contains" apps/web/component.yaml 'workersDevSubdomain: your-workers-subdomain' \
  'workersDevSubdomain: your-workers-subdomain-2' 3
check "a product name containing the baseline's name survives three passes" \
  "$contains" apps/web/lib/site.ts 'export const SITE_NAME = "My App Builder"' \
  'export const SITE_NAME = "My App Builder 2"' 3

# --verify runs in every phase. Without the product's values it cannot tell
# the product's own identity from a leftover; with them it can. A real
# leftover must fail it either way.
verify() { # NAME VALUES FILE CONTENT WANT(pass|fail) [--values]
  local name="$1" values="$2" file="$3" content="$4" want="$5" withvalues="${6:-}" tmp got
  tmp="$(mktemp -d)"
  git -C "$tmp" init -q
  mkdir -p "$tmp/$(dirname "$file")" "$tmp/.rebrand"
  printf '%s\n' "$content" > "$tmp/$file"
  printf '%s\n' "$values" > "$tmp/.rebrand/values.json"
  git -C "$tmp" add -A
  if (cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --verify ${withvalues:+--values .rebrand/values.json} >/dev/null 2>&1); then got=pass; else got=fail; fi
  rm -rf "$tmp"
  if [ "$got" = "$want" ]; then echo "   ok  $name"; else echo "   ✕  $name: --verify ${got}ed, want $want" >&2; fail=1; fi
}
echo "── rebrand --verify: the product's own identity is not residue"
verify "given the values, a slug containing the baseline's passes" \
  "$contains" package.json '"name": "v0-clone-2"' pass --values
verify "without them it cannot know, and fails" \
  "$contains" package.json '"name": "v0-clone-2"' fail
verify "given the values, a real leftover still fails" \
  "$acme" package.json '"name": "v0-clone"' fail --values
verify "a leftover worker name fails" \
  "$acme" apps/web/wrangler.jsonc '"name": "v0-clone-web",' fail --values
verify "…the preview's too" \
  "$acme" apps/preview/wrangler.jsonc '"name": "v0-clone-preview",' fail --values
verify "upstream's links are not residue" \
  "$acme" apps/web/README.md '(https://github.com/vercel/v0-sdk/tree/main/examples/v0-clone/apps/web)' pass --values
verify "upstream's V0_CLONE_ORIGIN is not residue" \
  "$acme" apps/preview/lib/origins.ts 'process.env.NEXT_PUBLIC_V0_CLONE_ORIGIN' pass --values
verify "any other variable on the baseline's prefix is" \
  "$acme" apps/preview/lib/origins.ts 'process.env.V0_CLONE_TOKEN' fail --values
verify "a leftover code identifier fails (no rule renames it — so nothing may spell it)" \
  "$acme" apps/web/app/x.ts 'export class V0Clone {}' fail --values
verify "a clean product passes" \
  "$acme" package.json '"name": "acme-builder"' pass --values

echo "── rebrand: a residue it cannot rename fails the rebrand itself"
tmp="$(mktemp -d)"; git -C "$tmp" init -q; mkdir -p "$tmp/.rebrand" "$tmp/apps/web"
printf '%s\n' "$acme" > "$tmp/.rebrand/values.json"
printf 'const x = "V0_CLONE_TOKEN"\n' > "$tmp/apps/web/x.ts"
git -C "$tmp" add -A
if (cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --values .rebrand/values.json --allow-dirty >/dev/null 2>&1); then
  echo "   ✕  an unrenamable env-var prefix passed the rebrand" >&2; fail=1
else
  echo "   ok  an unrenamable env-var prefix fails the rebrand, naming the file"
fi
rm -rf "$tmp"

[ "$fail" -eq 0 ] || exit 1
echo "rebrand.test.sh: ok"
