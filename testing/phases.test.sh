#!/usr/bin/env bash
# The phases in `repo-blueprint.yaml` must be the phases the bootstrap runs,
# placing what they are meant to place, saying what they are, and naming only
# what the engine can resolve.
#
# The partition below is the bootstrap's order, written down a second time on
# purpose. It is the one-landing shape (cirrus-baseline v22): `01-product`
# places EVERY module and is the one phase that deploys; `02-docs` places
# nothing. The order that used to need separate landings is carried by the
# plan instead, and this file checks the edge that carries it: the host app
# frames the preview origin and its smoke checks that origin answers, so on a
# merge to main `web` waits for `preview` in each environment — and each
# build is told its sibling Worker's origin. A module that drifts into another
# phase, or an edge that goes missing, fails at landing time, live, with
# nothing in this repository having looked wrong.
#
# And the shape that keeps a bootstrap fast (orun >= v2.88.0): the run-level
# task set-up runs in the background, each phase finds its task just before
# its landing, each landing checks its commit here (`checks: local`), and the
# convergence watch reads every few seconds.
#
# Adapted from sourceplane/cirrus-baseline's testing/phases.test.sh: the
# narration rules and the hook-only rule are Cirrus's, unchanged.
#
# bash + python3 + PyYAML. No network, no fakes, no credential.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"

echo "── repo-blueprint.yaml phases against what the bootstrap runs"
python3 - "$root" <<'PY'
import pathlib, re, sys

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required for the phase contract test (pip install pyyaml)")

root = pathlib.Path(sys.argv[1])
problems = []
def bad(m): problems.append(m)

bp = yaml.safe_load((root / "repo-blueprint.yaml").read_text())
phases = bp.get("phases") or []
if not phases:
    sys.exit("repo-blueprint.yaml declares no phases — this check has gone blind")

PARTITION = {
    "01-product": ["ai-deployment", "ai-operations", "discovery-roots",
                   "github-workflows", "preview", "preview-tests", "rebrand-values", "root-agents",
                   "root-gitignore", "root-intent", "root-package-json", "root-pnpm-lock",
                   "root-pnpm-workspace", "root-readme", "root-turbo", "tooling-eslint",
                   "tooling-tsconfig", "tooling-wire", "vscode", "web", "web-tests"],
    "02-docs": [],
}
HOOK_ONLY = {"02-docs"}
# The phases that DEPLOY, and so must give a re-run something to land.
DEPLOYS = {"01-product"}
# Each phase's pre, post and await hooks, in order — the one-landing recipe.
# The brokered keys are one `secrets` reconcile. No phase has a `pre` hook:
# the task is found in `post`, just before the landing, so that everything
# before it runs beside the background task set-up. There is no wiring to
# await: this product has no data plane.
PRE = {"01-product": [], "02-docs": []}
POST = {
    "01-product": ["retouch", "git-init", "stage", "rebrand", "orun-workspace", "work-tree",
                   "promotion", "dev-lanes", "restage", "rebrand-verify",
                   "repo", "link", "secrets", "task", "land"],
    "02-docs": ["promotion", "dev-lanes", "render", "task", "land"],
}
AWAIT = {"01-product": ["converge", "verify"], "02-docs": []}

by_name = {p["name"]: p for p in phases}
names = [p["name"] for p in phases]

# ── the order IS the execution order ──────────────────────────────────────
if names != sorted(names):
    bad(f"phases are not in execution order: {names}. The numbered name IS the "
        f"order; a phase out of sequence is a barrier in the wrong place.")
if names != list(PARTITION):
    bad(f"phases are {names}; the bootstrap runs {list(PARTITION)}")

# ── the partition has not drifted ─────────────────────────────────────────
for name, want in PARTITION.items():
    if name not in by_name:
        continue
    now = sorted(by_name[name].get("modules") or [])
    if now != sorted(want):
        bad(f"phase {name} no longer places what it placed: gained "
            f"{sorted(set(now) - set(want)) or '[]'}, lost {sorted(set(want) - set(now)) or '[]'}")
declared = {m["name"] for m in bp.get("modules") or []}
placed = {m for p in phases for m in (p.get("modules") or [])}
for m in sorted(declared - placed):
    bad(f"module {m} is declared and no phase places it")
for name in HOOK_ONLY:
    if by_name.get(name, {}).get("modules"):
        bad(f"phase {name} places modules — it is declared as hooks only")

# ── nothing may GATE on a phase the tree cannot answer for ────────────────
# A hook-only phase places no files, so orun derives it as `unknown`, and
# `requires.phases` fails closed on `unknown`: a requirement naming one can
# never be satisfied.
for p in phases:
    for need in ((p.get("requires") or {}).get("phases") or []):
        if need in HOOK_ONLY:
            bad(f"phase {p['name']} requires {need}, which places no files — require "
                f"its predecessor instead")
        if need not in by_name or names.index(need) >= names.index(p["name"]):
            bad(f"phase {p['name']} requires {need}, which does not run before it")

# ── every phase says what it is and what to budget ────────────────────────
for p in phases:
    for field in ("title", "expectedMinutes"):
        if not p.get(field):
            bad(f"phase {p['name']} declares no {field} — an operator reads both")
    if not (p.get("hooks") or {}):
        bad(f"phase {p['name']} declares no hooks — a phase that only places files "
            f"still has to land them")

def hooks_of(p):
    h = p.get("hooks") or {}
    if isinstance(h, list):
        return list(h)
    return [x for slot in ("pre", "post", "await") for x in (h.get(slot) or [])]

run_hooks = list((bp.get("hooks") or {}).get("preInstantiate") or [])

# ── every phase lands, and every landing is bound to its task ─────────────
for p in phases:
    ids = [h.get("id") for h in hooks_of(p)]
    lands = [h for h in hooks_of(p) if (h.get("uses") or "").startswith("orun.pr/land@")]
    if len(lands) != 1:
        bad(f"phase {p['name']} has {len(lands)} landing(s); a phase is ONE pull request")
        continue
    w = lands[0].get("with") or {}
    if w.get("task") != "{{ .phase.hooks.task.outputs.key }}":
        bad(f"phase {p['name']} lands without binding the PR to its task key")
    if "task" not in ids or ids.index("task") > ids.index(lands[0].get("id")):
        bad(f"phase {p['name']} must ensure its task before it lands")
    if p["name"] in DEPLOYS:
        if not any("retouch.mjs" in " ".join(h.get("run") or []) for h in hooks_of(p)):
            bad(f"phase {p['name']} deploys and has no retouch hook — a re-run after a "
                f"failed convergence would land an empty diff and redeploy nothing")
        awaits = (p.get("hooks") or {}).get("await") or []
        watch = [h for h in awaits if (h.get("uses") or "").startswith("orun.run/watch@")]
        if not watch or (watch[0].get("with") or {}).get("sha") != "{{ .phase.hooks.land.outputs.mergeSha }}":
            bad(f"phase {p['name']} deploys and does not watch the convergence of the "
                f"commit it merged (orun.run/watch@v1 with sha: mergeSha)")

# ── the hooks run in the one-landing order ────────────────────────────────
for name, want in PRE.items():
    got = [h.get("id") for h in ((by_name.get(name, {}).get("hooks") or {}).get("pre") or [])]
    if got != want:
        bad(f"phase {name}'s pre hooks are {got}; want {want} — a task found in `pre` waits "
            f"for the background task set-up before the phase has done anything")
for name, want in POST.items():
    got = [h.get("id") for h in ((by_name.get(name, {}).get("hooks") or {}).get("post") or [])]
    if got != want:
        bad(f"phase {name}'s post hooks are {got}; the one-landing order is {want}")
for name, want in AWAIT.items():
    got = [h.get("id") for h in ((by_name.get(name, {}).get("hooks") or {}).get("await") or [])]
    if got != want:
        bad(f"phase {name}'s await hooks are {got}; want {want}")
for p in phases:
    if p["name"] not in DEPLOYS:
        for h in hooks_of(p):
            if (h.get("uses") or "").startswith(("orun.integrations/reconcile@", "orun.run/watch@")):
                bad(f"phase {p['name']} deploys nothing and runs {h['uses']} ({h.get('id')})")

# ── THE PREVIEW ORIGIN BEFORE THE APP THAT FRAMES IT ──────────────────────
# `web` (the host) inlines the preview Worker's origin at build and its smoke
# reads that origin's /api/health; `preview` inlines the host's origin, the
# only one it lets provision its key. So on a merge to main the host must
# wait for its environment's preview deploy — `mode: enforced` — and not on a
# pull request, which deploys nothing (`modeRules` advisory on
# github-pull-request); the module that places it must come after the
# preview's; and each build must name its sibling's Worker, in its own
# environment, as the default origin it inlines.
comps = {}
for f in root.rglob("component.yaml"):
    if "node_modules" in f.parts:
        continue
    d = yaml.safe_load(f.read_text()) or {}
    comps[(d.get("metadata") or {}).get("name")] = (f.relative_to(root).as_posix(), d.get("spec") or {})
EDGES = {"web": "preview"}  # reader → the origin it waits for on main
SIBLING_ORIGIN = {  # component → (the variable its build inlines, the sibling it names)
    "web": ("NEXT_PUBLIC_V0_PREVIEW_PROXY_URL", "preview"),
    "preview": ("NEXT_PUBLIC_V0_CLONE_ORIGIN", "web"),
}
for reader, origin in EDGES.items():
    if reader not in comps or origin not in comps:
        bad(f"component {reader} or {origin} is missing — this check has gone blind")
        continue
    rel, spec = comps[reader]
    edge = next((d for d in spec.get("dependsOn") or [] if d.get("component") == origin), None)
    rules = (edge or {}).get("modeRules") or []
    advisory_on_pr = any(r.get("mode") == "advisory"
                         and ((r.get("when") or {}).get("triggerRef") == "github-pull-request")
                         for r in rules)
    if not edge or edge.get("mode") != "enforced" or not advisory_on_pr:
        bad(f"{rel} does not wait for {origin} on a merge to main — declare dependsOn "
            f"{origin} with mode: enforced and a modeRules advisory on github-pull-request")
    mod = next((m for m in bp.get("modules") or [] if (m.get("from") or "").rstrip("/") == rel.rsplit("/", 1)[0]), None)
    origin_mod = next((m["name"] for m in bp.get("modules") or []
                       if (m.get("from") or "").rstrip("/") == comps[origin][0].rsplit("/", 1)[0]), None)
    if not mod or not origin_mod or origin_mod not in (mod.get("dependsOn") or []):
        bad(f"module {(mod or {}).get('name', reader)} is not placed after {origin_mod or origin} (module dependsOn)")
for comp, (var, sibling) in SIBLING_ORIGIN.items():
    if comp not in comps or sibling not in comps:
        continue
    rel, spec = comps[comp]
    params = spec.get("parameters") or {}
    build = str(params.get("buildCommand") or "")
    sib_worker = str((comps[sibling][1].get("parameters") or {}).get("workerName") or "")
    sub = str(params.get("workersDevSubdomain") or "")
    want = f"https://{sib_worker}-${{ORUN_ENVIRONMENT}}.{sub}.workers.dev"
    if f"{var}=" not in build or want not in build:
        bad(f"{rel}'s buildCommand does not inline {var} with {sibling}'s Worker in its own "
            f"environment ({want}) as the default — the build would point at another origin")
# No data plane: nothing publishes a wiring document, and nothing may read one.
for name, (rel, spec) in comps.items():
    if any(k.startswith("WIRING_") for k in (spec.get("secretEnv") or {})):
        bad(f"{rel} reads a WIRING_* document, and this product has no infra component to publish it")
readers = len(EDGES)

# ── THE FAST SHAPE (orun >= v2.88.0) ──────────────────────────────────────
# The run-level list is the task set-up, all of it in the background: the
# first phase's provider check, placement, rebrand, repository and secrets
# run while it opens the epic, the milestones and the tasks.
for h in run_hooks:
    if not h.get("background"):
        bad(f"hooks.preInstantiate {h.get('id')} is not `background: true` — the first phase "
            f"waits for it before doing anything, though nothing before its landing reads it")
# No phase keeps a `pre` hook on the task plane: one there waits for the
# whole background list before the phase has done anything.
PLANE = ("orun.task/", "orun.pr/land@")
for p in phases:
    for h in ((p.get("hooks") or {}).get("pre") or []):
        if (h.get("uses") or "").startswith(PLANE):
            bad(f"phase {p['name']} pre hook {h.get('id')} uses the task plane ({h['uses']}) — "
                f"move it to `post`, just before the landing")
# Every landing checks its commit here and merges, instead of waiting for a
# runner to plan the tree this box just wrote.
for p in phases:
    for h in hooks_of(p):
        if (h.get("uses") or "").startswith("orun.pr/land@") and (h.get("with") or {}).get("checks") != "local":
            bad(f"phase {p['name']} lands with checks {(h.get('with') or {}).get('checks', 'ci')!r}, "
                f"not 'local' — it waits for a runner to plan a tree that is here")
# The convergence watch reads every few seconds, not the action's default 40.
for p in phases:
    for h in ((p.get("hooks") or {}).get("await") or []):
        if (h.get("uses") or "").startswith("orun.run/watch@"):
            every = (h.get("with") or {}).get("pollSeconds")
            if not isinstance(every, int) or every > 10:
                bad(f"phase {p['name']} watches its convergence every {every or 40} s; at most 10 — "
                    f"the build goes on that much after the run is green")

# ── every phase's task is one the run-level list opens, in the same order ─
def task_names(hooks):
    return [(h.get("with") or {}).get("name") for h in hooks
            if (h.get("uses") or "").startswith("orun.task/ensure@")
            and (h.get("with") or {}).get("kind") == "task"]
opened = task_names(run_hooks)
per_phase = [n for p in phases for n in task_names(hooks_of(p))]
if opened != per_phase:
    bad(f"the run-level list opens tasks {opened}; the phases ensure {per_phase} — "
        f"a task is found by its title, so the two must be the same words")
milestones = [(h.get("with") or {}).get("name") for h in run_hooks
              if (h.get("with") or {}).get("kind") == "milestone"]
if milestones != names:
    bad(f"the run-level list opens milestones {milestones}; the phases are {names}")

# ── every contract a hook names exists, beside the blueprint ──────────────
for h in run_hooks + [x for p in phases for x in hooks_of(p)]:
    rel = (h.get("with") or {}).get("contract")
    if rel and not (root / rel).exists():
        bad(f"hook {h.get('id')} names contract {rel}, which does not exist")
    if rel and not rel.startswith(".baseline/tasks/"):
        bad(f"hook {h.get('id')} names contract {rel} outside .baseline/tasks/ — "
            f"`tasks/` is this repository's own work tree, where an unkeyed "
            f"contract is an error")
for p in phases:
    for h in hooks_of(p):
        argv = " ".join(h.get("run") or [])
        for ref in re.findall(r"\{\{ \.baseline\.dir \}\}/(\S+?)(?:\"|'|\s|$)", argv + " "):
            if not (root / ref).exists():
                bad(f"phase {p['name']} hook {h.get('id')} runs {ref}, which this "
                    f"repository does not have")

# ── every phase has a documentation page, and every page a phase ──────────
docs_dir = root / "docs" / "phases"
pages = {f.stem for f in docs_dir.glob("*.md")} - {"README"}
for n in names:
    if n not in pages:
        bad(f"phase {n} has no page at docs/phases/{n}.md")
for page in sorted(pages - set(names)):
    bad(f"docs/phases/{page}.md documents a phase repo-blueprint.yaml does not declare")

# ── narration: authored here, printed from state (Cirrus's rules) ─────────
META_AT = {
    "start": {"files", "expectedMinutes"},
    "await": {"files", "expectedMinutes"},
    "failed": {"files", "expectedMinutes"},
    "done": {"files", "expectedMinutes", "elapsed", "next"},
}
STATE_WORDS = {"done", "failed", "complete", "completed", "succeeded", "skipped"}
PHASE_KEYS = {"name", "title"}
input_keys = set((bp.get("inputs") or {}).keys())

ws_input = (bp.get("inputs") or {}).get("orunWorkspace") or {}
if ws_input.get("from") != "workspace":
    bad("inputs.orunWorkspace must declare `from: workspace` — a console build has no other way to say it")

def strip_expressions(line):
    return re.sub(r"\{\{.*?\}\}", "", line, flags=re.S)

def refs(line):
    found = []
    for expr in re.findall(r"\{\{(.*?)\}\}", line, re.S):
        found += re.findall(r"\.([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)", expr)
    return found

def check_line(where, line, slot, hook_ids):
    prose = strip_expressions(line).lower()
    for w in STATE_WORDS:
        if re.search(rf"\b{w}\b", prose):
            bad(f"{where} asserts {w!r} — `state` is the truth and narration is the "
                f"caption. Describe the world, not the run.")
    for ref in refs(line):
        parts = ref.split(".")
        head = parts[0]
        if head == "phase":
            if len(parts) != 2 or parts[1] not in PHASE_KEYS:
                bad(f"{where} names .{ref}; a phase carries {sorted(PHASE_KEYS)}")
        elif head == "inputs":
            if len(parts) != 2 or parts[1] not in input_keys:
                bad(f"{where} names .{ref}, which is not a declared input")
        elif head == "meta":
            allowed = META_AT.get(slot, META_AT["start"])
            if len(parts) != 2 or parts[1] not in allowed:
                bad(f"{where} names .{ref}; the {slot} event carries {sorted(allowed)}")
        elif head == "hooks":
            if len(parts) < 2 or parts[1] not in hook_ids:
                bad(f"{where} names .{ref}; this phase has no such hook")
        else:
            bad(f"{where} names .{ref}; narration may reference phase, inputs, meta and hooks")

for p in phases:
    n = p.get("narrate") or {}
    ids = {h.get("id") for h in hooks_of(p)}
    # `await` is NOT authored. A phase waits on a hook or on a connection its
    # `requires.probe` asks for, and the engine, which knows which, prints
    # "<title>: <reason>" when a phase authors no await line (an engine that
    # predates the reason prints "<name> is waiting."). An authored line
    # replaces that with a guess, and wrapping the reason does not work
    # either: it is a clause of its own ("waiting for github, cloudflare to
    # be connected…"). So an authored await line is refused, not required.
    for slot in ("start", "done", "failed"):
        line = n.get(slot)
        if not line:
            bad(f"phase {p['name']} declares no narrate.{slot}")
            continue
        check_line(f"phase {p['name']} narrate.{slot}", line, slot, ids)
    if n.get("await"):
        bad(f"phase {p['name']} authors narrate.await — leave it out: the engine says "
            f"what the phase waits on (\"<title>: <reason>\"), and an authored line can only guess")
    for h in ((p.get("hooks") or {}).get("await") or []):
        line = h.get("narrate")
        if not line:
            bad(f"phase {p['name']} await hook {h.get('id')} declares no narrate — a "
                f"wait with no words reads as a stalled build")
            continue
        check_line(f"phase {p['name']} hook {h.get('id')} narrate", line, "done", ids)
    for slot in ("pre", "post"):
        for h in ((p.get("hooks") or {}).get(slot) or []):
            if h.get("narrate"):
                check_line(f"phase {p['name']} hook {h.get('id')} narrate", h["narrate"], "start", ids)
# The run's own hooks speak too (orun >= the build panel's engine), under no
# phase: their scope is the run's hook outputs, and they carry no meta.
META_AT["run"] = set()
run_ids = {h.get("id") for h in run_hooks}
for h in run_hooks:
    if h.get("narrate"):
        check_line(f"hooks.preInstantiate {h.get('id')} narrate", h["narrate"], "run", run_ids)

# ── what a baseline of this shape never grows back ────────────────────────
if (root / "flows").exists():
    bad("flows/ exists — the bootstrap is the blueprint; every mechanism is a typed orun action")

if problems:
    print("FAIL: the blueprint's phases and the bootstrap disagree:", file=sys.stderr)
    for p in problems:
        print(f"  - {p}", file=sys.stderr)
    sys.exit(1)

placed_n = sum(len(p.get("modules") or []) for p in phases)
print(f"   {readers} origin edge(s), each reader waiting for the origin it frames on main; both builds name their sibling")
narrated = sum(len(p.get("narrate") or {}) for p in phases)
narrated += sum(1 for p in phases for h in hooks_of(p) if h.get("narrate"))
narrated += sum(1 for h in run_hooks if h.get("narrate"))
print(f"   {len(phases)} phases, {placed_n} modules, {len(HOOK_ONLY)} hook-only — in execution order")
print(f"   {narrated} authored narration lines, every reference resolving")
PY

echo "phases.test.sh: ok"
