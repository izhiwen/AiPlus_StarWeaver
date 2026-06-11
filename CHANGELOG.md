# Changelog

## Unreleased

## 0.7.23

> **📦 Release Notes — v0.7.23**
>
> **One tarball, one gate.** `curl … | sh` now produces a fully-gated
> `cargo` — the `aiplus-gate-shim` is bundled in the release tarball,
> and `aiplus gate --install` activates it. No source checkout needed.
>
> **Anti-lag advances.** Four-piece anti-stuck loop: memory-pressure
> detection warns before your Mac swaps → dispatched agents remind you
> to close finished sessions → session strategy tiers (`⚙️ CONFIG`)
> auto-annotate dispatch prompts so agents know whether to reuse or
> restart their session.
>
> **Session strategy tiers.** Dispatched agents now receive tier-appropriate
> CONFIG hints: LIGHT tasks → "新会话即可", MEDIUM → "一任务一会话
> · compact 35%", HEAVY → "同会话续做 · compact 60%". Set
> `AIPLUS_SESSION_STRATEGY=fresh-always` to force all tiers to
> fresh-session mode.
>
> **STOP-gate simplified.** Owner override for STOP-gated actions is now
> two-step: first request warns and refuses → second request executes.
> (Down from three-step per Owner ruling.)
>
> **30 PRs** landed: Gate-Shim standalone install, B.5 data-driven skins,
> dispatch execution Phase-B, user-persona substrate, anti-lag advances,
> docs rescue, and CA-hardened test suites.

### Standalone Gate-Shim Install (one tarball, one `install.sh`)

Closes the standalone-install loop. v0.7.23 release tarballs now bundle
the `aiplus-gate-shim` binary alongside `aiplus` and `aiplus-token-cost`,
so `curl … | sh` from a fresh box produces a fully-gated `cargo` without
needing a source checkout. (#342 #347 #348 #349 #353 #357 #358 #360 #366)

- `install.sh` extracts the shim to a version-pinned libexec path
  (`~/.local/libexec/aiplus-shim/v<version>/cargo`) and leaves
  activation to the new `aiplus gate --install`
  (the only form the CLI accepts — `aiplus gate install` would clap-fail).
- `aiplus gate --install` walks two paths: **tarball-sidecar** (use the
  staged binary, write a structured `~/.config/aiplus/gate.toml`
  sidecar) and **source-build** (fall back to `cargo build -p
  aiplus-gate-shim` for users who still build from a checkout). Drift
  detection (M3) compares the installed shim's version stamp against
  the aiplus CLI's `CARGO_PKG_VERSION` — drift is a `doctor` WARN,
  never an error.
- `aiplus doctor` gains a **Build Gate** section showing install /
  PATH-order / bypass / recursion-guard / ledger state and the M3
  DRIFT warning.
- KEystone activation probe in the shim's main entry: parses
  `~/.config/aiplus/gate.toml` (or `~/.aiplus/gate-shim.toml`) as
  valid TOML with at least one top-level key; missing / unreadable /
  corrupt ⇒ passthrough (fail-OPEN). Empty / whitespace-only files
  are NOT activated (CA-caught on #353).
- A 4th commit on #353 moves the `decide_shim` decision into a
  SEAM-typed enum (`ShimDecision::{PassthroughRealCargo,
  GateAiplusBuild}`) so the test suite actually exercises the
  intercept path (CA caught a hollow-green CI on the prior version).
- #342 / #366: shim binary-lookup hardening — resolves installed-binary
  path resolution (exe-parent → cwd workspace fallback) and cfg-gates
  shim exec calls for Windows build compatibility.
- #369: CA 🟡 follow-ups on install.sh + post-release-smoke — 3
  install-script edge cases hardened (banner, replace-in-bundle, smoke).

### B.5 Data-Driven Skins (substrate: `TeamIdentity` + golden tests)

Phase-A design (Architect, #341) + Phase-B substrate landed. The three
existing teams (agent-team / AEL / ASL) now declare their
`core_roles / expert_roles / bench_roles` in a single
`TeamIdentity` struct instead of hardcoded match arms. (#341 #343 #345)

- B.5 PR-2 (#341): generic adapter installer — the data-driven substrate
  keystone that encodes per-team role mappings into `TeamIdentity` structs,
  replacing 45+ hardcoded skin arms with a single normalized lookup.
- `ModuleSpec` extended with `TeamIdentity` (F1 fields); 3 skins
  filled; 8 golden tests added (`skin_golden_set_team_roundtrip`
  covers install-and-no-panic; `subagent_prefix_is_correct_for_all_teams`
  covers role-name resolution).
- B.5 PR-6 (#354): removed 9 hardcoded per-team `*_ROLES` arrays, 6 deprecated
  `install_*_adapter` functions, 2 `wrap_*_subagent` helpers, and
  the 3 `*_managed_block` helpers; 2 categories required regression
  fixes reverted. **Honest post-fix disposition: 9 fully deleted +
  2 partial + 4 retained+TODO** (+273/−1508 lines).
  Reviewer PASS, CA 🟡 follow-ups cleared (#360), golden tests
  byte-identical PASS.

### Dispatch Execution (Phase-B distribution)

The agent-team roles (e.g. `engineer-a`) can now run real `claude`
workers from a local source build, gated by 6 admission checks:
exec-mode, env allowlist, spawn-rate, concurrency, session cost cap,
daily cost cap. (#351)

- `execution_admission()` is the single choke point at
  `agent/route.rs:2228`. Mode gate returns `queued_mode_off` when
  `AIPLUS_AGENT_EXEC_MODE != auto`; remaining 5 gates are
  unreachable in dormant state.
- Cost caps: $100/session, $200/24h, $25/dispatch ceiling
  (post-hoc backstop). All FAIL-CLOSED on ledger read error.
- Owner ENABLE runbook (`docs/proposals/dispatch-exec-enable-runbook.md`)
  is the on-disk Owner procedure; Step 6 is now **read-current-queued-list**
  (no hardcoded dispatch IDs — old `dispatch-1780961896155` /
  `dispatch-1781119564402` are historical CLOSED examples).
- L5 sandbox test harness (`tests/dispatch_cost_cap_l5_sandbox.rs`)
  is gated on `AIPLUS_RUN_DISPATCH_COST_CAP_L5=1` so default CI
  stays green.

### User-Persona (PR-1 substrate)

The user-persona substrate (config, profile, redactable fields,
PII layer-2 masks, structure tests) lands as PR-1 (~2900L, 5 files),
with bench fan-out wiring so user-visible persona changes auto-add
a persona reviewer. (#350 #362)

- `user_profile::mod.rs` is the single per-project entry point;
  read-only at runtime for the lobby; writable by `aiplus
  user-persona set` (Owner-gated).
- B1 direction (per-project `~/.aiplus/agents/` vs repo `assets/`
  SOURCE) ruled per-project by Architect DA1.
- clobber-safe writer (ADR-clobber-safe-writer) preserves user
  edits to the per-project config across upgrades.
- B1 (per-project) PASS, B2 (PII layer-2 masks) PASS, B3 (no
  global / constitution writes) PASS, B4 (lobby read-only) PASS.
  30/30 unit tests + 18/18 structure tests green. Reviewer
  INDEPENDENTLY re-ran same = predecessor code is NOT false-done.

### Fixes & Docs

- #344 / #346: doc rescue — 8 untracked design docs recovered from
  evaporation risk; runbook CA corrections applied.
- #352 Dispatch-Execution ENABLE runbook rewritten (Step 6
  generalized; §10 PR-4 plan list flipped source-first → tarball-first
  per #349 merge; CA 🟡 cleared).
- #355 / #356 docs cleanups (see PRs for per-file lists).
- #359 Lobby resume claude bypass: restores
  `claude-code --dangerously-skip-permissions` in the lobby RESUME
  path (over-filtered by #326; opencode filter correct, claude
  was collateral damage; Owner-ruled restore).
- #360 CA 🟡 follow-ups on #353/#357: shim test suite
  `GateAiplusBuild` positive assertions (CA caught a hollow-green
  test on the prior version that only asserted
  `PassthroughRealCargo`); `gate_cmd query_aiplus_version` version
  parse hardening (garbage string → None → existing Skip branch,
  tri-state preserved).
- #372 fix(clippy): zero-warning cleanup — main hygiene restoration (30→0)
- #373 fix(dispatch): inject lane_id into native runtime prompt generation
- #374 fix(doctor+session-limit): add --fix×--reap-orphans mutex guard and pin RAM/8 boundaries

### Anti-Lag & Session Strategy (closure loop)

v0.7.23 advances the anti-lag feedback loop: detect memory pressure
→ remind the user → make dispatched agents self-aware about session
reuse. (#361 #364 #365 #367 #368)

- #361 **Memory-pressure guard** (three-piece suite): `UserPromptSubmit`
  hook detects RAM/swap pressure and emits a soft reminder; `aiplus
  doctor` extends with Memory / Swap / Orphan-session detection; new
  `docs/16gb-survival-guide.md` (中英双语) as the canonical 16GB
  Mac survival reference.
- #364 / #367 **STOP-gate two-step confirmation**: all 18 persona files
  adopt a consistent Owner-override rule — first request warns and
  refuses; second request executes (Owner-ruled collapse from 3-step
  to 2-step).
- #365 **Persona shutdown reminder + CONFIG auto-annotation**: 10
  execution/verification personas gain a role-specific shutdown
  reminder ("任务已完成，可以关闭本会话以释放内存"); dispatch
  prompts now auto-annotate with `⚙️ CONFIG` tier hints (LIGHT →
  新会话即可, MEDIUM → 一任务一会话 · compact 35%, HEAVY →
  同会话续做 · compact 60%).
- #368 **Ignition soft gate + orphan reap**: lobby pre-resume
  session-limit gate checks (`AIPLUS_SESSION_STRATEGY` → limit
  enforcement); `aiplus doctor --reap-orphans` interactive cleanup
  of stale agent sessions.
- #370 **Tier-aware session strategy**: dispatch CONFIG annotation
  upgraded from hardcoded hints to a tier table (LIGHT/MEDIUM/HEAVY)
  driven by `AIPLUS_SESSION_STRATEGY`; `fresh-always` override forces
  all tiers to new-session mode.

## 0.7.22

### Build Gate (Transparent, Phase-B)

- Added a **transparent build gate** that runs a `cargo`-named shim ahead of
  the system `cargo` in `PATH` and quietly routes every `cargo build` /
  `cargo test` invocation through the new `aiplus build` admission path
  (the same admission the lobby, agent-team dispatch, and CI already use),
  so a 16 GB Mac with three in-flight builds is queued, OOM-killed, and
  restarted from a checkpoint rather than a frozen shell (#336).
- The shim is opt-in, but **`aiplus gate --install` in v0.7.22 must be
  run from inside an AiPlus source checkout** (a clone of the
  `AiPlus/aiplus-public` repo, with `crates/aiplus-gate-shim` present):
  `command_gate_install()` invokes `cargo build -p aiplus-gate-shim`
  locally to produce the shim binary and then copies it to
  `~/.local/bin/cargo`, so the install path looks for the shim
  alongside the running `aiplus` binary in the local `target/`
  directory. `aiplus gate --install` now falls back to the cwd
  workspace `target/` when run from an installed binary inside a
  source checkout, with actionable error guidance (#342).
  A standalone install (e.g. via `install.sh` placing `aiplus` at
  `~/.local/bin/aiplus`) does **not** carry the shim binary, so
  outside a source checkout `aiplus gate --install` will surface
  `shim binary not found. The aiplus-gate-shim must be built before
  installing.` along with a built-in three-step How-to-fix guide
  (enter the source checkout, build the shim, re-run the install),
  and inside a source
  checkout it falls back to `<cwd>/target/cargo` first per #342
  (with the same explicit build hint if no local shim exists).
  **Standalone-install support is deferred to v0.7.23**
  (a separate lane that bundles the shim binary into the release
  tarball). Until then, the intended workflow is: clone the repo,
  `cargo build --release`, then `aiplus gate --install`.
- After install, `cargo --version` reports the real toolchain
  (`cargo 1.95.0 …`) — there is no command-line tell that the shim is
  there; a D5 dogfood across login shell, non-login shell,
  agent-spawned shell, and IDE-spawned shell all show identical
  output.
- IDE-spawned `cargo check --message-format=json` is exempt by config-driven
  flag match (Rust Analyzer / VS Code Rust extension all hit this path), and
  `AIPLUS_GATE_BYPASS=1 cargo …` is the documented escape hatch for the rare
  user who must bypass the gate.
- The shim uses a fail-OPEN fallback: if the AIPlus binary is missing, the
  config file is unreadable, or `exec` fails for any reason other than a real
  `cargo` not being in `PATH`, the shim forwards the original command to
  the real `cargo` rather than blocking the build. The only fatal exit (127)
  is "real cargo not found in PATH", which is identical to the pre-shim
  failure mode.
- A shim-sidecar `~/.local/bin/.aiplus-gate-shim.version` plus a new
  `aiplus doctor` Build Gate section surface install / PATH-order / bypass /
  recursion-guard / ledger state and a **DRIFT** warning when the shim
  version no longer matches the AIPlus CLI version.
- Full design notes live in
  `docs/proposals/transparent-build-gate-phase-b.md`; the Phase-A proposal
  was not landed in the repo and the source-of-truth is the Advisor framing
  plus the on-disk implementation (the Phase-B doc discloses this).

### Codex Hook Set (UserPromptSubmit)

- Added a managed `UserPromptSubmit` hook to the Codex runtime so a Codex
  session under the lobby now sees a pre-prompt pause that surfaces
  lobby-coordinator context (chief-auditor routing hints, advisory memory
  pointers, and a one-line "load project bundle" reminder), matching what
  Claude Code and OpenCode already enjoy via their own managed hook sets
  (#335).
- After upgrade, Codex users must run `/hooks` once and re-accept the new
  managed entry: Codex caches the trust decision on first encounter and
  the added `UserPromptSubmit` shows up as a new event the user has to
  confirm. A README + CHANGELOG line tell users what to do; the lobby
  surfaces a one-shot hint on first launch after upgrade.

### Runtime Reporting (Mis-Report Fix + Grandmother Tightening)

- Fixed a runtime mis-report where a long-running agent handoff could
  attribute the previous session's runtime to the new session (e.g.
  `claude-code` reported as `codex` when an opencode branch had been the
  last writer to the dispatch log), and tightened the 👵 grandmother
  instruction so the parallel-form (plain + metaphor) reply contract
  survives a runtime re-detect mid-session without dropping the metaphor
  half (#332).

### Resource Hygiene (Block 2 — RAM-Aware Admission Cap)

- Replaced the fixed `aiplus build` concurrency budget with a real
  **RAM-aware admission cap**: a per-lane `SysinfoSampler` keeps a 5-sample
  median of free RAM, the brake formula is `slots = floor(free_gb /
  cost_gb)`, the default per-build cost is `4.0 GiB`, the hard cap clamps
  `[1, 8]` with `AIPLUS_BUILD_MAX`, and a conservative 6.0 GiB peak
  floor-of-one means a 16 GB Mac with one running build at `2.4 GiB free`
  is queued (not killed) for the next 5-second tick. Behavior is identical
  to v0.7.21 when memory is loose (Normal pressure + 8+ GiB free → admit
  up to hard cap) (#334).
- Added two new `aiplus doctor` checks: a `MemoryPressureCheck` (`Ok` /
  `Runbook`) with a pinned four-line runbook, and a `DynamicCapCheck`
  reporting `FloorViolation` / `AtFloor` / `AtCeiling` / `Normal` /
  `NoSamples` so a 16 GB Mac user sees the brake explain itself.
- Module-level docs in `agent/sysinfo.rs` explicitly note the
  admission-only guarantee: a 16 GB Mac with 2 GiB free still admits one
  build at `cost=4.0`, and the cap is intentionally conservative
  (admission is the *honest* failure mode; silently killing a long build
  is not).
- Extended the worktree-infrastructure surface with three visibility /
  safety improvements that the operator can
  observe without any new auto-delete behavior:
  `aiplus doctor` now lists reclaimable worktrees (Removable vs.
  SkipUnmerged vs. SkipDirty) with a prune hint when any are Removable
  and a no-op INFO when none are; `aiplus integrate` prints a global
  summary of *all* reclaimable worktrees (not just the current lane)
  after a successful integrate so stale worktrees from prior rounds are
  visible; and `aiplus prune-worktrees` gained an explicit `--dry-run`
  flag plus a `du -sk` upper-bound disk estimate via
  `estimate_reclaimable_gib()`. The `du -sk` form is chosen
  deliberately: `-b` (GNU-only byte count) fails on macOS / BSD
  because their `du` does not implement `-b`, while `-sk` is POSIX and
  works on Linux, macOS, and the BSDs — so the estimate is
  cross-platform out of the box. The destructive path is still
  `--yes` only, and the `PruneStatus::Removable` gate continues to
  protect dirty / unmerged / detached worktrees (#337).
- Output carries a structured `PRUNE_WORKTREES_STATUS=PREVIEW|DRY_RUN|REMOVED`
  token so a `aiplus prune-worktrees --dry-run` and the default preview
  can be distinguished from a real removal in a downstream automation.

### Skin Substrate (Data-Driven, Phase-B)

- Replaced the per-skin hardcoded `match` arms in `data-driven skin
  substrate Phase-B`: the ~45 per-skin `match` arms scattered across
  `agent/`, `mirror/`, `craft-memory/`, and `dispatch/` are now a
  single config-driven `normalize_module` lookup keyed off the new
  `TeamIdentity` registry. Concretely: 45 arms is the **count of
  replaced arms**, not the count of skins — the three existing skins
  are `agent-team` (alias `swe`), `aieconlab` (alias `ael`), and
  `agentsciencelab` (alias `asl`), and the refactor fills
  `TeamIdentity` for all three. Behavior is identical for those three
  skins, and adding a new skin is now a single registry entry plus a
  fixture file (no code change) (#330).
- Bundle ship size drops by ~3 KB (~45 hardcoded arms → 1 generic
  lookup + 1 `TeamIdentity` struct), and the `data-driven skin
  substrate Phase-A` design is fully retired.
- Replaced the `DISK_CACHE_CONFIG_PATH` const (hardcoded
  `.aiplus/agent-team.toml`) with a `disk_cache_config_path()` function
  that reads `active-team.txt`, normalizes the alias via
  `normalize_module()`, looks up `get_team_identity()`, and returns
  `.aiplus/<team_config_filename>`. The lookup falls back to
  `.aiplus/agent-team.toml` when no active-team marker exists, when the
  active team has no `TeamIdentity`, or when any I/O error occurs — so a
  per-team disk cache config (e.g. `econ-team.toml` for the
  `aieconlab` team, `agent-science-team.toml` for `asl`) is resolved
  without a code change, and the hot path adds no `OnceLock` overhead.
  Verified by four new tests: `disk_cache_config_path_defaults_to_agent_team`,
  `disk_cache_config_path_reads_active_team`,
  `disk_cache_config_path_unknown_team_falls_back`, and
  `disk_cache_config_path_agentsciencelab` (#339).
- Replaced the 18-line hardcoded `match` arm in `handle_set_team()` with
  a single `normalize_module(Some(team))` lookup so adding a new team
  alias is a registry entry instead of a code change. The error message
  now dynamically lists all known aliases from `bundled_module_specs()`
  (was a static string) and matching is now case-insensitive (e.g.
  `Agent-Team` and `AEL` resolve), while every previously-accepted alias
  is still honored (superset, no breaking change). Verified by a new
  golden test #14 `skin_golden_set_team_roundtrip` that exercises alias
  → `normalize_module` → `set_active_team` → `read_active_team` for all
  three canonical teams (`agent-team` / `aieconlab` / `agentsciencelab`)
  against a tempdir snapshot dir (#338).

### Repository Compliance

- Consolidated the resource-hygiene Architect and DevOps briefs with the
  Advisor F-1 (failure-mode proof) and F-2 (operationalization) rulings
  and the Q1–Q7 question log, all under one Phase-A design proposal
  without behavior change (#331).
- Re-numbered Chief Auditor (CA) section headings so the manager / coach /
  advisor / chief-auditor block sits outside the shared reply-format
  managed block, and resolved the section-numbering conflict that
  generated ambiguous output (`## 1.5` was being claimed by two managed
  regions); the 1.5 anchor is now the sole occupant of its range
  (#324).

### Agent-Team Dispatch (B.2 — Allowlist + Daily Cost Cap)

- Tightened the agent-team dispatch env allowlist so the `env` map
  forwarded into a child process is exactly the documented CORE+DUAL set
  (no implicit `PATH`, no leftover `AIPLUS_*` test seams), and added a
  daily cost cap (`AIPLUS_AGENT_DAILY_COST_CAP_USD`, default `200.0`,
  fail-closed) under which `--execute` dispatches are queued rather than
  executed once the rolling 24h spend reaches the cap. The cap advances the long-running #216 and #217 roadmap
  threads without committing to their full surfaces (#329).
- Fixed a lobby resume path so a saved session with the
  `--dangerously-skip-permissions` flag is filtered out at restore time
  (it never applied to the TUI; it was the historical cause of the
  rejected-launch symptom) and the opencode plugin detects TUI mode and
  routes stderr advisories off-channel so the TUI's raw-bytes harness
  doesn't catch noise as a regression (#325, #326).
- OpenCode same-name `FullSync` backs up with `.bak` before removal so
  the opencode `FullSync` race cannot silently nuke a user's hand-edited
  agent mirror when the bundle and the project share a file name (#328).
- `strip_quoted_context` now skips `<pre>` blocks (it was double-stripping
  pastes that wrapped code blocks) and the audit log records skip paths
  so a `> <inline code>` can be traced through the strip pipeline (#327).

### CI

- Loosened the self-dev-smoke `GLOBAL_CONFIG_UNTOUCHED` grep to accept the
  `=YES scope=…` form emitted by the v0.7.20 audit pipeline so a v0.7.21+
  self-dev smoke can pass on an untouched global config without a
  whitelist override (#323).

## 0.7.21

### Lobby Resilience

- Made the lobby startup auto-refresh a stale project bundle **once**, even on
  machines already running the current binary — projects that were not in the
  re-exec path (so `refresh_current_project_modules_after_self_update` never
  fired) now pick up newly-bundled roles such as `chief-auditor` on the next
  start, with an anti-loop guard (re-checked status falls back to a one-line
  hint instead of re-writing when refresh fails) and two opt-out knobs:
  `AIPLUS_AUTO_UPDATE=0` (master) and `AIPLUS_AUTO_REFRESH=0` (granular,
  bundle-only) (#317).
- Stopped the bundle refresh from silently destroying a user's hand-edits to
  generated agent mirrors (`.claude/agents/*.md`, `.opencode/agents/*.md`):
  prefixed and same-name mirror files are now preserved across the regeneration
  pass, so a manually-tweaked role persona survives a bundle update (#319).
- Made the lobby **self-heal** a globally-stale OpenCode AiPlus plugin: on
  startup, before any `opencode` subprocess is spawned, the lobby detects a
  crash-prone old-shape plugin at `~/.config/opencode/plugins/aiplus.js` and
  refreshes it in place. When the live refresh is impossible, the failure
  degrades to a one-line actionable WARN instead of letting the launched
  opencode process throw `null is not object (evaluating 'O.config')` (#320).

### OpenCode Plugin Hygiene

- Taught `aiplus doctor` and `aiplus agent doctor` to read the global OpenCode
  plugin's new `AIPLUS_CLI_VERSION` marker and emit an actionable WARN when the
  installed copy is older than the running CLI, so a user can run
  `aiplus opencode refresh-global-plugin --force` to fix the version skew
  before it crashes a future lobby launch. Missing/unreadable plugins stay
  a quiet skip (a user may not use global OpenCode at all) (#315).
- Landed the OpenCode **handoff** in the full TUI agent mode, mirroring the
  start-new path from #313: `opencode --agent agent-team-<role> --prompt
  "<inline compacted context>"`. The inline `--prompt` guarantees the
  continuity context reaches the agent instead of depending on a file read,
  the now-incorrect `--dangerously-skip-permissions` flag is dropped (it never
  applied to the TUI; it was the historical cause of the rejected-launch
  symptom), and a >100 KB payload falls back to the proven `run --file -i`
  path as an ARG_MAX safety valve (#316).

### Repository

- Replaced the repository `LICENSE` with the verbatim standard Apache-2.0 text.
  The previous copy had been reformatted and was missing the appendix, so
  GitHub's license detection reported the project as unlicensed (`Other`) and
  the two README `](LICENSE)` links pointed at an unrecognized file. GitHub now
  recognizes the project as Apache-2.0; added a matching `NOTICE` file (#318).

### Craft Memory (L1 Phase-B)

- Added cross-runtime role-craft memory capture: roles emit a self-declared
  `📓 craft · <role> · <lesson>` marker, and a `Stop` / `SubagentStop` hook in
  claude-code / codex / opencode parses the marker, gates it through the
  CORE+DUAL role whitelist + `AutoWriter::classify_risk` (High = blocked),
  dedups via `stable_hash`, and appends it to the runtime-neutral store
  `.aiplus/agent-memory/<role>/memory.jsonl`. Quoted / fenced contexts are
  stripped before scanning (paste-injection guard), and unknown roles
  fail-closed (never writes `unknown`) (#321).

## 0.7.20

### Lobby

- Quieted the lobby startup so the auto-update check no longer prints transient
  progress noise before the menu, made the layout adapt to terminal width, and
  added a resume progress indicator so reopening a session shows it is working
  (#297).
- Added a cross-worktree resume picker: the lobby now enumerates your active
  role-main sessions living in sibling worktrees of the same checkout — not just
  the current directory — and resumes the selected one in its own worktree so
  `--resume` can find it (#301).
- Pinned the lobby's most-used bodies at the top of both lists: the resume view
  now leads with the most recent Advisor, CEO-1/2/3, and Chief Auditor session
  (every other session collapses behind `more`), and the start-new roster pins the
  three CEO lanes plus Advisor and Chief Auditor ahead of the rest of the team
  (#308).
- Added an animated progress bar to the cross-runtime handoff so compaction shows
  a real bar instead of bare text lines, stopped the summarizer subprocess from
  leaking a terminal graphics probe (the stray `Gi=…` next to the progress line),
  and made the `── entering <runtime> ──` divider the last line before a
  handed-off runtime takes over (#310).
- Reworked the lobby to the UI-Designer spec: resume sessions now render on a
  single line led by a bold uppercase role name (ADVISOR, CEO-1, CA) with a
  dimmed `runtime · time-ago · branch` tail, dropping the transcript preview, the
  "Since you left" counter, and the per-row resume hint; regrouped the start-new
  roster into Coordinate / Build / Verify / Experts sections (with "DevOps / SRE"
  renamed to "Deploy & Ops"); and turned the handoff progress bar into a single
  percentage line that degrades to `[ 45%]` under NO_COLOR/CI (#312).

### Cross-Runtime Sessions

- Made `aiplus agent talk` open a new Codex role as an interactive session
  instead of a one-shot run, so handing work to a fresh Codex role lands you in a
  usable session (#296).

### OpenCode

- Hid the non-compact `check-reply-format` SOFT advisories in OpenCode so routine
  replies are no longer cluttered by advisory-only notices (#295).
- Kept OpenCode slash commands additive rather than replacing the default command
  set, and isolated the handoff launch so it no longer interferes with the user's
  own commands (#305).
- Launched OpenCode start-new role sessions in the full TUI agent mode
  (`opencode --agent agent-team-<role>`) instead of `run -i` direct mode, so a
  freshly opened OpenCode role keeps its native slash commands (`/help`,
  `/sessions`, `/models`) alongside the AiPlus ones (#313).

### Task Ledger

- Added a task ledger MVP: a lightweight ledger with CLI and MCP wrappers plus
  proactive surfacing hooks, so in-flight tasks are tracked and resurfaced rather
  than lost between turns (#302).

### Coordinator Assurance (CA) Verification

- Fixed the Advisor CA-verdict detector so it fires on real forwarded CEO report
  pastes (`⏺ CEO-1 …`, `ceo · opencode`, `## ceo-2 · codex`) instead of only the
  synthetic shape it shipped with, and added a sibling `advisor-ca-prompt` SOFT
  rule that nudges when a `需要CA验证` verdict ships without an attached CA prompt.
  Both are advisory-only and never block (#303).
- Activated the Chief Auditor agent-team role so it is routable, without enabling
  Hook ② — the role is available now while its second hook stays deferred (#304).
- Fixed agent-team `update` so an install already on the current version still
  receives newly bundled role files, so the Chief Auditor role now propagates to
  existing projects instead of being silently skipped as up-to-date (#307).

### Release Safety

- Hardened the release ship-gate with regression assertions covering the
  v0.7.18/0.7.19 lobby, handoff, agent-talk, and plugin bug classes so those
  specific failures cannot silently return (#298).
- Added a Phase-C pty smoke harness that drives the lobby in a real
  pseudo-terminal and asserts on raw bytes, locking terminal-level invariants
  (no graphics-escape leaks, the entering-runtime divider, progress-bar bytes,
  resume read-before-compact ordering) that argv-only tests cannot catch (#309).

### Design Proposals

- Landed two docs-only Phase-A design proposals — the Chief Auditor persona and
  the task ledger orchestration layer — with no runtime behavior change
  (#299, #300).

## 0.7.19

### Cross-Runtime Handoff

- Decluttered the OpenCode handoff transition so the carried identity and memory
  context no longer floods the screen on resume: the seeded context now moves
  into a file attachment instead of being printed inline, leaving the user-facing
  transition clean while preserving the same carried state (#292).

### Agent-Team Operating Model

- Baked the orchestrator (coordinate-not-implement) contract into the Advisor and
  CEO window-main personas, so the coordinating roles consistently delegate
  implementation rather than building directly (#289).
- Added the CA-verification dual-hooks Phase-A design proposal that specifies the
  coordinator-assurance verification hooks ahead of implementation. Docs only —
  no persona, config, or runtime behavior change (#291).
- Implemented CA Hook ① (the Advisor CA-verdict hook) as a SOFT, advisory-only
  check, Claude-first, that surfaces a verdict without blocking. It is advisory
  by design and does not gate or alter existing flows (#293).

## 0.7.18

### Cross-Runtime Handoff

- Fixed a cross-runtime handoff resume crash that left lobby-opened Codex and
  OpenCode windows failing with `AIPLUS_UNEXPECTED_ERROR`: the Codex handoff
  seed could trip a Hard self-correct rule and exit BLOCKED, and the OpenCode
  invocation passed a `run`-only flag plus an unsupported `--prompt` at the
  global level. Handoff now tolerates the Codex seed exit code and builds a
  valid OpenCode command (#284).
- Decluttered the cross-runtime resume transition by hiding pure telemetry
  lines from user-facing output. This is a rendering-only change that does not
  alter handoff logic (#286).

### Build Cost

- Made compile-memory-saving the project default through config and docs only,
  with no source change and fully reversible: a `jobs = 2` cap bounds
  concurrent codegen units so 16GB-class Macs no longer OOM-freeze on local
  `cargo build --release`, alongside an optional presence-gated sccache wrapper
  and a developer build-memory guide (#285).
- Added `aiplus build`, the automatic counterpart to the F1 first-aid: it reads
  this machine's live free memory and macOS memory pressure before compiling
  and admits, queues, or brakes by how many compiles fit right now, then runs
  `cargo` and releases its slot on exit. Concurrent invocations coordinate
  through an on-disk FIFO ledger so a host does not fan out into an OOM-freeze.
  It layers additively on F1 and is reversible (#288).

### OpenCode Robustness

- Added `aiplus doctor` detection for a stale GLOBAL opencode plugin — the old
  multi-export shape that breaks opencode for every project during provider
  init — plus a user-invoked `refresh-global-plugin` subcommand to heal it,
  closing the gap where `install` and `update` never touched the global plugin
  path (#287).

### Design and Docs

- Formalized the Owner-decided hybrid agent-team operating model into a
  reviewable Phase-A design proposal. Docs only — no persona, config,
  constitution, or exec-mode change (#282).
- Added the executed, reversible Phase-B0 cleanup report for the ratified
  agent-team-config model, clearing dead plumbing and pruning stale worktrees
  while protecting every active lane and leaving `main` behavior unchanged
  (#283).

## 0.7.17

### Auto-Verification

- Wired the auto-verification protocol into the `/at-goal` loop and the CEO
  persona so verification dispatch, evidence collection, and scoped follow-up
  checks run as part of the coordinator workflow instead of remaining only a
  standalone command surface (#275).
- Added a pre-spawn baseline snapshot plus delta reporting so
  `aiplus goal diff-check` can isolate verifier footprints precisely instead
  of mixing them with unrelated pre-existing worktree changes (#279).

### Stop-Hook Feedback

- Hid non-compact SOFT Stop-hook reminders from user-facing output while
  preserving visible `💾 Compact` reminders and leaving HARD-block behavior
  intact, making ordinary correction turns quieter without weakening
  enforcement (#277).
- Extended hidden-SOFT handling through Codex and OpenCode glue, added a JSONL
  audit trail for suppressed Stop-hook feedback, and exposed
  `AIPLUS_STOP_HOOK_SHOW_SOFT` as a debug restore switch when operators need to
  see the raw reminders (#280).
- Documented the cross-runtime feasibility and limits for hiding Stop-hook
  feedback before the implementation work, including the remaining HARD-block
  visibility constraints that depend on each runtime's hook channel (#273).

### Governance and Security

- Added tripwire coverage for the rule-class loop guard so future hook changes
  cannot silently downgrade security-class continuation blocks while preserving
  softer behavior for ordinary reply-format feedback (#274).

### Persona and Update

- Reconciled the installed `_teams/agent-team/personas` snapshot cache during
  `aiplus update agent-team`, so active personas and the team cache no longer
  drift or reintroduce stale managed-region wording on later team switches
  (#278).

### Docs

- Documented the dormant `agent route` worktree-provisioning backlog so the
  queued-only path's unused worktree behavior is visible as known product debt
  rather than a hidden operational surprise (#276).

## 0.7.16

### Exec-Safety Nets

- Made the dispatch execution cost gate fail closed when the session ledger is
  unreadable, so execution-mode cannot silently continue without a trustworthy
  cost view. This is a required safety net before broader exec-mode rollout
  (#266).
- Hardened worker reaping on normal exits and native backends so managed
  runtime workers do not leave child or grandchild processes behind after
  AiPlus considers the job complete. This is the matching process-lifecycle
  safety net for execution-mode readiness (#268).
- Kept secret-broker rule-class checks hard-blocking inside Stop-hook
  continuations, closing the leaked soft-pass path where a security-class rule
  could be softened by the continuation guard added for ordinary reply-format
  loops (#272).

### Goal-Mode and Project Stewardship

- Added the Part-3 auto-verification implementation: the `aiplus verify`
  command family, deterministic verifier fan-out with depth<=1 termination and
  concurrency<=4 hard clamping, and compile-time read-only `gh` allowlisting
  that preserves real `--head` identifiers for the Claude Code path and future
  runtime backends (#271).
- Upgraded `/at-goal` into a bounded, in-turn multi-batch orchestration loop with
  five strict-priority halt conditions (GATE / EVIDENCE / BUDGET / AMBIGUITY /
  GOAL_DONE), a mandatory `aiplus overclaim rerun --gate` evidence checkpoint at
  every halt, an evidence ledger in `goal-state.md`, and codex/opencode
  plan-only behavior — still turn-anchored with no background daemon.
- Added `aiplus goal diff-check [--since <ref>] [--repo-dir <path>] [--json]`, a
  mechanically independent scope-lock check (`git status` / `git diff --stat` /
  `gh pr list`) the Goal-Mode loop consumes after each dispatched batch to detect
  a rogue sub-agent's out-of-scope footprint (the #238 fix); it reports
  `clean`/`deviation`, it does not gate. "Mechanically independent" means the
  verdict is git-derived (not the CEO's self-judgement); full process
  independence via a `SubagentStop` hook is deferred to a next round. The
  `--repo-dir` flag points the probe at a sibling worktree so a footprint outside
  the current directory is not missed, and a leading-dash `--since` value is
  rejected (git-option-injection hardening).
- Added the ASL bundle-drift investigation, documenting why the current
  AgentScienceLab package should be reconciled only after upstream bundle-facing
  manifest/adapters are cleaned and an ASL sync workflow exists (#267).
- Added the Phase-A role-memory architecture design for CORE / DUAL /
  ON-DEMAND-REFERENCE roles, plus persona wording that clarifies 👵 lines are
  plain household metaphors rather than literary or archaic prose (#265).

## 0.7.15

### Goal-Mode and Reply Format

- Added the CEO-only §1.7 Goal-Mode managed region plus `/at-goal`, giving CEO
  sessions an explicit orchestration loop for objective tracking, scoped
  delegation, evidence-bound done, STOP gates, and compact-safe continuation
  without introducing a background daemon (#245).
- Simplified Format C into a lean reply skeleton while preserving compatibility:
  the hook accepts both the new one-line time form and the legacy four-line time
  form, and it keeps the required 👶 / 👵 affordances (#245).
- Added the Tier-2 mainline-progress board (`📊 主线全榜`) and the lean `🎯`
  progress nudge so coordinators can show a full task board when useful without
  forcing every reply to carry the whole board (#254).
- Kept older `🎯 主线任务` wording and board body-tag vocabulary compatible so
  installed hooks and current personas do not split across release boundaries
  (#257).

### Runtime Enforcement and Hooks

- Extended Codex interactive TUI coverage with realtime AiPlus hook enforcement,
  closing the gap where native interactive Codex sessions could bypass the
  shared reply-format, Self-Correct, and memory-add checks (#259).
- Guarded the shared Stop hook against `stop_hook_active` re-block loops: a
  previous `decision:block` no longer blocks its own forced continuation,
  breaking the infinite-revise loop that affected memory-add and reply-format
  checks (#262).
- Hardened memory-add checks by stripping embedded relay/report blocks before
  evaluating the Owner-memory rule and by ignoring pasted Format-C reports that
  should not trigger a new memory-add REVISE path (#250, #253).

### Lobby, Dispatch, and Cost Controls

- Finished lobby v2 tails: added cross-worktree hints, bracket-picker prompt
  refinements, and guardrails for Codex resume paths so the lobby stays clearer
  around resumed sessions and runtime choices (#258).
- Added dormant dispatch cost guardrails with $25/$100 defaults, a session cap,
  and a backstop so future execution lanes have cost fences before being turned
  on (#256).
- Documented the dispatch-execution backend credential path and Phase-B build
  design, and added the disk-login survival probe for the execution backend
  investigation (#248, #251, #252).

### AiEconLab Branding and Assets

- Renamed the AiEconLab display brand to `AdamSmith: AiEconLab` while preserving
  structural identifiers such as `aieconlab`, `AEL`, paths, markers, and repo
  URLs (#260).
- Made the bundled AiEconLab public-branding test treat the missing `demo.gif`
  as a pending interactive-VHS asset with an explicit warning instead of a hard
  failure, and added the recording instructions without committing a placeholder
  GIF (#261).

### Release

- Unified the release-prep version sources to 0.7.15: `aiplus --version` is
  sourced from `crates/aiplus-cli/Cargo.toml` via `CARGO_PKG_VERSION`, with
  matching `Cargo.lock` and `install.sh` fallback values.
- Re-verified the macOS install and self-update postprocess paths added in
  v0.7.14: both clear extended attributes, remove stale signatures, apply an
  ad-hoc hardened-runtime signature, and smoke `aiplus --version` after landing
  the binary.

## 0.7.14

### Install and Runtime Hardening

- Fixed the project-local OpenCode plugin so OpenCode 1.15.x no longer crashes
  during `opencode run` plugin loading. The plugin now exports only its plugin
  factory as a top-level export; test helpers live on that function instead of
  as separate exports, and OpenCode is documented as observe/audit plus stderr
  advisory rather than hard visible-output parity (#246).
- Fixed a live macOS install blocker where official release binaries could be
  killed by taskgated on macOS 26.x after install. `install.sh` and
  `aiplus self-update` now clear quarantine metadata and apply an ad-hoc
  hardened-runtime signature after landing macOS binaries, so a fresh
  `aiplus --version` runs without manual `xattr` / `codesign` repair (#241).
- Reaped full worker process trees on timeout so a timed-out runtime adapter
  cannot leave child or grandchild processes running after AiPlus reports
  failure (#243).
- Added Codex native Stop hook wiring so interactive Codex can call the shared
  `aiplus hook` checks instead of relying only on the `run-codex` one-shot
  wrapper path (#238).
- Made Claude Code -> Codex runtime handoff resume into an interactive Codex
  session instead of seeding one answer and dropping back to the shell (#234).

### Release and Evidence Quality

- Added evidence-bound-done gate core: schema v2 evidence packets,
  `overclaim rerun --gate`, and advisory CI coverage for completion claims
  that need evidence (#237).
- Propagated the evidence-done persona region through the installed persona
  templates and update flow so completion-claim evidence guidance stays current
  after project refresh (#242).
- Added the D6 reply-time advisory for high-level "done/tested/live" claims
  without an evidence-packet reference, keeping rollout SOFT/advisory-first
  while surfacing unsupported completion claims (#239).
- Guarded the memory-add hook against Stop-hook and `run-codex` feedback loops
  so hook feedback containing words like `remember` no longer retriggers the
  memory-add REVISE path; genuine Owner memory requests still require
  `aiplus memory add` (#240).
- Ignored `RUN_CODEX_STATUS=` wrapper telemetry in the memory-add evaluator so
  Codex status lines do not accidentally trigger memory-add revise loops while
  genuine remembered-content requests still get checked (#247).

### Lobby, Workflow, and Project Hygiene

- Polished lobby v2.1: removed redundant runtime-selection copy, added the
  versioned banner treatment, and tightened resume/new-role hints including
  `[r#]` affordances (#232).
- Productized the lapse fixes that came out of prior dogfood: doctor guidance
  for merge/delete-branch worktree collisions, dynamic update UX fixtures,
  self-update temp-dir cleanup, merge-main clippy-gate documentation, persona
  governance text, and cross-runtime reply-format glue follow-through (#233).
- Added worktree disk hygiene PR-A with AiPlus-managed worktree markers, safe
  prune surfaces, and doctor warnings for reclaimable stale worktrees (#231).
- Added worktree disk hygiene PR-B with integrate-time reclaim and opt-in
  shared compile cache support for managed worktrees (#235).
- Reconciled AiEconLab bundle sync so updates preserve substrate pins and avoid
  overwriting owner-managed module state incorrectly (#244).

### Documentation

- Added the Skin Factory operating model, AiEconLab dossier, and AiPlus skill
  manifest documentation for future audience-specific package work (#236).

## 0.7.13

### Lobby v2: bracket-first role selection (#225)

- Reworked the `aiplus` lobby around bracket-first choices: all user-selectable
  entries render as explicit `[N]` / `[rN]` affordances, resume entries stay
  visually separate from new-role selection, and the grouped roster remains
  readable in color, no-color, CI, and piped output.

### Cross-runtime install hooks and honest install output (#226)

- `aiplus install <runtime>` / `aiplus update` now self-heal project-local
  runtime wiring instead of requiring manual setup: Claude Code gets the
  canonical five project hooks, OpenCode gets the project plugin, and fresh
  Codex role launches go through `aiplus run-codex` so Self-Correct enforcement
  applies.
- Install output now distinguishes untouched global configuration from applied
  project runtime wiring, avoiding the old misleading
  `GLOBAL_CONFIG_UNTOUCHED`-only report.

### Section III structure fidelity, all-SOFT rollout (#227)

- Added a runtime-agnostic `aiplus hook check-reply-format` entry point for
  Section III structure checks, so Claude Code, Codex, and OpenCode use one Rust
  source of truth instead of reimplementing reply-format logic per runtime.
- The new structure checks ship as SOFT advisories for this release, preserving
  enforcement safety while surfacing drift in seal placement, body-item tags,
  decision-line guidance, compact markers, and progress-percent hints.

### Compact pressure reflects the current context window (#228)

- `aiplus context-usage` and hook consumers now derive compact pressure from the
  latest per-turn usage snapshot where the runtime exposes one, rather than from
  cumulative transcript file size. After compaction, pressure can fall back to
  the current live window instead of climbing forever.
- Claude Code defaults to a 200k context budget unless an explicit 1M beta hint
  is present; Codex and OpenCode parse their own latest usage shapes and only
  fall back to text-size heuristics when no per-turn usage exists.

## 0.7.12

### Lobby: scannable sectioned roster (#220)

- The `aiplus` lobby roster is now a single-column, three-section layout —
  **core team**, **review bench**, **on-demand experts** — with coral accent
  numbering fixed at 1–17 and decoupled from resume (resume entries moved to
  `r<N>`; Enter still resumes the most recent session). Labels use each role's
  display name, width follows `$COLUMNS` (no new dependency, 80-column
  fallback), and non-color / piped / CI output degrades to plain text with `--`
  rules and `[bench]` / `[expert]` text grouping (screen-reader friendly; honors
  `NO_COLOR` / `TERM=dumb` / `CI`). Demo GIFs are re-rendered before the next
  user-facing announcement.

### True dispatch-execution loop — honest execution, ships dormant (#218)

- `aiplus agent route --execute` can now drive a real Claude headless worker,
  gated behind an opt-in `AIPLUS_AGENT_EXEC_MODE=auto`. The default (unset /
  `queue`) queues exactly as before, so **this change is dormant — merging it
  turns nothing on**. Adds a structured `agent_route` MCP result envelope and an
  honest `isError` when execution does not actually occur; a Model-1
  true-execution gate (a dispatch is `completed` only with exit-0 **and**
  non-empty result **and** a parent-verified audit hash **and** an inspected
  worktree side-effect); execution-boundary credential confinement (`env_clear`
  + command allowlist on spawn paths); audit-hash verification on read; a native
  timeout; and a cost backstop. The codex / opencode native execution paths are
  hard-disabled by default. **Enabling** the loop remains separately gated
  (grandchild-process reap + cost sign-off, #216; live end-to-end loop, #217).

### fact-check: first-class opt-in module — Phase-A design (#219, docs only)

- Design proposal to elevate the shipped overclaim re-runner (`aiplus overclaim
  rerun`, v0.7.11) into a first-class, **opt-in** `aiplus-fact-check` module: the
  re-runner tool stays in the binary; the module is a project-local authoring
  scaffold (evidence-packet schema mirror, taxonomy, security model, examples).
  Documentation only — no module code is built. Includes the rescued
  overclaim-defense prior-art survey.

### update UX tightening

- Reduced the automatic release-check TTL from 24 hours to 5 minutes. The state
  is a single global `~/.config/aiplus/update-check.json` timestamp, so the new
  ceiling is at most 12 unauthenticated GitHub checks per hour.
- Bounded release metadata fetches: `curl` now uses `--max-time 2` plus
  `--connect-timeout 2`, and `wget` uses `-T 2`, so slow networks degrade
  quickly instead of hanging lobby/update flows.
- `aiplus update` now checks the binary before refreshing project modules:
  same-major updates self-update and re-exec, major updates prompt for
  `aiplus self update --yes`, and offline/check failures skip binary work while
  still refreshing bundled modules. A re-exec env guard prevents update loops,
  and lobby re-execs after self-update refresh the current project's modules.

### `aiplus load`: read-only pre-flight machine load meter

- Added `aiplus load [--json]` for Owner pre-flight checks before opening a new
  ultracode session on constrained machines. It reports total/free memory,
  pressure, heavy agent process count, a recommendation band, and suggested max
  concurrency without writing project or user files.
- macOS reads `sysctl hw.memsize`, `vm_stat`, and `memory_pressure`; Linux
  degrades to `/proc/meminfo`; unsupported OSes exit 0 with an unsupported
  message. JSON output exposes `free_gb`, `used_pct`, `pressure`,
  `agent_proc_count`, `recommendation`, and `suggested_max_concurrency`.
- Added tests for the concurrency mapping, recommendation bands, CLI JSON
  fields, human output, and no cwd side effects.

## 0.7.11

### `memory add` scope whitelist: refuse `global`/`profile` instead of silently writing local

- `aiplus memory add --scope global` (and `profile`, `session`) previously passed
  validation and then fell through a silent `_ =>` catch-all in
  `memory_write_rel_for_scope`, writing to the **project-local** store — promising
  cross-project / global persistence that does not exist (cross-project sync is
  POLICY-ONLY / not yet wired; see
  `docs/proposals/cross-project-advisor-preference-sync-phase-a.md`).
- Writable scopes are now an explicit whitelist (`personal | team | project`).
  Unknown scopes are rejected with a bilingual, non-zero-exit error and **nothing
  is written**. `--scope project | personal | team` behavior is unchanged.
- New regression test `memory_add_scope_whitelist.rs` flips the previously
  live-proven `global → PASS` into an asserted rejection (incl. "no silent local
  write") and pins the supported write scopes.

### Fast-follow (post-#204): CI-enforced JS locks + out-of-band sentinel + version bump

- **F2 — bun tests wired into CI**: added a `bun-opencode-plugin` job to `ci.yml`
  that runs `aiplus.test.js`. The JS anti-fake-green locks (`budgetForModel`, F4,
  CHECK-3/4) now run on every PR; previously cargo never executed the JS, so those
  regressions could merge green. CI goes 5 → 6 checks.
- **CHECK-3/4 — out-of-band idempotency**: the 💾 compact-advisory append no longer
  embeds the visible `[AIPLUS_SELF_CORRECT_SOFT]` sentinel (it leaked into the
  Owner-visible answer). Re-entrancy is now the out-of-band `compactAppended` Set
  keyed on `part.id` (it survives the `part.text` mutation that made `processed`
  dead for re-entry). Added `stripVisibleSoftSentinel()` to scrub any legacy visible
  sentinel left in a payload during an in-place upgrade.
- **F4 — test tightened**: the providerID test now plants a 1M-looking hint in
  `providerID` (no `modelID`) and asserts ~85% (NOT ~17%), pinning "providerID is
  NOT consulted" rather than merely asserting a numeric result.
- **Cargo bump 0.7.10 → 0.7.11** (version-skew discipline: bump Cargo + CHANGELOG +
  `install.sh` fallback together, before tagging).

### OpenCode compact-advisory parity: budgetForModel fix + bun snapshot tests + panic-hardening

- **compact-advisory parity** (not full soft-rule parity): the 💾 compact advisory
  now correctly fires on OpenCode for standard non-1m Opus users. Other soft rules
  remain stderr-only on OpenCode; only the 💾 advisory is routed into the visible
  `part.text` payload (this is the scope of this PR).
- Fixed `budgetForModel` in `aiplus.js`: removed a blanket `if (hint.includes("opus"))
  return 1_000_000` that assigned a 1M budget to standard Opus (~200k window) →
  computing ~17% pressure → the 85% gate never fired. Non-1m opus now correctly
  gets 200k, mirroring `context_usage.rs:budget_for_source` where `opencode → 200_000`.
- Fixed `percentFromTokens`: removed `|| info?.providerID` fallback in the
  `budgetForModel` call. `providerID` is the provider name (e.g. "anthropic") not a
  model hint; using it mis-budgets a real Opus-1M by 5× low → premature false 💾.
- Updated comment for `percentFromTokens` to list all five token components summed
  (input + output + reasoning + cache.read + **cache.write**; previously omitted).
- Added coupling note on `isCompactAdvisory`: the `"💾 Compact ·"` prefix is coupled
  to `build_compact_advisory()` in `pre_response.rs`; if Rust changes the render
  prefix, JS detection silently breaks.
- Idempotency for the 💾 append is the out-of-band `compactAppended` Set keyed on
  `part.id` (see Fast-follow above); the `processed` set is dead for re-entry because
  its key changes after `part.text` mutation. (The interim `[AIPLUS_SELF_CORRECT_SOFT]`
  sentinel guard was superseded before release — it leaked into the visible answer.)
- Security/panic-hardening: `Bun.spawnSync` wrapped in try/catch (E2BIG/EINVAL
  throws before `exitCode`); `lastUserText` capped to 16KB.
- Added `aiplus.test.js` (bun, checked-in; wired into CI via the `bun-opencode-plugin`
  job — see Fast-follow above): snapshot tests for `budgetForModel` +
  `percentFromTokens` with real token counts; CHECK-2 robustness tests;
  anti-fake-green proof showing RED with the blanket bug and GREEN after fix.
- Corrected overstating test-header comment in `agent_team_opencode.rs`: the static
  string test now honestly declares itself a source-contract check, not a behavioral test.

### Reply Format C (FINAL, bilingual) + header-region HH:MM (Self-Correct Layer 4)

- Migrated the Owner-facing reply schema enforced by `reply-format-anchor-missing`
  from the legacy 12-anchor stacked-`##` format to **Format C FINAL**, a
  seal-wrapped, visually-tiered, **bilingual** schema. The hook PASSes when the
  reply carries the shared header anchors plus one *complete* language anchor set
  — Chinese OR English (AiPlus replies in the user's primary language).
- Skeleton: a super-long unlabelled `═══` seal at top and bottom; a 3-line
  identity header (`## <role-emoji> <role>` / `🤖 <runtime>/<model>` /
  `🕐 <YYYY-MM-DD HH:MM TZ>`); 🎯 主线任务/Mission, 🔹 当前分任务/Current task,
  📊 分任务进展/Progress; labelled double-line block dividers `═════ 📄 正文/Body
  ═════` and `═════ 🔚 收尾/Wrap-up ═════`; the decision cluster ✅ 信心/Confidence
  · ⚠️ 风险/Risk · 🚦 Owner批准/Owner approval; then ➡️ 下一步/Next · ⏱ 时间/Time;
  optional `═════ 📋 Prompt ═════` dispatch module. Three line types: super-long
  unlabelled seal / labelled `═` block divider / fine `─` group divider.
- Match form (prevents false-positives): every label anchor is matched at the
  START of a line by its emoji+label (block dividers by `═` bars + label word),
  never as a bare substring — body prose merely mentioning e.g. "主线任务" no
  longer satisfies the anchor.
- HH:MM scope = header region: the clock is required on the `🕐` identity line
  (regex `(?:[01]?\d|2[0-3])[:：][0-5]\d`), not anywhere in the reply, so a time
  in a body table/command output (`12:34`) does not falsely satisfy it and a
  date-only header triggers REVISE (Owner Q2). The fullwidth colon (：) is
  accepted; `🚦 Owner批准` also accepts plain `批准`; emoji variation selectors are
  optional.
- The `[~X%]` figures, the three line types, paragraph rendering (👶 plain / 👵
  metaphor lines as blank-line-separated paragraphs, no `-` lists, no inline
  separators), 2-3 sentence 👶/👵 lengths, and light-mode (short single-topic
  replies, exempt by the ≤400-char rule) are persona-instructed, NOT hook-checked.
  The optional 📋 Prompt module (advisor/ceo dispatch only) is not a required
  anchor and never triggers REVISE.
- The rule remains role-agnostic (inspects only the reply text) and applies to
  **every** Owner-facing role including QA and all AEL roles; the >400-char
  trigger and exemptions (`[NO_FORMAT]`, short, tool-output) are unchanged.
  HARD/SOFT Stop-hook output schema is unchanged.
- All 35 Owner-facing personas (AiPlus + AEL + ASL) now point to constitution
  Section III with a short bilingual summary (DRY — no inlined full spec); the
  optional 📋 Prompt module note stays on ceo.md + advisor.md only.
- Regression tests: Chinese FINAL PASS, English FINAL PASS, missing-anchor
  REVISE, date-only-header REVISE (Owner Q2), body-time-without-header-HH:MM
  REVISE (header-region scope), bare-label-not-at-line-start REVISE, missing
  role heading REVISE, single missing decision anchor REVISE, fullwidth-colon /
  bare-emoji / lowercase-owner accept, optional 📋 module PASS, light-mode short
  reply exempt, `[NO_FORMAT]` / tool-output exempt.

## 0.7.10

### HOTFIX: Stop hook output schema correctness

- Fixed `aiplus hooks stop` SOFT verdict output that emitted
  `hookSpecificOutput.hookEventName=Stop`, which Claude Code SDK rejects
  ("Hook JSON output validation failed (root): Invalid input"). Stop event
  `hookSpecificOutput` is reserved for PreToolUse / UserPromptSubmit /
  PostToolUse / PostToolBatch only.
- SOFT verdicts now emit top-level `systemMessage` (per Claude Code SDK
  Stop event schema at https://code.claude.com/docs/en/hooks).
- HARD verdicts (`decision="block"` + `reason`) unchanged; this path was
  already schema-correct.
- Effect: Self-Correct SOFT rules (compact-prepare, score-only,
  audit-verify, doctor) now actually deliver reminders in real Claude
  Code sessions instead of being silently dropped by the host validator.
- Added 2 regression tests in `crates/aiplus-cli/tests/hooks_integration.rs`
  asserting Stop hook output schema (no `hookSpecificOutput.hookEventName=Stop`
  for SOFT, top-level `decision`/`reason` for HARD).

## 0.7.9

### Self-Correct cross-runtime + reply format + handoff fixes

This release closes the v0.7.8 cross-runtime gap by extending Self-Correct
Layer 4 to Codex and OpenCode, introduces the 12-anchor Reply Format Schema
enforced by a new Self-Correct hook, unifies cross-runtime Owner memory
under `~/.aiplus/`, and fixes the cross-runtime handoff bug for CEO lane
sessions.

**Self-Correct cross-runtime parity**

- Added Path AA-opencode: ESM plugin in `.opencode/plugins/aiplus.js`
  installed by `aiplus install opencode`. HARD rules mutate `part.text`;
  SOFT rules emit via stderr + `.aiplus/agents/hook-events.jsonl` (OpenCode
  1.15.3 plugin API limitation noted) (#185).
- Added Path BB-codex: `aiplus run-codex` wrapper applies Self-Correct
  evaluation to `codex exec` output. HARD rule blocks with exit 3,
  SOFT/PASS exit 0, `--no-self-correct` bypass exit 0 (#184, exit code
  semantics documented in #188).

**Reply Format Schema v2 (12-anchor)**

- Added 8th Self-Correct rule `reply-format-anchor-missing` that REVISEs
  Owner-facing replies > 400 chars missing any of 12 required anchors
  (`我是 `, `当前时间:`, 4 task/progress anchors, 4 next-step anchors,
  `## 风险 / 阻塞`, `## Confidence`, `## 是否需要 Owner 批准`). Spec
  authoritative in `~/.aiplus/constitution.md` Section III (#182).
- Fixed reply-format rule false positives: now fires on English long
  no-anchor replies; fixed `我是 ` regex position sensitivity false
  positive (#187).

**Cross-runtime Owner memory + constitution**

- Added `~/.aiplus/constitution.md` as Owner-only source of truth for
  cross-project conventions (principles, communication, memory protocol,
  STOP-gates, workflow tiers, evolution).
- Added `aiplus constitution context` subcommand + SessionStart hook wire
  for all 3 runtimes (#182, Card 11).
- Added `aiplus memory context-owner` subcommand + `~/.aiplus/memory/<project>/`
  cross-runtime memory layer with migration scaffold (#182, Card 12).
- Memory consolidation: `~/.claude/projects/.../memory/` is now a symlink
  to `~/.aiplus/memory/<project>/` for backward compatibility.

**Context tracking**

- Added `aiplus context-usage [--source claude-code|codex|opencode|auto]`
  subcommand returning JSON `{percent, tokens_used, tokens_budget, ...}`.
  Stop hook handlers now auto-detect context usage so the
  `compact-prepare-at-threshold` rule fires without manual env var (#182,
  Card 8).

**Persona + release prep**

- Strengthened score-only nudging in advisor + ceo personas: handoff to
  CEO and dispatch to engineer now explicitly recommend `aiplus agent
  route --score-only` first. Driven by Layer B observation that score-only
  spontaneous usage was 0/3 in MailCue dogfood (#186).
- Deprecated PR #148/#153 old anchor schema (GATE=, RECOMMENDATION=, etc.)
  with persona text references updated to constitution Section III (#182,
  Card 9).

**Handoff fix**

- Fixed cross-runtime handoff for CEO lane sessions: `ceo-1`, `ceo-2`,
  `ceo-3` lane tags now correctly resolve to `ceo.md` persona file via
  lane suffix stripping. Previously `aiplus` lobby cross-runtime resume
  (codex ceo-2 → claude-code) errored with "Persona file not found for
  role `ceo-2`" (#189).

**Quality + tests**

- Added regression tests for reply-format rule (English long no-anchor,
  all-12-anchors-present), run-codex exit code semantics (HARD exits 3,
  bypass exits 0), and handoff lane suffix normalization (#187, #188, #189).
- Cargo workspace version bumped 0.7.8 → 0.7.9. CHANGELOG entry, install.sh
  fallback, and persona Reply Format references updated in lock-step
  (per `[[version-skew-v0-7-7]]` discipline).

## 0.7.8

### Agent inbox, self-correct hooks, runtime execution, and ASL

This release moves AiPlus from persona/team scaffolding into a more operational
agent platform. It adds a visible agent inbox, wires Self-Correct rules into
Claude Code runtime hooks, introduces a Claude Code dispatch adapter for real
`agent route --execute` execution, and graduates AgentScienceLab into an
opt-in bundled module.

**Agent workflow and execution**

- Added Agent Inbox MVP so queued dispatches can be listed, filtered, watched,
  marked read, accepted, completed, and emitted as JSON.
- Added honest dispatch reporting when no execution backend is configured;
  callers now see the backend warning in the route response instead of needing
  to inspect execution state files.
- Added doctor detection for silent dispatch backlogs and surfaced backend
  state in `aiplus agent status`.
- Added `DispatchAdapter` plus a Claude Code adapter. `aiplus agent route
  --execute <role> <task>` can spawn a Claude Code subagent and return captured
  output when `AIPLUS_AGENT_EXEC_BACKEND=claude-code`.

**Self-Correct Framework**

- Added velocity bias memory writeback, SessionStart self-correct injection,
  PreResponse rule evaluation, and the `aiplus_estimate_time` MCP tool.
- Expanded PreResponse coverage from one velocity rule to seven rules:
  velocity format, memory recording, secret-broker use, score-only before
  route, compact threshold, audit verify before sensitive actions, and doctor
  during troubleshooting.
- Wired the rules into Claude Code Stop, SubagentStop, and UserPromptSubmit
  hooks so they run in live sessions instead of remaining orphaned code.
- Fixed persisted user-prompt context so the memory-add rule can evaluate
  actual session input.

**Personas and owner-facing output**

- Added persona template v2, rewrote the CEO/Advisor anchors and all Phase D
  persona groups, and tightened Advisor-to-CEO handoff boundaries.
- Added Reply Format Schema so reports use a consistent owner-facing structure,
  including `小白版=` where required.
- Added mock LLM persona behavior tests to reduce behavior workflow flake risk.

**Modules and onboarding**

- Registered AgentScienceLab as an opt-in bundled module via
  `aiplus add agentsciencelab`.
- Fixed role discovery so non-role TOML manifests are skipped generically while
  team manifests remain available to team-load paths.
- Restored and refreshed README binary / release / ASL facts in English and
  Chinese.
- Cleaned lobby UX: English-only role descriptions, hidden v0.2 stub experts,
  and no default marker in the runtime picker.

**Safety and auth**

- Added Owner Auth Phase 2 read-only checker while keeping authorization
  decisions Owner-gated.
- Added cross-runtime hook investigation notes for Codex and OpenCode follow-up.

Known follow-ups: PR #177 demo GIF regeneration remains open at the time of
this release-prep draft. Codex/OpenCode runtime adapter and hook work remains
v0.7.9 follow-up unless the Owner explicitly waits for additional PRs before
tagging.

## 0.7.6

### Project refresh, quieter lobby startup, and v0.7.6 cleanup

This release focuses on reducing post-update friction and improving the
operator-facing lobby path. It adds a project-local refresh command for
managed AiPlus assets, keeps runtime startup output concise while preserving
full persona injection, clarifies lobby role labels, and closes the Node.js 20
GitHub Actions warning cleanup.

**Project refresh MVP**

- Added `aiplus refresh` and `aiplus refresh --dry-run` to refresh the current
  project's AiPlus-managed assets after a binary self-update.
- Added `aiplus install refresh` as an alias for the same project refresh path.
- Refresh preserves memory, dispatch logs, execution state, runtime logs,
  locks, lane worktrees, and user/non-managed content.
- Stale project bundle detection reports clear `PROJECT_REFRESH_STATUS`
  outcomes and points users to `aiplus refresh` when the local project bundle
  is older than the installed binary.

**Lobby startup noise reduction**

- Runtime startup still receives the full role persona prompt/context.
- Default user-visible stdout now shows a short startup summary instead of
  printing the full persona block.
- `AIPLUS_TALK_DEBUG_PROMPT=1` keeps the debugging escape hatch for inspecting
  the full prompt when needed.
- Menu-based lobby flow, runtime picker behavior, and talk audit records remain
  unchanged.

**Lobby role labels and integration-manager display**

- CEO lane labels now describe the action as opening a new parallel CEO lane
  instead of exposing internal PILOT/persona wording.
- `integration-manager` appears in the lobby as a core/internal role with a
  neutral integration coordination description.
- Numeric menu selection remains supported.

**Node.js 20 CI cleanup**

- Updated GitHub Actions workflow dependencies to avoid Node.js 20
  deprecation warnings while preserving required check names:
  `fmt`, `clippy`, `test`, `install-smoke (macos-14)`, and
  `install-smoke (windows-latest)`.
- Release and post-release-smoke workflow semantics remain unchanged.

**Docs and policy planning**

- Added v0.7.6 backlog triage covering Node.js 20 cleanup, MailCue
  clean-baseline smoke policy, project refresh UX, async scheduler follow-up,
  lane-aware worktree status, lock limitations, and AEL notification auth.
- Added project refresh UX design notes and dirty-project smoke policy docs.

Known follow-ups: full scheduler/daemon work, lane-aware human Worktree status,
distributed locking, and clean-baseline dogfood policy enforcement remain
outside this release.

## 0.7.5

### Atomic execution locks, resume dry-runs, and repo hygiene

This release tightens v0.7.4's lane-aware execution foundation with atomic
role-instance locks, safer resume inspection paths, and repository hygiene
policy cleanup. Default routing remains recorded/queued-only unless execution
is explicitly requested.

**Atomic role-instance locks**

- Added local atomic execution locks at
  `.aiplus/agents/locks/<safe-role-instance>.lock`.
- Acquires locks with atomic `create_new` semantics before backend launch so a
  losing concurrent `--execute` does not start a runtime backend.
- Uses lane-aware role-instance keys such as `engineer-a@ceo-1` and
  `engineer-a@ceo-2`, while legacy no-lane dispatch keeps the role id as the
  lock key.
- Releases matching locks on terminal transitions and stale native-async
  dead-pid reaping without regressing already terminal execution records.
- Known limitation: locks are local filesystem coordination only, not a
  distributed or cross-machine scheduler.

**Talk resume UX**

- Added `aiplus agent talk --resume ... --dry-run` for inspecting the selected
  resume target and launch command without starting a runtime.
- Added `--no-launch` as an alias for dry-run resume inspection.
- Non-TTY resume flows that require an interactive terminal now return a typed
  `requires_terminal` block instead of silently attempting launch.

**Repo hygiene**

- Ignores local `/CLAUDE.md` so adapter-generated or workspace-local Claude
  notes stay out of release PRs by default.
- Clarifies proposal docs policy and keeps active proposal notes separate from
  archived release and dogfood documents.
- Archives prior release and dogfood planning notes under
  `docs/archive/releases/`.
- Adds the v0.7.5 quality backlog covering async daemon/scheduler follow-up,
  atomic queue work, richer integration-manager dashboards, lane-aware status
  polish, and AEL notification auth cleanup.

Known follow-ups: full async daemon scheduling, atomic queue management,
distributed locking, and richer integration dashboards remain outside this
release.

## 0.7.4

### Full PILOT lane isolation and native async supervision

This release completes the v0.7.4 Full PILOT MVP by combining isolated CEO
lanes, lane-aware integration, direct CEO lane resume, native async supervision,
and the integration-manager core role. Default agent routing remains
recorded/queued-only unless execution is explicitly requested.

**Full PILOT lane isolation**

- Added lane model support for `ceo-1`, `ceo-2`, and `ceo-3`, with
  `lane1` / `lane2` / `lane3` aliases.
- Added lane-specific role instances such as `engineer-a@ceo-1`, preserving a
  single CEO persona while isolating session identity, dispatch state, worktree,
  and branch ownership.
- Added lane-aware worktree and branch naming so the same role can work in
  different CEO lanes without sharing the same role worktree.
- Added active execution collision locking by role instance, blocking same-role
  same-lane `running` / `launch_ready` collisions while allowing the same role
  in a different lane.

**Lane-aware integration gate**

- Added explicit lane integration commands:
  `aiplus agent integrate --list-lanes`,
  `aiplus agent integrate --dry-run --lane <lane> <role>`, and
  `aiplus agent integrate --lane <lane> <role>`.
- Integration discovery reports role instance, lane, branch, worktree, dirty
  state, ahead count, and blockers.
- Local integration blocks dirty base worktrees, dirty lane worktrees, missing
  branches, and merge conflicts instead of guessing or auto-resolving.
- MCP `agent_integrate` now supports lane, dry-run, and list-lanes semantics.

**Direct CEO lane resume**

- `aiplus agent talk --resume ceo-1` / `ceo-2` / `ceo-3` resumes the latest
  matching lane session directly.
- `aiplus agent talk --resume ceo` does not guess when multiple CEO lanes
  exist; it prints explicit lane resume commands and stops without launching a
  runtime.
- Single-lane and no-lane CEO resume paths remain ergonomic, and non-CEO resume
  behavior is unchanged.

**Native async supervision**

- Added explicit opt-in native async supervision with
  `AIPLUS_AGENT_EXEC_NATIVE_MODE=async`.
- Async execution records truthful `running`, `completed`, `failed`, and
  terminal state transitions with process id, session id, supervision mode, and
  runtime log path evidence.
- `aiplus agent status` and `aiplus agent execution poll` can reap supervised
  native executions and avoid overwriting already-terminal records.
- `launch_ready` remains a manual launch state and does not imply an async
  supervised worker is running.

**Integration-manager core role**

- Added `integration-manager` as a core/internal agent-team role across
  templates, installed role metadata, adapters, documentation, and behavior
  tests.
- The role owns neutral lane-output discovery, integration planning, dry-run
  checks, local integration handoff, and blocker reporting.
- Owner gates remain in force for push, PR merge, tag, release, publish,
  deploy, external accounts, secrets, and private data actions.

Known follow-ups: automatic merge-manager conflict planning, full async
supervision scheduling, richer lane dashboards, and cross-runtime transcript
import remain outside this release.

## 0.7.3

### Native runtime execution, Advisor review bench, and PILOT CEO lanes

This release bundles the already-gated native runtime execution MVP, Advisor
review bench roles, PILOT CEO lane picker, and lobby UX cleanup work. Default
routing behavior remains recorded/queued-only unless execution is explicitly
requested.

**Native runtime execution MVP**

- Added opt-in native runtime execution with
  `AIPLUS_AGENT_EXEC_BACKEND=codex|claude-code|opencode`.
- Preserved default queued-only behavior for `aiplus agent route <role>
  "<task>"`; native launch is separate from route recording.
- Records launch lifecycle states including `launch_ready`, `running`,
  `completed`, `failed`, and `unsupported`.
- Persists execution evidence including `prompt_path`, `persona_path`,
  `worktree_path`, launch command state, and resume command state.

**Advisor review bench**

- Added `release-manager` and `evidence-auditor` bench roles.
- Reuses QA for dogfood, smoke, and reproduction validation instead of adding a
  duplicate QA-like bench role.
- Keeps the review bench read/verify/report/recommend only; Owner gates remain
  in force for deploy, publish, release, external accounts, secrets, and other
  STOP-gated actions.

**PILOT CEO lanes**

- Adds lane-tagged `ceo-1`, `ceo-2`, and `ceo-3` sessions backed by the same
  CEO persona.
- The lobby offers the next available CEO lane for new CEO sessions.
- Full branch/worktree isolation and integrator flow remain backlog; this ship
  is lane tagging and lobby selection only.

**Lobby UX cleanup**

- Runtime selection now shows available runtimes even when the project adapter
  is not installed yet, with an install path for missing adapters.
- Resume display keeps the list compact by default and supports `more` / `all`
  to reveal older or untagged sessions.

Known follow-ups: direct `aiplus agent talk --resume ceo` may not match
lane-tagged `ceo-1` / `ceo-2` / `ceo-3` sessions, and Advisor review-bench
persona wording can be tightened later.

## 0.7.2

### Agent-team execution gate, AEL dogfood fixes, and role architecture cleanup

This release bundles the already-gated CEO1 + CEO2 + execution-layer MVP work.

**AEL dogfood hotfixes**

- Fixed `AIPLUS_BRAND` lobby setup/status preambles so branded wrappers no
  longer leak the literal `aiplus:` prefix.
- Clarified `agent_route`, MCP `agent_route`, status output, and AEL PI
  persona wording: default route is recorded/queued-only and does not imply a
  worker runtime has started.
- Added the Advisor strategic recommendation memory bridge so AEL Advisor
  recommendations can be captured into shared team memory.
- Reduced `aiplus memory add --kind decision --title ... --summary ...`
  friction for concise decision capture.
- Added LaTeX auxiliary/intermediate outputs to `.gitignore`.

**Agent-team role architecture**

- Promoted `ui-designer`, `ai-integration`, and `security-reviewer` to
  core/internal roles across install, list/status, docs, adapters, personas,
  and tests.
- Kept the remaining on-demand functional experts as `tech-writer`, `devops`,
  and `researcher`; v0.2 stub experts remain stubs.
- Recorded `product-lead` as backlog only; no new role is shipped in v0.7.2.

**Execution-layer MVP**

- Added opt-in execution with
  `aiplus agent route --execute <role> "<task>"`; default
  `aiplus agent route <role> "<task>"` remains recorded/queued-only.
- MCP `agent_route` now accepts `execute: true` to reach the same execution
  surface.
- Added MVP backends:
  `AIPLUS_AGENT_EXEC_BACKEND=fake|local` and
  `AIPLUS_AGENT_EXEC_COMMAND` for explicit local execution.
- Safely reuses clean configured role worktrees, including worktrees on a
  non-`agent/<role>` branch, and fails before backend launch for dirty,
  non-repo, or mismatched worktree paths.
- Runs the local backend in the role worktree cwd, falling back to project root
  only for roles without a worktree.
- Records `worktree_path` in execution state and status JSON/human output.

Known limitation: this is an execution-layer MVP, not full long-lived native
Codex/Claude/OpenCode async session supervision. Native runtime session
orchestration remains future work.

## 0.7.1

### One-command lobby update + behavior CI graceful auth

`aiplus self update` now force-refreshes GitHub Latest instead of trusting
the binary's compile-time `RELEASE_TAG`, fixing the stale
`latest_release_version` path from Task #99. The refreshed latest tag is
cached at `~/.config/aiplus/latest-release.json` for cheap `aiplus status`
reads.

The bare `aiplus` lobby now supports first-run one-command setup:
available runtimes are detected from `PATH`, missing project setup can be
auto-installed, partial runtime failures warn without blocking successful
runtimes, and risky directories require confirmation. The lobby also checks
for updates at most once per 24 hours, auto-updates within the same major
version, re-execs after success, and reports major-version bumps as
manual-only.

Doctor/schema support now accepts v0.7.x manifests, restoring green CI after
the v0.7.0 cross-runtime release.

The agent-team persona behavior workflow now degrades gracefully when its
Anthropic credential is missing or invalid: structural checks still run, the
behavior job reports the auth failure clearly, and the workflow no longer
fails the whole PR solely because live provider auth is unavailable.

## 0.7.0

### Cross-runtime session handoff (G-AT-CROSS-RUNTIME-HANDOFF)

When user resumes a session in the lobby and picks a **different
runtime** than the session's original, aiplus now transfers the
prior conversation as a compressed transcript to the new runtime.
Achieves ~98-99% subjective continuity for cross-runtime switches
(weekly use case for power users running codex + claude-code).

**UX**: runtime selection moves to UNCONDITIONAL second step (always
asked after picking resume/new). If selected runtime matches the
resumed session's runtime → traditional resume (no handoff). If
different → handoff fires automatically.

**Tiered compression** for sessions >50K tokens:
- Recent ~13 turns: verbatim (~25K)
- Middle ~40 turns: brief summary (~15K)
- Earlier turns: condensed narrative summary (~10K)

**Summarization LLM**: codex primary, claude-haiku as fallback,
simple truncation as final fallback. Graceful degradation; handoff
never blocks even when LLMs unavailable.

**Lobby annotations**: handed-off sessions are marked
`[handoff from <source_runtime> N min ago]` so the resume picker
shows the relationship between original and continued sessions.

Per-runtime transcript extractors:
- codex: reads JSONL at `threads.rollout_path` from sqlite
  (corrected from earlier spec assumption of `conversation_items`
  table; CEO discovered actual schema empirically)
- claude-code: reads `~/.claude/projects/<cwd>/<id>.jsonl`
- opencode: reads sqlite + falls back to `opencode export` shell

**Documented deviations**: token estimate uses dependency-free
approximation (not tiktoken-rs); handoff link recorded post-exec
not pre-exec; 6-pair matrix tested as dry-run not live TUI
automation. See `docs/proposals/cross-runtime-handoff-impl-notes.md`.

This is the largest single feature ship in the v0.6.x line. Bumping
to v0.7.0 to mark the new cross-runtime interaction paradigm.

## 0.6.21

### Persona modernization v1 (G-AT-PERSONA-V1)

All 41 persona templates (8 aiplus core + 5 aiplus stubs + 11 aiplus
experts + 22 AEL roles/experts) updated with role-specific knowledge
of recent CLI surfaces shipped in v0.6.16-v0.6.20:

- `aiplus agent talk --resume <role>` — session resume (most roles)
- `aiplus status --all` — cross-project orchestration (CEO/PI)
- `aiplus release-status` — release pipeline visibility (advisor/CEO)
- `--tier <auto|haiku|sonnet|opus>` flag — model tier control (dispatch roles)
- `aiplus init` alias for `aiplus install` — bootstrap (any role advising on setup)
- `aiplus doctor` new checks (PATH-shadow + 3 team-drift) — diagnostic roles

AEL personas use `ael` command prefix; aiplus personas use `aiplus`.
Experts get only generic `--resume` guidance to keep their domain focus.

Closes the "agents don't know about new tools" gap flagged after the
v0.6.16-v0.6.20 ship sequence. Future feature ships should bundle
persona awareness updates in the same PR.

## 0.6.20

### Config-driven role aliases (G-AT-ROLE-ALIASES)

`team.toml` now supports a `[role_aliases]` section: freeform input
(Chinese phrase, English phrase, partial role name) maps to a canonical
role id. `aiplus agent talk` and `aiplus agent route` consult this
table at resolve time.

Resolution order: exact role id → alias-exact (case-insensitive) →
ordered substring match → deprecated AEL hardcoded fallback (defensive).
IndexMap preserves insertion order so first-defined alias wins on
substring conflicts.

aieconlab team config (`assets/aieconlab/core/templates/econ-team.toml`)
ships with econ-specific aliases: `项目经理→pi`, `RD design→theorist`,
`reflect→advisor`, `实证→ra-stata`, etc. Migrated from `aieconlab_alias_canonical()`
(kept as defensive fallback when team.toml lacks `[role_aliases]`).

Wrappers like AEL (and future MailCue) can now delete their bash
NL-routing layers and ship their own team's `[role_aliases]` instead.
Unblocks AEL v1.0 Phase 1.

## 0.6.19

### Polish bundle (G-AT-POLISH-BUNDLE: Tasks #86 + #87 + #96 + #97)

**`aiplus update` helpful error** — when run outside an aiplus-managed
project, no longer prints cryptic `ERROR AiPlus manifest is missing`.
Instead suggests `cd` to a project or rebuilding from source.

**`aiplus init` alias** — `aiplus init` now works as an alias for
`aiplus install`. Same flags, same behavior. Matches the more common
new-project bootstrap nomenclature.

**`aiplus doctor` PATH-shadow detection** — when multiple `aiplus`
binaries are on `$PATH` (e.g. old `/usr/local/bin/aiplus` plus new
`~/.local/bin/aiplus`), doctor INFO-warns which one runs and which is
shadowed.

**`aiplus doctor` team-drift checks** — three new INFO-severity checks
catch the AEL-in-aiplus-team-project drift class:
- `DOCTOR_INFO_TEAM_ENV_OVERRIDE` — `AIPLUS_TEAM` env var differs from
  project's `active-team.txt` (normal for wrappers, but flag it)
- `DOCTOR_INFO_PERSONA_TEAM_MISMATCH` — roles in active team have no
  persona file in any of the v0.6.18 fallback paths
- `DOCTOR_INFO_RUNTIME_ADAPTER_GAP` — runtime is on PATH but not
  registered in `.aiplus/manifest.json`

### Release pipeline: post-release-smoke auto-trigger (Task #90)

`release.yml` now triggers `post-release-smoke.yml` via
`gh workflow run` (workflow_dispatch — exempt from GITHUB_TOKEN
restriction). Eliminates the manual `gh workflow run` step that was
required after every v0.6.14-v0.6.18 ship. No PAT setup needed.

## 0.6.18

### DX dispatch controls (G-AT-DX-BUNDLE: Tasks #4 + #5 + #93 + #94)

**Token budget warning** — `aiplus agent route` and `aiplus agent talk`
now print a one-line stderr warning when weekly token usage exceeds 75%
of the configured cap (`AIPLUS_WEEKLY_CAP_USD`, default $20k). Non-
blocking; no prompt. You see the burn before dispatch, not at week-end.

**`--tier <auto|haiku|sonnet|opus>` flag** — `aiplus agent talk` and
`aiplus agent route` accept a tier override. `--tier auto` resolves
per role config's new `suggested_tier` field. Light roles (qa, tech-
writer, devops) default to haiku; engineering roles default to
sonnet; strategy roles (architect, advisor, reviewer, ceo) default to
opus. Default behavior unchanged — only takes effect when flag passed.

**Direct CLI default-bypass-on** — `aiplus agent talk <role>` now
defaults bypass-on, matching lobby's existing behavior. Use `--safe`
or `AIPLUS_SAFE=1` to opt out. The old `--bypass` and `--lobby-bypass`
flags are preserved as no-ops for backward compat.

**Team-aware persona resolution** — `persona_path_for` now falls
back to `.aiplus/agents/_teams/<team>/personas/<role>.md` when
`AIPLUS_TEAM` is set, fixing the "AEL roles can't launch from an
agent-team project" case that surfaced when v0.6.16's brand
parameterization let lobby show team-foreign roles whose personas
weren't in the standard path.

### Self-dev smoke workflow (G-AT-SELFDEV-SMOKE)

New `.github/workflows/self-dev-smoke.yml` runs daily, exercising the
user-facing install path (`curl install.sh | bash` → `aiplus install
--runtime codex --yes` → `aiplus doctor`) on a clean macos-14 runner.
Guards against drift between dogfood and shipped-binary behavior —
the failure class that produced the MailCue persona drift incident.

Live talk dispatch deferred (no test API key wired up); manual trigger
remains via `workflow_dispatch`.

## 0.6.17

### Cross-project observability (G-AT-STATUS-ALL + G-AT-RELEASE-STATUS)

`aiplus status --all` shows recent activity across all aiplus-registered
projects in one screen: active sessions, recent release-like dispatches,
and stale registry notes. It reads `~/.config/aiplus/installed-projects.json`
and aggregates the v0.6.16 runtime session scanners across projects.

`aiplus release-status` shows the current release pipeline state for the
current or specified GitHub repo: recent releases, latest/draft/superseded
state, stuck draft warnings, and smoke pass/fail/race annotations.

Task #91 removes bogus post-release-smoke matrix targets
`x86_64-apple-darwin` and `x86_64-unknown-linux-gnu`; the release smoke
matrix now covers only shipped release assets.

## 0.6.16

### Lobby resume + brand parameterization (G-AT-TALK-RESUME)

`aiplus` (no args) now lists recent sessions in this directory as
resumable candidates BEFORE the role picker. Press Enter to resume the
most recent; type a number to pick another or to start fresh.

The default lobby brand and role list are configurable via env vars
(`AIPLUS_BRAND`, `AIPLUS_TEAM`, `AIPLUS_DEFAULT_ROLE`) so wrappers
(AEL, MailCue, future) share the same lobby UX with their own brand
and roles. AEL v0.2.10 adopts this — see AEL CHANGELOG.

New flag: `aiplus agent talk --resume <role>` skips the lobby and
directly resumes the most recent session for that role (or `--last`
fallback if no role-tagged sessions yet).

Sessions started in v0.6.16+ are tagged `[BRAND:role:project]` in
title for future role-aware filtering. Pre-v0.6.16 sessions still
resume but display as `[?]` in the picker.

Bypass-approval is now the default for all interactive launches from
the lobby (Owner-trusted local context). Use `--safe` for the rare
case where you want approval prompts.

### Post-release smoke trigger race fix (Task #89)

`post-release-smoke.yml` now triggers from `release.published` instead
of `workflow_run`, avoiding the race where smoke tried to validate a
draft release before assets were ready.

## 0.6.15

### Team-aware talk prompt brand

`aiplus agent talk` now introduces the active `aieconlab` team as the
AEL virtual team in the runtime prompt, while preserving AiPlus as the
default team brand for the original agent-team and unknown teams.

## 0.6.14

### Token cost coverage: session + dispatch (G-AT-COST-COVERAGE-1)

`agent_token_cost` MCP tool + `aiplus agent token-cost` CLI now report
**both AiPlus dispatch tokens AND local codex session tokens** by
default. Previously the tool only counted aiplus agent dispatch
overhead — for Owner who burns most tokens in the codex main session,
the answer was always ~0 and never matched the actual question.

New fields per window:

| Field | Source |
|---|---|
| `dispatch_tokens` / `dispatch_usd` | AiPlus dispatch log |
| `session_tokens` / `session_usd` | Local codex `~/.codex/state_5.sqlite` (READ-ONLY) |
| `total_tokens` / `total_usd` | Sum of above |

New CLI flags:

```bash
aiplus agent token-cost --window 168h         # weekly, default both
aiplus agent token-cost --session-only        # codex sessions only
aiplus agent token-cost --dispatch-only       # aiplus dispatch only
```

New windows: `7d` / `168h` for weekly rollups.

SKILL.md + tool description add Chinese trigger examples ("本周烧了多少 token",
"最近花了多少") so Discovery layer routes natural-language queries correctly.

**Caveat**: codex's `threads.tokens_used` sqlite field is total tokens only —
not input/output split — so `session_usd` is **estimated** by pricing all
tokens at the model's input-token rate. Real cost is somewhat less. Order
of magnitude is correct.

Claude Code session rollup deferred to a future goal; codex session
support ships now.

### Project freshness: mcp-register update + persona refresh + doctor warnings (G-AT-FRESHEN-1)

After MailCue dogfood revealed that the codex MCP server pointer
silently stayed on an old vendored binary while the installed `aiplus`
binary upgraded — defeating two weeks of Discovery v2 work without
warning — this release adds freshness detection + repair tooling.

**`aiplus mcp-register --runtime <r>`** now detects an existing config
entry pointing to a different binary path, prompts to update (TTY) or
auto-updates with notice (non-TTY).

**New command `aiplus persona refresh [--dry-run] [--yes]`**:
walks `.aiplus/agents/personas/*.md` + `.aiplus/AGENTS.aiplus.md`,
compares each AiPlus Tool Discovery preamble block to canonical
templates, and replaces ONLY the preamble — preserving project
customizations in the persona body.

**`aiplus doctor`** adds two INFO-severity warnings:
- `DOCTOR_WARN_MCP_BINARY_STALE` — configured MCP binary path differs from current `aiplus`
- `DOCTOR_WARN_PERSONA_DRIFT` — persona file missing or has outdated discovery preamble

### Install smoke test (G-AT-INSTALL-SMOKE-1)

After today's `zsh: killed aiplus` macOS 26.4 SIGKILL incident where
install.sh printed PASS but the installed binary was unrunnable,
`install.sh` now runs a post-install smoke test (runs `aiplus --version`
after copy). On non-zero exit: `SMOKE_FAIL=exit=<code>`, `INSTALL_STATUS=FAIL`,
clear remediation hints, `exit 1`. Catches platform-specific install
failures at install time instead of first-run time.

### Bundled commits

- 25b624b — install.sh smoke test
- f4a9f9b — freshen (mcp-register + persona refresh + doctor warns)
- 7c8339f — cost-coverage (session tokens + Chinese examples + new flags)

## 0.6.13

### Public bypass passthrough for agent talk

`aiplus agent talk` now accepts a visible `--bypass` flag and the
equivalent `AIPLUS_BYPASS=1` env var. Both append the correct
runtime-specific approval-bypass flag when launching the selected
runtime:

| Runtime | Flag |
|---|---|
| Codex | `--dangerously-bypass-approvals-and-sandbox` |
| Claude Code | `--dangerously-skip-permissions` |
| OpenCode | `--dangerously-skip-permissions` |

Direct `aiplus agent talk` calls still default to approval-mode unless
`--bypass`, hidden lobby passthrough, or `AIPLUS_BYPASS=1` is present.
The help text documents the risk inline, and the regression test uses
per-runtime fake CLIs to assert both bypass and non-bypass argv.

### macOS 26.4 SIGKILL fix

macOS 26.4.1 introduced a new kernel-level check that SIGKILLs Rust-
produced binaries with `flags=0x20002 (adhoc, linker-signed)`. This
affected every `aiplus` install on macOS 26.4: install.sh would report
PASS but `aiplus` would print `zsh: killed aiplus` on first run.

**Fix in release.yml**: after `cargo build --release` on macOS, re-sign
the binary with plain ad-hoc (`codesign --force --sign - --timestamp=none`).
This strips the `linker-signed` flag -> `flags=0x2 (adhoc)` -> macOS 26.4
allows execution.

**Backup in install.sh**: defensively re-sign after `cp` to
`$INSTALL_DIR/aiplus` on Darwin. Belt-and-suspenders so old install.sh
run against new releases also works.

**Affects**: every fresh `aiplus` install since macOS 26.4. Owner's
v0.6.11 and v0.6.12 binaries both reproduced the SIGKILL on
macOS 26.4.1 / build 25E253. Re-signing fixes it.

## 0.6.12

### Lobby runs in trusted-owner bypass mode by default

Lobby (`aiplus` bare command) now launches the chosen runtime with its
**approval-bypass flag** by default:

| Runtime | Flag |
|---|---|
| Codex | `--dangerously-bypass-approvals-and-sandbox` |
| Claude Code | `--dangerously-skip-permissions` |
| OpenCode | `--dangerously-skip-permissions` |

The spawn line shows the mode so you always know which one you got:

```text
[Launching codex with ceo persona (bypass-mode)...]    ← default
[Launching codex with ceo persona (safe-mode)...]      ← --safe / env
```

### Why

`aiplus` lobby is for the project Owner's own machine on their own
project — the agent is already trusted, and asking for approval on
every action turned the lobby into a click-throughfest. Bypass-by-
default matches how Owners actually work.

### Escape hatches

Two ways to keep approval-mode:

```bash
aiplus --safe                       # one-off
AIPLUS_LOBBY_SAFE=1 aiplus          # session / shell default
```

Both also accept `true`, `yes`, `on` for the env var.

Non-lobby code paths are untouched — `aiplus agent talk --runtime …`
called directly (not through lobby) still uses runtime defaults (no
auto-bypass). The `--lobby-bypass` switch on `agent talk` is hidden
and lobby-internal.

### Safety posture (read this)

Bypass mode **skips runtime approval prompts**. It is intended for
**personal-machine, personal-project Owner workflows**. In shared,
multi-user, CI, or production-like environments, run with `--safe`
or `AIPLUS_LOBBY_SAFE=1` so approval prompts stay on.

### Files

- `crates/aiplus-cli/src/lobby/mod.rs` — passes hidden `--lobby-bypass`
  by default, prints mode label, honors env var
- `crates/aiplus-cli/src/agent/talk.rs` — accepts hidden lobby-only
  `--lobby-bypass` and maps it to per-runtime flag
- `crates/aiplus-cli/src/main.rs` — global `--safe` flag on bare aiplus
- `crates/aiplus-cli/tests/lobby.rs` — covers default-bypass, --safe,
  env-var (3 scenarios) with fake runtime

## 0.6.11

### Bare `aiplus` lobby — one-word entry point

```text
$ cd MyProject
$ aiplus                       # ← that's it
```

Bare `aiplus` (no subcommand, run in a project dir) now drops you
into a lobby:

1. **Auto-setup if needed.** If `.aiplus/` doesn't exist yet, lobby
   runs `aiplus install all --yes` and `aiplus mcp-register`
   automatically. Runtimes whose CLI isn't on PATH (claude / codex /
   opencode missing) are silently skipped — no friction, no error.
2. **Role picker.** Lists the active team's roles (core + experts)
   with one-line descriptions. Pressing Enter defaults to `ceo`.
   Type partial names (e.g., `eng` → `engineer-a` if unique).
3. **Runtime picker** (only when multiple runtimes are installed).
   With one runtime on PATH, lobby skips this prompt and uses it.
4. **Launch.** Spawns the chosen runtime with the chosen role's
   persona loaded (`aiplus agent talk --runtime <r> <role>`).

Existing `aiplus <subcommand>` paths are unchanged. Lobby is just
the bare-command default.

### What this enables

Day-to-day flow becomes: `cd into-project; aiplus; Enter; Enter`.
No more remembering subcommands for the common case of "I want to
work with the agent team on this project". The new `aiplus` lobby
is the entry door; the v0.6.9-v0.6.10 discovery layer + MCP tools
take over once you're inside a runtime session.

### Internal

- New `crates/aiplus-cli/src/lobby/` module (536 lines): auto-install
  helper, runtime detection (which / Command-based probe), role/runtime
  prompts with partial-match completion, spawn dispatch.
- `crates/aiplus-cli/src/main.rs`: bare-aiplus arm routes to lobby.
- New `crates/aiplus-cli/tests/lobby.rs` (189 lines): 7 integration
  tests covering fresh install path, single-runtime skip, ceo default,
  runtime picker, unknown role retry.
- Test growth: 585 → 592.
- `install.sh` fallback synced to `v0.6.11`.

### Migration notes

- No breaking CLI changes. `aiplus <subcommand>` paths unchanged.
- First-time bare `aiplus` in any project triggers auto-install
  (the same effect as running `aiplus install all --yes` manually).

## 0.6.10

### Autoflow coverage validation harness

- `crates/aiplus-cli/tests/autoflow_coverage_matrix.rs` — 884-line
  programmatic multi-runtime coverage harness. Spawns isolated codex
  and opencode in non-interactive mode, sends natural-language
  prompts, and records which MCP tool / CLI surface the agent calls.
- `docs/proposals/autoflow-validate-1-coverage-matrix.md` — 40-cell
  matrix (20 prompts × 2 runtimes) with PASS / FAIL / RUNTIME-
  LIMITATION per cell.
- First-run findings: OpenCode 18/20 PASS strict (90%) + 2 "FAIL"
  that are on examination the agent correctly following SKILL.md
  guidance (preferring `agent_route_score_only` over `agent_route`
  per Dispatch Flow rule; preferring `agent_doctor` MCP over
  `aiplus doctor` CLI per "Prefer MCP over CLI"). Effectively 20/20.
  Codex 20/20 RUNTIME-LIMITATION — harness's isolated CODEX_HOME
  setup omits `auth.json` copy, causing 401. Fix-in-place follow-up.

### Autoflow discovery — full feature coverage

v0.6.9 wired the discovery layer for 3 MCP tools (cost / planning / audit).
This release extends it to **the full aiplus feature surface**: all 14 MCP
tools plus 6 categories of non-MCP CLI features. Agents now have natural-
language → aiplus routing guidance for memory recording, compact prep,
velocity tracking, hardware signing setup, doctor checks, and team switching
— not just the 3 v0.6.9 cases.

**SKILL.md "Use These Tools First" extended** (in `.claude/skills/aiplus/`,
`.codex/skills/aiplus/`, `.opencode/skills/aiplus/`) now groups guidance by
topic:

- Cost / spending / token usage → `agent_token_cost` MCP
- Planning / task preview → `agent_route_score_only` MCP
- Audit / log integrity → `agent_audit_verify_log` MCP
- Dispatching / role management → `agent_route`, `agent_invite`, `agent_dismiss`,
  `agent_disable` / `agent_enable`, `agent_integrate`, `agent_talk` (all MCP)
- Team status / configuration → `agent_status`, `agent_list`, `agent_set_team`,
  `agent_doctor` (all MCP)
- Memory / context → `aiplus memory record / context / status` (CLI)
- Compact / session token efficiency → `aiplus compact prepare / resume / savings`
- Velocity / time tracking → `aiplus velocity estimate / report`
- Identity / commit signing → `aiplus identity setup-signing`
- Doctor (cross-cutting health) → `aiplus doctor [--quiet] [--check-keyring]`

**MCP tool descriptions** for the 11 previously-generic-described tools
(`agent_route`, `agent_status`, `agent_set_team`, `agent_list`, `agent_doctor`,
`agent_invite`, `agent_dismiss`, `agent_disable`, `agent_enable`,
`agent_integrate`, `agent_talk`) now all start with "PREFERRED programmatic
surface for <intent>" plus a CLI-alternative reference, matching the v0.6.9
pattern for the 3 new tools.

**Multi-turn dispatch flow** — SKILL.md now has explicit "Dispatch Flow" and
"Multi-turn Patterns" sections showing the 4-step pattern (score → confirm →
dispatch → integrate) and common multi-turn conversation patterns (follow-up
questions, mid-flight scope change, ambiguous intent disambiguation).

**Project-root preamble** (in `CLAUDE.md` / `AGENTS.md` /
`.opencode/instructions/aiplus.md`) extended to cover the full intent list +
a compact dispatch-flow summary appended after the intent list.

### What this enables

Owner's vision "user 自然语言 → agent 主动调 aiplus 各种功能" is now wired
across the full feature surface. Empirical validation across runtimes happens
in v0.6.11 G-AT-AUTOFLOW-VALIDATE-1 (next).

### Internal

- 2 parallel CEO sessions on `feat/autoflow-coverage` (Session A) +
  `feat/autoflow-multiturn` (Session B) implemented this release. Ownership
  matrix per CONTRACT v1.1 App D Rule D.3 cleanly separated work areas;
  one merge conflict in a shared test file resolved by keeping both
  branches' assertions. 582 workspace tests pass (was 581 in v0.6.9; net
  +1 from Session A's expanded coverage assertions).
- `install.sh` fallback bumped to `v0.6.10` (parity test).

### Migration notes

- No breaking CLI changes.
- Re-run `aiplus install <runtime>` to land the v0.6.10 SKILL.md and
  preamble content in existing projects. The discovery-block managed-block
  is idempotent — re-running replaces but does not duplicate.
- Existing v0.6.9 discovery still works; this release is additive.

## 0.6.9

### Agent autoflow — natural-language → aiplus MCP tools

When a user asks about token costs, planning, or audit in natural language,
the agent (Codex / Claude Code / OpenCode) now reaches for AiPlus MCP tools
instead of bypassing aiplus with shell grep or training-data answers. Two
mechanisms together make this work:

- **Per-runtime SKILL.md files** written to
  `.claude/skills/aiplus/SKILL.md`, `.codex/skills/aiplus/SKILL.md`, and
  `.opencode/skills/aiplus/SKILL.md` during `aiplus install`. Each file
  explicitly steers the agent toward MCP tools, lists prefer-MCP-over-CLI
  patterns, and includes concrete dialogue examples ("user says 'implement
  X' → call `agent_route_score_only` first, not internal knowledge").
- **Project-root preamble** in `CLAUDE.md` / `AGENTS.md` /
  `.opencode/instructions/aiplus.md` with a small `<!-- aiplus-discovery-block
  -->` managed-block summarizing the intent → tool mapping. Idempotent on
  re-install.
- **MCP tool descriptions for `agent_token_cost`, `agent_audit_verify_log`,
  `agent_route_score_only`** updated to start with "PREFERRED programmatic
  surface" and reference the CLI alternative, so the agent picks MCP over
  `aiplus agent <verb>` CLI subcommands.

Multi-runtime empirical validation (Advisor independent live re-test, 6
prompts):
- OpenCode: 3/3 prompts triggered the expected MCP tool (cost prompt
  fully executed and returned structured result; planning prompt
  triggered then rejected by opencode non-interactive permission gate;
  audit triggered).
- Codex: 3/3 prompts triggered the expected MCP tool, but codex
  non-interactive mode cancels MCP calls mid-flight before the tool
  returns. This is a codex runtime limitation, not an AiPlus issue;
  interactive codex sessions and Claude Code are unaffected.

### Behind the scenes

This release lands **two iterations** of discovery work:

- v1 (G-AT-AGENT-AUTOFLOW-DISCOVERY-1) shipped initial SKILL.md +
  preamble. Independent Advisor re-test showed only 1/3 prompts
  triggered the expected MCP tool: cost went to CLI subcommand,
  planning bypassed aiplus entirely, audit triggered then cancelled.
  v1 was STOPPED at Phase C ratification per spec strict rule.
- v2 (G-AT-AGENT-AUTOFLOW-DISCOVERY-2) diagnosed three root causes
  and redesigned: explicit prefer-MCP-over-CLI language, concrete
  dialogue examples for non-trivial coding tasks, enhanced MCP tool
  descriptions. Independent re-test confirms 5-6/6 MCP triggered.

### Internal

- `crates/aiplus-cli/src/main.rs`: install logic extended to emit
  SKILL.md + project-root preamble per runtime.
- `crates/aiplus-cli/src/mcp_server.rs`: descriptions of three new
  MCP tools enhanced to encourage agent to prefer MCP over CLI.
- `assets/aiplus-agent-team/adapters/<runtime>/skills/aiplus/SKILL.md`:
  three new asset files (claude-code, codex, opencode), shipped via
  `aiplus install`.
- `crates/aiplus-cli/tests/agent_autoflow_discovery.rs`: new
  regression tests for file content + idempotency.
- Test growth: 579 → 581 workspace tests.
- `install.sh` fallback bumped to `v0.6.9` (parity test).

### Known limitations

- **Codex non-interactive mode** cancels MCP calls mid-flight. The
  agent does correctly try the right MCP tool, but the runtime
  doesn't return the structured result. Interactive codex works
  fine. Documented in SKILL.md.
- **OpenCode non-interactive mode** uses a permission gate that may
  reject MCP tool calls when no interactive user is present.
  Interactive opencode works fine.

### Migration notes

- No breaking CLI changes.
- Re-run `aiplus install <runtime>` once after upgrading to land the
  SKILL.md + preamble files in your projects. Existing projects
  continue to work without the new discovery layer until you re-run
  install.
- The `<!-- aiplus-discovery-block -->` managed-block in CLAUDE.md /
  AGENTS.md is idempotent: re-running `aiplus install` replaces the
  block content but doesn't duplicate.

## 0.6.8

### Bug fixes (userland-test discoveries)

- **`aiplus mcp-register --runtime claude-code`** is now accepted as
  a synonym for `--runtime claude` (previously rejected with "Valid:
  codex, claude, opencode"). This matches the runtime name used by
  `aiplus install claude-code` and the README. Both `claude` and
  `claude-code` forms work; help text now lists both.
- **`aiplus doctor --quiet`** (alias `-q`) is now a real flag. v0.6.5
  CHANGELOG documented this feature but the binary rejected the flag
  (clap variant was never updated). Now: emits only NEEDS_FIX items
  and the final `DOCTOR_STATUS` line; suppresses successful/INFO
  detail lines.
- **`aiplus mcp-register` now honors `CODEX_HOME` and
  `CLAUDE_CONFIG_DIR` env vars** before falling back to the default
  config paths (`~/.codex/config.toml`, `~/.claude/.mcp.json` etc.).
  A new `--config-dir <path>` flag provides explicit override. This
  enables safe isolated testing without touching the user's real
  configuration directory. (Previously hard-coded to `~/.codex/`
  etc., which silently mutated user config during CI / dev test
  setup.)
- **Expert auto-summoning by LLM intent now works in practice.**
  v0.6.5 G-AT-AUTOSUMMON-INTENT-1 shipped the feature but it failed
  silently on real userland: `auto_summoned=[]` despite valid
  `intent_hint` and API keys in env. Root cause was provider-
  selection: the classifier only tried Anthropic Haiku, and silently
  returned empty when only `OPENAI_API_KEY` was available. Fix:
  classifier now tries both providers (Anthropic preferred,
  OpenAI fallback), and surfaces `skipped=<reason>` or
  `failed=<error>` warnings on the CLI output line + in the
  `dispatch-log.jsonl` `warnings` field. Users now see why auto-
  summon did or didn't fire.

### Internal

- `crates/aiplus-cli/tests/userland_bugfix.rs`: 5 new regression
  tests covering each of the four bugs above. Future Phase C
  ratifications can re-run these specific tests to verify userland
  command paths haven't regressed.
- `install.sh` fallback bumped to `v0.6.8` (parity test).
- Test growth: 574 → 579 workspace tests.

### Documentation

- README + README.zh-CN: `claude-code` runtime naming clarified.

### Migration notes

- No breaking CLI changes.
- Auto-summon previously returning `[]` will now return matched
  experts (when intent matches by LLM). If you have downstream
  consumers that depended on the empty result, they'll see new
  entries.
- `--quiet` is a new doctor flag; default doctor output unchanged.
- mcp-register on default-config-dir setups: behavior unchanged.
  Only matters if `CODEX_HOME` / `CLAUDE_CONFIG_DIR` is set, in
  which case those paths are now honored (more intuitive).

## 0.6.7

### Features — Agent discoverability via MCP

- **Three new MCP tools registered** so the user's agent (Claude Code
  / Codex / OpenCode, configured via `aiplus mcp-register`) can
  discover and invoke recent v0.6.5 / v0.6.6 features without manual
  user invocation:
  - **`agent_token_cost`** — wraps `aiplus agent token-cost`. Args:
    `window` (optional `"1h"|"8h"|"24h"`), `by_role` (optional bool),
    `top_n` (optional int). Returns structured JSON the agent can
    reason over (tokens, USD, top tasks, by-role detail). The agent
    can now proactively check burn before authorizing expensive
    dispatches.
  - **`agent_audit_verify_log`** — wraps `aiplus agent audit
    verify-log`. Returns `{verdict: PASS|FAIL, first_bad_line, reason}`.
    The agent can periodically verify the dispatch log's hash chain.
  - **`agent_route_score_only`** — wraps `aiplus agent route
    --score-only "<task>"`. Returns the coordinator's would-staffing
    decision (complexity, risk, tier, staffing_roles, forced_by_risk,
    auto_summoned) without spending any tokens. The agent can
    pre-flight a task before committing to dispatch.
- The 11 existing MCP tools (`agent_route` / `agent_status` /
  `agent_set_team` / etc.) are unchanged. New tools are pure
  additions.

### Internal

- `crates/aiplus-cli/src/mcp_server.rs`: 3 new tool JSON definitions
  + 3 new subprocess-dispatch functions following the established
  pattern of the 11 existing tools.
- `crates/aiplus-cli/tests/agent_autoflow_mcp.rs`: new live MCP
  integration test that starts `aiplus mcp-serve`, sends JSON-RPC
  `tools/list` (verifies 3 new tools listed), sends `tools/call`
  for each (verifies happy path), and sends invalid args (verifies
  `isError=true` reply).
- Test growth: 569 → 574 workspace tests.
- `install.sh` fallback bumped to `v0.6.7` (parity test).

### What this enables (downstream)

- The agent's tool inventory grows by 3 entries the next time
  `aiplus mcp-register` is run against a configured runtime. No
  config edits needed in `~/.codex/` / `~/.claude/` / `~/.config/opencode/`.
- The agent decides when to call these on its own per its prompt
  heuristics. Owner observes during continued dogfood whether the
  agent uses them or ignores them; that signal informs whether to
  also do Option B (SKILL.md guidance) and Option C (`aiplus install`
  opt-in prompts).

### Migration notes

- No breaking CLI changes.
- Existing MCP integrations re-fetch the tool list per session, so
  the new tools become available automatically.

## 0.6.6

### Features

- **`aiplus-token-cost` is now a 7th bundled substrate module** with
  its own source-of-truth repo at
  [github.com/izhiwen/AiPlus-Token-Cost](https://github.com/izhiwen/AiPlus-Token-Cost).
  Two usage modes: (a) standalone via `curl -L
  .../AiPlus-Token-Cost/releases/latest/download/aiplus-token-cost-aarch64-apple-darwin.tar.gz
  | tar xz` then `aiplus-token-cost`, or (b) bundled — `aiplus
  install` now deploys both `aiplus` and `aiplus-token-cost`
  binaries from the same release tar.gz, and `aiplus agent
  token-cost` continues to work as the subcommand path. Module
  manifest (`assets/aiplus-token-cost/aiplus-module.json`) extends
  the schema with a new `binaryAssets` array field signaling
  binary-shipping modules vs data/template substrate modules.
- **`aiplus doctor` adds `aiplus-token-cost` PATH check** —
  INFO-level confirmation that the standalone binary is reachable
  from PATH after bundle install.

### Platform support narrowed

- **Pre-built binaries now ship for two platforms only**: Apple
  Silicon Mac (`aarch64-apple-darwin`) and Intel Windows
  (`x86_64-pc-windows-msvc`). Owner decision: focus distribution
  on the two platforms actually maintained.
- **Dropped from CI release matrix**: `x86_64-apple-darwin` (Intel
  Mac), `x86_64-unknown-linux-gnu` (Linux), `aarch64-unknown-linux-gnu`
  (Linux ARM). The CI release workflow no longer cross-builds these.
- **Users on dropped platforms** can still build from source:
  `git clone https://github.com/izhiwen/AiPlus && cargo build
  --release -p aiplus-cli`. Existing installed binaries continue
  to work; this only affects future pre-built downloads.
- `install.sh` now refuses non-Apple-Silicon-Mac platforms with a
  clear unsupported message + source-build instructions.

### Internal

- Release workflow assembles a dual-binary tar.gz per supported
  platform: builds `aiplus` natively, downloads the matching
  `aiplus-token-cost` binary from
  AiPlus-Token-Cost releases, and packages both into one archive
  per target.
- `install.sh` + `install.ps1` extract and deploy both binaries;
  backward-compatible with older single-binary archives (silently
  skips the second-binary step if not present).
- `crates/aiplus-core/src/module_manifest.rs` parser supports the
  new `binaryAssets` field; `crates/aiplus-core/schemas/aiplus-module.schema.json`
  documents the schema extension.
- `install.sh` fallback version bumped to `v0.6.6` (parity test).
- README + README.zh-CN updated from "6 bundled modules" to "7"
  with token-cost entry pointing at both standalone and bundled
  install paths.

### Migration notes

- No breaking CLI changes.
- Existing `aiplus install` users will see the new
  `aiplus-token-cost` binary land in `~/.local/bin/` alongside
  `aiplus`. If you don't want it on PATH, the standalone binary is
  inert when not invoked.
- Standalone-only users (never running `aiplus install`) can use
  `aiplus-token-cost` directly without changes.

## 0.6.5

### Removed

- **Cross-provider auditor (`--auditor-provider`)** — the feature
  shipped in v0.6.4 G-AT-SEC-1 D2 has been removed before public
  dogfood. After honest re-evaluation: solo-Owner value was marginal
  (manual provider-swap covers the same need), per-task token cost
  doubled, and no monitoring layer existed. Tamper-evident dispatch
  log and Mac Secure Enclave commit signing (the other two SEC-1
  features) remain shipped and supported. Removed: `--auditor-provider`
  CLI flag, route auditor invocation path, `auditor_verdict` event
  emission, and the `auditor_provider_configured` doctor INFO line.
  3 auditor smoke tests deleted. Legacy v0.1 Auditor (acceptance-mode
  weekly_spot_check) is a different subsystem and is unaffected.

### Features

- **Auto-summoned experts now classified by LLM intent**, not brittle
  keywords. Each role with an `[autosummon]` section declares an
  `intent_hint` natural-language description; the coordinator asks a
  lightweight LLM "does this task match this intent?" per dispatched
  task and joins matching experts to staffing. Reuses the v0.6.0 G2
  semantic dispatch gate's LLM-call plumbing. Decisions are cached
  in-process (FIFO, default 1000 entries) so a repeat task in the
  same process incurs no second LLM call. Initial trigger sets ship
  for `security-reviewer` (intent: 支付 / auth / credentials / OWASP /
  CVE / 漏洞), `tech-writer` (intent: docs / README / API docs /
  tutorial), and `ai-integration-specialist` (intent: LLM / prompt /
  embedding / RAG / fine-tune). Migration: replace `keywords = [...]`
  with `intent_hint = "..."` in role TOML; previous keyword fields
  are no longer read.
- **`aiplus agent token-cost`** — new subcommand showing token
  consumption and USD cost in rolling 1-hour / 8-hour / 24-hour
  windows, plus a top-5 most-expensive-tasks list. Per-task primary
  view + per-role detail view via `--by-role`. Pricing source:
  community-maintained LiteLLM JSON
  (`model_prices_and_context_window.json`), fetched once per day and
  cached at `~/.cache/aiplus-token-cost/pricing.json`; falls back to
  embedded constants if the fetch fails; a local
  `.aiplus/pricing.toml` overrides both for project-specific or
  enterprise rates. Each invocation also appends an hourly snapshot
  row to `.aiplus/agents/token-cost-snapshots.jsonl`. Lives in the
  new sibling crate `aiplus-token-cost/`.
- **`aiplus doctor --quiet`** — suppresses the INFO chatter, shows
  only WARN+ and FAIL. Useful for CI gates and noisy-day debugging.

### Internal

- **`AdapterResult` return-value plumbing** — `route_known_role` and
  friends now return `Result<AdapterResult>` instead of `Result<()>`,
  threading the primary adapter's structured output back to callers.
  This unblocks any future feature that needs to act on adapter
  output programmatically.
- **Dispatch-log rows now carry `schemaVersion: "0.4.0"`** — every
  JSONL row written to `.aiplus/agents/dispatch-log.jsonl` includes
  this field so downstream consumers can branch on schema cleanly
  instead of feature-detecting each individual field. Field is
  purely additive; old parsers ignoring unknown fields continue to
  work.
- **Pre-existing clippy lint debt cleaned up** —
  `cargo clippy --workspace --all-targets -- -D warnings` now PASSES.
  Roughly a dozen historical `aiplus-core` and older `aiplus-cli`
  lint issues fixed cosmetically (no semantic changes). This means
  clippy `-D warnings` can now be a binding CI gate.
- **install.sh / Cargo parity pre-commit hook** — `scripts/install-hooks.sh`
  installs a pre-commit hook at `.git/hooks/pre-commit` that refuses
  to commit if `aiplus-cli` Cargo.toml version field changes without
  the matching `install.sh` fallback bump. Prevents the parity drift
  that silently broke v0.6.0 → v0.6.1.
- **Briefing template Skill** — recurring CEO-briefing structure
  (worktree isolation / ownership matrix / day-0 narrow STOP rule /
  retry-once gate / phase structure / scope fence / deliverables /
  handoff endpoint) extracted into `aiplus-agent-team/skills/aiplus-ceo-briefing.md`
  for future Advisor reuse. Captures the proven pattern across 8
  prior briefings.
- Existing 16-entry calibration baseline preserved byte-identical;
  v0.3.1 auto-summon entries rewritten to assert intent-based
  matching.
- `install.sh` fallback bumped to `v0.6.5` (parity test enforced by
  new pre-commit hook).
- Test growth: 555 → 569 aiplus-cli + workspace tests
  (3 auditor smoke tests removed; ~17 new tests across intent /
  token-cost / polish smoke files).

### Migration notes

- Role TOML `[autosummon] keywords = [...]` → `[autosummon] intent_hint = "..."`.
  No fallback path: the keyword field is silently ignored after this
  release. Customized role configs need manual migration.
- `--auditor-provider` flag is no longer recognized; scripts using
  it will error.
- Dispatch-log consumers will see new `schemaVersion: "0.4.0"` field
  on all new rows. Old rows pre-upgrade are unaffected.
- Run `scripts/install-hooks.sh` once after pulling this version to
  activate the parity pre-commit hook.

## 0.6.4

### Layer-7 security upgrades (G-AT-SEC-1)

- **Tamper-evident dispatch log**: every new `coordinator_decision`
  row in `.aiplus/agents/dispatch-log.jsonl` is now chained via
  sha256 hash. New `aiplus agent audit verify-log` walks the chain
  and reports `VERIFY_LOG=PASS` or `VERIFY_LOG=FAIL line=N` if
  anything was tampered with. Legacy pre-genesis rows (from before
  this release) are ignored until the first chained row. `aiplus
  doctor` adds an `INFO dispatch_log_chain=<status>` line.
- **Cross-provider auditor (Layer 7)** via `aiplus agent route
  --auditor-provider <provider> "<task>"`: after the primary
  dispatch completes, the named provider (different from primary,
  enforced) is invoked via its non-interactive command (`codex
  exec`, `claude --print`, `opencode run`) to review the result and
  emit a structured verdict (`agree` / `disagree` / `flag`). The
  verdict lands in dispatch-log as a new `auditor_verdict` event.
  Catches single-provider hallucinations and bias even when both
  providers are otherwise capable.
- **Hardware-backed commit signing** via `aiplus identity setup-signing`:
  on macOS, configures git to sign commits with a Secure Enclave-
  backed SSH key (`ssh-keygen -t ecdsa-sk -O resident -O
  verify-required`); passwordless, biometric-gated, no YubiKey
  required. Supports `--dry-run` preview. Refuses to clobber any
  existing signing configuration. Non-macOS platforms degrade with
  a clear `SETUP_SIGNING_STATUS=UNSUPPORTED` message. `aiplus
  doctor` adds an `INFO commit_signing=<secure_enclave|ssh|gpg|none>`
  line.

### Internal

- Concurrent dispatch-log append race discovered during auditor
  integration testing and fixed with a process-local append mutex
  around hash-chain read + append; this affects parallel adaptive
  coordinator dispatches (introduced in v0.6.3).
- `aiplus-cli` gains a new top-level `identity` module for
  identity-related subcommands (currently `setup-signing`).
- Three new integration test files: `sec_1_tamper_evident_smoke.rs`,
  `sec_1_auditor_smoke.rs`, `sec_1_setup_signing_smoke.rs` (11 new
  tests). `cargo test --package aiplus-cli`: 363 passed (was 352);
  `cargo test --workspace`: 558 passed (was 547). All tests isolate
  `HOME` and `GIT_CONFIG_GLOBAL`; the test suite never touches the
  Owner's global git config.
- `install.sh` fallback bumped to `v0.6.4` for parity.

### Known deviations

- The cross-provider auditor currently receives the task + dispatch
  summary, not the primary's structured `final_text` / `tool_calls`
  output. This is a limitation of the current adapter-to-route
  return plumbing rather than a SEC-1 design choice; future
  AdapterResult plumbing improvement (v0.6.5+) will let the auditor
  review actual primary content.

### Migration notes

- No breaking CLI changes.
- The new hash chain starts at the first dispatch after upgrading;
  old log entries are preserved verbatim and skipped by `verify-log`.
- `aiplus identity setup-signing` is the only subcommand that
  modifies Owner's global git config, and only when explicitly run;
  use `--dry-run` to preview.

## 0.6.3

### Performance — HEAVY task dispatch now parallel

- **HEAVY-tier (and MEDIUM / LIGHT_CODE) dispatch is now parallel, not
  serial.** Previously when the adaptive coordinator staffed multiple
  roles, they ran one at a time. Now all staffed roles dispatch
  concurrently via a peer-based parallel primitive. Wall-clock overhead
  drops from ~6× single-role time on a HEAVY task to ~1-2×. Benchmark
  fixture (6 mock roles delayed 900ms each): 5.40s serial baseline →
  0.94s parallel = ~5.7× speedup.
- **Partial-failure semantics**: if one role errors mid-flight, the
  other roles continue to completion; the final result aggregates all
  outcomes rather than failing fast. You see all the work that
  succeeded, not just up to the first failure.
- New `kind=coordinator_peer` field on dispatch metrics distinguishes
  adaptive-coordinator-staffed roles from Perf-1's primary/sidecar
  dispatch pattern.

### Internal

- New `coordinator_batch` peer-based parallel primitive in `route.rs`,
  living alongside Perf-1's existing `route_batch` (which keeps the
  primary/sidecar model for `--workflow author-critic-fixer` and direct
  role dispatch). Shared `WorktreePool` and `route_known_role`; no
  infrastructure duplication beyond the spawn/join loop.
- WorktreePool was confirmed safe at 6-way concurrent fan-out; the
  existing `Arc<Mutex<WorktreePool>>` serialization is sufficient
  (Perf-1 had only been validated at 1+2=3-way).
- New `tests/coordinator_parallel_smoke.rs` covers 6-way fan-out,
  partial failure, WorktreePool contention, and wall-clock benchmark.
  `cargo test --package aiplus-cli`: 352 passed (was 348);
  `cargo test --workspace`: 547 passed (was 543).
- `install.sh` fallback bumped to `v0.6.3` for parity test.

### Migration notes

- No breaking CLI changes.
- **Dispatch order in `.aiplus/agents/dispatch-log.jsonl` is no longer
  guaranteed for adaptive-coordinator-staffed dispatches.** Roles
  run in parallel, so log lines for a single HEAVY-task batch may
  appear in any order. Consumers that depend on strict role ordering
  should sort by `timestamp` field instead.
- LIGHT_NO_CODE dispatch (no staffing) behavior unchanged — CEO still
  handles directly with no role dispatched.

## 0.6.2

### Adaptive coordinator polish (v0.3.1 P1)

- **Expert auto-summoning**: the coordinator now scans task text for
  domain-expert trigger keywords and adds matching experts to the team
  on top of the tier baseline. Initial trigger sets ship for three
  experts — `security-reviewer` (payment / auth / credentials / OWASP
  / CVE / vulnerability), `tech-writer` (README / doc / tutorial / API
  docs), and `ai-integration-specialist` (LLM / prompt / embedding /
  RAG / fine-tune / API key). Task "实现支付接口" now auto-summons
  `security-reviewer` on top of the HEAVY-tier baseline. New optional
  `[autosummon]` section in role TOML lets you add trigger sets for
  more experts without code changes.
- **Risk-based forced summoning**: high-risk tasks now staff a
  `reviewer` (risk ≥ 0.7) and `qa` (risk ≥ 0.85) even when the tier
  baseline wouldn't normally include them. `coordinator_decision`
  events expose which roles came from this gate via the new
  `forced_by_risk` array field.
- **TTL honoring (opt-in)**: disk-warm cache entries older than the
  role's `warm_bench_ttl_seconds` are now invalidated and cold-started.
  Disabled by default to preserve current dogfood behavior — enable
  with `[cache] enforce_ttl = true` in `.aiplus/agent-team.toml`. New
  `ttl_expired` field in the `coordinator_decision` log; `aiplus
  doctor` now reports cache age vs TTL per role.

### Internal

- Coordinator calibration regression suite extended from 16 to 26
  entries, covering all three new staffing dimensions
  (auto-summon / risk-forced / TTL). The original 16 entries are
  locked as scorer-rubric regression baseline.
- `install.sh` fallback version bumped to `v0.6.2` to maintain
  parity with `aiplus-cli` Cargo version (parity test enforces this).

### Migration notes

- No breaking CLI changes.
- Existing role TOMLs without an `[autosummon]` section continue to
  work unchanged (no auto-summon for that role).
- TTL enforcement is opt-in; existing disk-warm cache is not
  affected until you set `enforce_ttl = true`.
- Existing dispatch-log consumers see new `forced_by_risk`,
  `auto_summoned`, and `ttl_expired` fields on
  `coordinator_decision` rows. Older readers can ignore them.

## 0.6.1

### Quality + observability

- **Pre-flight scoring with `aiplus agent route --score-only "<task>"`**: ask
  the coordinator what it would do for a task without actually dispatching
  anyone or spending tokens. Prints the same `Adaptive coordinator:` line,
  the planned consult step, and the team it would staff. Chinese alias:
  `--打分`.
- **Coordinator audit trail**: every coordinator decision now writes a
  `coordinator_decision` event to `.aiplus/agents/dispatch-log.jsonl`, even
  for tasks the CEO handles directly (LIGHT_NO_CODE) or for `--score-only`
  dry-runs. Previously only role-dispatching decisions were logged, so half
  the coordinator activity was invisible to post-hoc auditing.
- **`aiplus doctor` warns when Bitwarden + missing API key**: emits
  `WARN_SECRET_BROKER_RUNTIME_AUTH` when `AIPLUS_SECRET_PROVIDER=bws`,
  agent-team has at least one active role, and neither `ANTHROPIC_API_KEY`
  nor `OPENAI_API_KEY` is in your shell environment. The warning includes a
  copy-pasteable fix line (`aiplus secret-broker run --aliases ... -- ...`).
  Catches the most common onboarding failure for BWS-backend users before
  the adapter spawn fails with a confusing auth error.

### Internal

- Coordinator calibration regression suite: new
  `crates/aiplus-cli/tests/coordinator_calibration.rs` driven by a 16-entry
  TOML fixture spanning all four tiers (LIGHT_NO_CODE / LIGHT_CODE / MEDIUM
  / HEAVY) and the boundary cases (complexity 2↔3, risk 0.69↔0.70).
  Detects accidental scoring drift in future coordinator changes.
- `aiplus agent route` first-run hint marker now lives under
  `~/.config/aiplus/` instead of the project working tree, so it no longer
  causes `git status` to show a dirty file after the first dispatch in a
  fresh project.

### Migration notes

- No breaking CLI changes.
- Existing dispatch-log consumers should expect new `coordinator_decision`
  event rows alongside the existing per-role dispatch rows. Filter by
  `event` field if you only want one kind.

## 0.6.0

### New features

- **Natural-language role triggers (G1)**: mid-session, say "you are CEO",
  "take the reviewer role", or "switch to PI" and the agent re-binds to that
  role and loads its memory namespace. No CLI command needed. Works in
  Codex, Claude Code, and OpenCode interactive mode. Verified at 10/10 on
  Codex and Claude Code test matrices; OpenCode `opencode run`
  non-interactive mode currently limited by upstream OpenCode.
- **Semantic dispatch gate (G2)**: the coordinator now parses the intent of
  a request (verb-object semantic analysis) before approving owner-gated
  operations. Quoting, backticks, or wording tricks can no longer bypass
  the gate. Includes `dispatch_gate=PASS` check in `aiplus doctor`.
- **~2× faster dispatch cycle (Perf-1)**: reviewer and QA dispatch run
  concurrently as parallel sidecars. Per-role worktrees live in a pool with
  shared build cache (`crates/aiplus-cli/src/agent/worktree_pool.rs`).
  Typical iteration drops from ~15-20 min to ~8-10 min with identical
  quality gates.
- `aiplus agent route --workflow author-critic-fixer <role> <task>` now
  records a three-phase author -> independent critic -> fixer workflow. AEL
  uses `referee` as the critic role and writes workflow audit records with
  distinct `agent_id` values for the author and critic phases.

### AEL additions

- Two new applied-economics specialist roles: **DoF Auditor** (degrees-of-
  freedom auditing) and **R&R Strategist** (revise-and-resubmit strategy
  for top-field submissions). Brings total to 8 core + 14 experts.
- LLM-as-Measurement correlation heatmap surfaced in main AEL README.
- Adapter READMEs document natural-language role switching per runtime.

### Safety

- Installer/module cleanup refuses to delete git-tracked project files. If
  cleanup encounters a tracked file, it aborts with a clear error and a
  module-manifest issue hint while preserving the file; untracked managed
  cleanup behavior is unchanged.
- `aiplus install <runtime>` after `aiplus add aieconlab` now preserves the
  active AEL team layout instead of falling back to default. Covered by new
  `cross_runtime_install_matrix` test.
- Dispatch gate hardened across six rounds of edge-case fixes: quoted
  commands, imperative-with-false-safety-waiver, negation scope, mixed
  execution, owner-bypass attempts, approval-wording bypass.

### Docs

- READMEs (AiPlus and AEL) document G1 / G2 / Perf-1 as team capabilities.
- G2 spec promoted from DRAFT to APPROVED.
- New `docs/proposals/perf-1-dispatch-acceleration.md`.
- New `docs/team-protocols/dispatch-batching.md`.
- `docs/proposals/g1-t2-ai-integration-contract.md` (identity-context API
  contract).

### Internal

- Re-vendored `aiplus-public/assets/aieconlab/` from current AEL main.
- Worktree pool implementation at
  `crates/aiplus-cli/src/agent/worktree_pool.rs`.
- `is_supported_manifest_schema` extended to accept 0.6.x prefix (anticipated
  in source comment from prior 0.5.x stabilization work).

### Migration notes

- No breaking CLI changes.
- AEL users running `aiplus add aieconlab` automatically pick up DoF + R&R
  experts on next install.
- Existing dispatch-gate behavior is tightened: some prompts that
  previously slipped through will now require explicit Owner approval. This
  is the intended safety improvement.

## 0.5.26

### AEL Tier 1 Bundle A — runtime reconciliation (#16, #17, #18)

- `aiplus add <module>` now re-materializes bundled module files and
  reconciles module runtime adapters even when the module is already
  installed. Re-running `aiplus add aieconlab` repairs missing AEL
  Claude/OpenCode adapter artifacts without duplicating managed blocks.
- `aiplus install <runtime>` now reconciles already-installed modules
  into the newly installed runtime. The Codex-first AEL flow followed
  by `aiplus install claude-code` now leaves AEL Claude agents,
  commands, and managed blocks present with `aiplus doctor` passing.
- Added `aiplus doctor --fix` for the supported initial repair class:
  installed module runtime adapters and managed blocks. It reports the
  reconciled modules/runtimes, changed item count, and any remaining
  unsupported diagnostics.

### AEL Tier 1 Bundle B — runtime selection + role aliases (#19, #20)

- `aiplus agent talk --runtime <codex|claude-code|opencode>` now
  explicitly selects the runtime, rejects unsupported runtime IDs, and
  prints runtime/role audit context before opening the session.
- AiEconLab route/talk role aliases now resolve to canonical roles:
  `ceo`/`CEO`/`主作者`/`主笔`/`负责人` -> `pi`, `顾问`/`导师` ->
  `advisor`, `回归`/`主表` -> `ra-stata`, and `计量`/`识别` ->
  `econometrician`. Dispatch logs keep the canonical role plus the
  original alias as `roleInput`; transcripts render that source context.

### Cross-project velocity sharing (v2) (#71)

A new global ledger at `~/.config/aiplus/velocity/` (mode `0700`,
files `0600`) collects the structural projection of every project's
velocity records. Brand-new projects calibrate AI-native time
estimates from your cross-project history immediately instead of
starting at `MATCHED_RECORDS=0 CONFIDENCE=low`. Default per-project
mode is `read_write`; switch to `read_only` (learn but don't share —
for IRB-restricted or client work) or `none` (full isolation) via
`share_to_global_mode` in `.aiplus/velocity/config.json`. New
commands: `aiplus velocity import-from-project <path>` for one-shot
migration of an existing project's records; `aiplus velocity report
--scope local|global|both` (default `both`). The global ledger is
**structurally incapable** of holding free-text task descriptions,
file paths, project names, runtime, or machine identifiers — only
structured labels (`task_type`, `model`, `workflow`), durations,
outcomes, IDs, timestamps. New doctor fields:
`local_records_count`, `global_records_count`,
`synced_records_count`, `local_only_records_count`,
`share_to_global_mode`, `global_ledger_health` (PASS/NEEDS_FIX/FAIL
— iCloud/Dropbox sync paths flagged NEEDS_FIX). New IDs are
ULID-shaped (forward-compat for future multi-machine sync); old
`est_{unix_ms}` IDs remain readable. velocity types never use
`serde(deny_unknown_fields)` so an older CLI reading a future
config doesn't panic.
/ **跨项目 velocity 共享（v2）**：新增全局 ledger
`~/.config/aiplus/velocity/`（目录 `0700`、文件 `0600`），汇总每个
项目的结构化 velocity 投影。新项目立即用你跨项目的历史校准 AI 速度，
不再从 `MATCHED_RECORDS=0` 起步。每个项目可独立选择
`read_write`（默认）/`read_only`（学不写，IRB 项目用）/`none`（完全
隔离）。新命令：`aiplus velocity import-from-project <path>`
一次性迁移，`aiplus velocity report --scope local|global|both`
默认 both。全局 ledger 在**结构上**就无法存任务文本、文件路径、
项目名、runtime 或机器标识——只有结构化标签。doctor 新增 6 个字段
描述全局 ledger 健康度。新 ID 是 ULID 形状（为未来多机同步留接口）；
老的 `est_{unix_ms}` 仍可读。velocity schema 永远不用
`deny_unknown_fields`，旧 CLI 读未来字段不会 panic。

## 0.5.25

### K9: agent-key follow-ups (#79, #80, #81)

- **#79 — `secret-broker set --export-as <NAME>`** (new spelling for
  the legacy `--env <NAME>` output-label flag). Users and agents
  reading `--help` commonly misread `--env` as "read value from env
  var NAME" — the new name says what it does. `--env` remains as a
  clap `visible_alias` for one release; deprecation is name-only,
  no behavior change. / `set --env` → 改名 `--export-as`；旧名兼容。
- **#80 — Cross-project share docs**: README + AGENTS.aiplus.md
  BROKER protocol now spell out the two layers explicitly. Layer 1
  (keychain, always on, machine-wide) vs Layer 2 (cd-auto-load,
  per-project opt-in via `aiplus install`). Resolves the
  recurring "why doesn't my new project auto-load keys" confusion.
  / README/AGENTS protocol 把 cross-project 共享的两层语义讲清楚：
  keychain 层始终生效，cd-auto-load 层要 install opt-in。
- **#81 — bash + fish shell-init parity tests**:
  `install_with_yes_appends_shell_init_to_bashrc` and
  `install_with_yes_prefers_bash_profile_when_it_exists` cover the
  bash branch (including `~/.bash_profile` precedence on macOS).
  `install_with_yes_appends_shell_init_to_fish_config` covers
  `$XDG_CONFIG_HOME/fish/config.fish` + parent-dir auto-create.
  Interactive PTY tests intentionally skipped (rationale documented
  in #81); coverage focuses on the deterministic --yes path.
  / 3 个新 parity 测试，覆盖 bash + fish 的 shell-init 写入路径。

### Public profile template renamed: `aiplus-work-with-you` → `AiPlus-Work-with-Me`

- Semantically clearer: each forked profile bundle is "AiPlus working
  with me" (the owner), not "with you" (ambiguous referent). GitHub
  auto-redirects old URLs, so existing fork commands still resolve.
- `canonical_user_profile_or_default()` fallback string updated to
  match. `aiplus-agent-memory` identity templates' `inherits` field
  also flipped (see its main branch).
- The v0.5.23 entry below intentionally retains the old name as
  historical truth — it was correct at release time. Use the new name
  going forward.
- / **公开 profile 模板更名**：`aiplus-work-with-you` → `AiPlus-Work-with-Me`
  (每个 fork 都是 "AiPlus 跟我一起工作"，更贴合 owner 视角)。GitHub
  保留 URL 重定向，旧 fork 命令仍可用。CLI fallback 字符串 +
  `aiplus-agent-memory` identity 模板 `inherits` 同步更新。下方 v0.5.23
  条目里的旧名是历史记录，不回改。

## 0.5.24

### K8 (#87): NEEDS_ELEVATED status for sandbox-blocked GUI prompts

- **`aiplus secret-broker need|set --auto-prompt` now distinguishes
  user-cancellation from agent-sandbox GUI-block.** Codex CLI's
  sandbox blocks osascript from reaching the WindowServer; prior to
  this fix, the broker collapsed that failure to
  `SECRET_NEED_STATUS=MISSING` — and the agent (correctly, for that
  signal) gave up. v0.5.24 emits `NEEDS_ELEVATED` (exit 76) with a
  hint naming the actual fix: re-run wrapped in `zsh -lc 'eval
  "\$(aiplus secret-broker need <alias> --auto-prompt)"'`, which the
  agent's runtime treats as a permission-elevation request.
- **AGENTS.aiplus.md BROKER_PROTOCOL section now documents
  `NEEDS_ELEVATED`** alongside the existing PASS / MISSING flows,
  so agents reading the protocol know to branch on exit 76 without
  trial-and-error.
- Detection looks for osascript stderr markers seen in real Codex
  E2E: `(-1708)` (JXA-under-sandbox), `WindowServer`,
  `TISFileInterrogator`, `Connection invalid`.
- Internal: `prompt_secret_via_gui` return type changed from
  `Result<String>` to `Result<PromptOutcome>` (Value / Cancelled /
  SandboxBlocked variants). Test override via `AIPLUS_TEST_OSASCRIPT`
  env var so we can mock all three branches without popping real
  dialogs.
  / **K8 (#87)**：sandbox 阻挡 GUI 弹窗的情况现在能被识别。之前 codex
  用户在 sandbox 里跑 `need --auto-prompt` 会被静默归类为
  `MISSING`，agent 误以为"没 key 可用"放弃。现在 broker 检测 osascript
  stderr 里的 sandbox marker，emit `SECRET_NEED_STATUS=NEEDS_ELEVATED`
  + exit 76，给 agent 一行明确的 wrapped-shell 重跑指令。AGENTS protocol
  也加了这个状态的说明。

## 0.5.23

### Profile-name-agnostic CLI (#86)

- **`aiplus refresh`, `aiplus status`, `aiplus user context` now
  discover the installed profile name dynamically** instead of
  hardcoding `aiplus-work-with-zhiwen`. Any profile fork — including
  the new public `aiplus-work-with-you` template — is recognized
  automatically on first use. No config required.
  / **CLI 完全 profile-name agnostic**：三个命令自动识别已安装的 profile
  名，不再写死 `aiplus-work-with-zhiwen`。装了公开模板
  `aiplus-work-with-you` 或自定义 fork 的用户，命令输出直接显示正确的
  profile 名。

- **`aiplus refresh` now inlines the Owner's USER.md preferences** so
  agents pick them up automatically at session start — no extra
  `aiplus user context` command needed.
  / **`aiplus refresh` 自动内嵌 USER.md 偏好**：agent 启动时刷新一次就
  拿到 Owner 的所有偏好，不需要再手动跑 `aiplus user context`。

- **`ProfileSync` and `SnapshotBuilder::write_profile_snapshot` are
  now profile-name-agnostic**, accepting the profile name as a
  parameter. / **底层 API profile-name agnostic**：`ProfileSync`、
  `write_profile_snapshot` 改为接受 profile 名参数，不再假设固定名称。

- **Identity templates** in `aiplus-agent-memory` updated: `inherits`
  field now references `aiplus-work-with-you` (the public template)
  instead of the private prototype name.
  / **identity 模板** `inherits` 字段改指公开模板 `aiplus-work-with-you`。

## 0.5.22

### K7 (#83): `aiplus install` refuses on PATH version skew

- **`aiplus install <runtime>` now refuses when `which aiplus` is older
  than the binary running the install.** Previously, a user with stale
  `aiplus` on PATH would get an AGENTS.aiplus.md whose BROKER protocol
  references `secret-broker need --auto-prompt` (v0.5.18+ subcommand);
  agents dutifully ran it and hit `error: unexpected argument '--auto-prompt' found`,
  silently falling back to asking the Owner — defeating the agent-key
  zero-touch promise. Now refused with `INSTALL_STATUS=NEEDS_UPGRADE`
  and a copy-pasteable fix line. Override with `--allow-version-skew`
  flag or `AIPLUS_SKIP_VERSION_CHECK=1` env (for advanced users who
  are about to overwrite the PATH binary anyway).
- **AGENTS.aiplus.md BROKER protocol now self-describes its minimum
  required `aiplus` version (≥ 0.5.18)** at the top of the section, so
  agents reading the file can refuse to call `need --auto-prompt`
  when their PATH binary is too old.
  / **K7 (#83) install 检测 PATH 版本 skew**：装在用户机器上的老 aiplus
  会让新写的 AGENTS protocol 静默失败。现在 install 检测到 PATH 上 aiplus
  比自己旧就拒绝写文件，给一行 cp/install.sh 修复命令。`--allow-version-skew`
  / `AIPLUS_SKIP_VERSION_CHECK=1` 可绕过。AGENTS protocol 段落本身
  也声明 "Required aiplus version on PATH: ≥ 0.5.18"。

## 0.5.21

### K5: `aiplus install` auto-wires the cd-auto-load hook

- **`aiplus install <runtime>` now offers to append the
  secret-broker shell hook to your rc** (default Y on interactive
  tty; auto-append with `--yes`). Closes the last manual step in the
  agent-key UX: after a fresh install + one keyring entry, every
  `cd` into a project with `.aiplus/keys.toml` injects the expected
  `*_API_KEY` env vars before your agent starts. Idempotent (skipped
  if the rc already contains `_aiplus_broker_hook`); honors
  `AIPLUS_SKIP_SHELL_INIT=1` for dotfile-managed setups; falls back
  to a printed hint on unknown shells or non-tty without `--yes`.
  Detects zsh/bash/fish from `$SHELL` and writes to `~/.zshrc`,
  `~/.bash_profile`/`~/.bashrc`, or `$XDG_CONFIG_HOME/fish/config.fish`
  respectively. Append-only — never rewrites or removes existing rc
  content.
  / **`aiplus install` 自动 wire shell-init**：装完会问一句"启用 cd 自动
  装载？[Y/n]"，同意就 append ~6 行到你的 rc。装一次 + 第一把 key 弹窗
  粘一次 = 永久无感。`AIPLUS_SKIP_SHELL_INIT=1` 跳过；幂等；只 append
  不重写。

## 0.5.20

- **`aiplus doctor` no longer reports NEEDS_FIX for stale-registry
  entries alone (#74).** The cross-project registry accumulates an
  entry for every project AiPlus has ever installed into; deleted
  project directories leave behind stale entries. Doctor now surfaces
  these as `INFO registry has N stale entries (run aiplus prune-
  projects --yes)` and keeps `DOCTOR_STATUS=PASS` when stale entries
  are the only finding. Genuine install-correctness failures still
  flip to NEEDS_FIX. New `CheckSeverity` enum + `push_info_check`
  helper formalize the distinction.
  / **doctor 不再因 stale-registry 误报 NEEDS_FIX (#74)**。已删除项目目录
  对应的 registry entry 现在归类为 INFO 而非 NEEDS_FIX，DOCTOR_STATUS
  保持 PASS。

## 0.5.19

The v0.5.18 tag was pushed before this sprint's Tracks A.1/A.2/B.1/
B.2/B.3/C.1/C.2/D.2 merged on top of the agent-key K1-K4 commit, so
the v0.5.18 DRAFT release would have shipped without them. Skipping
v0.5.18; v0.5.19 carries the K1-K4 agent-key UX work AND the full
Tracks A-D bundle below.

### agent-key UX complete (K1-K4)

- **K1** `aiplus secret-broker set --auto-prompt` pops a native OS
  password dialog (macOS `osascript` / Linux `zenity-kdialog` /
  Windows PowerShell) — paste once into the OS-native input box, no
  shell-history pollution.
- **K2** `aiplus secret-broker need <alias>...` agent-callable
  command — agents declare what keys they need; the broker handles
  the pop-up + scope.
- **K3** AGENTS.aiplus.md protocol section documents the broker
  flow for runtimes that read AGENTS.
- **K4** `cd` auto-load via shell hook — the broker injects scoped
  env-vars on directory change for fast iteration.

### This-sprint Tracks A/B/C/D

- **Uninstall hygiene (Track A.1)**: `aiplus uninstall --yes` now
  sweeps `.claude/agents/{aieconlab,agent-team,aiplus}-*.md`,
  `.claude/commands/{aiel,aiplus,at}-*.md`, and the matching
  `.opencode/{agents,commands,prompts}/aiplus*` mirrors. Empty
  parent dirs we created are pruned. User-authored files survive.
  / **卸载清理（A.1）**：`aiplus uninstall --yes` 现在清理三个 prefix 组
  的 `.claude/`、`.opencode/` 残留文件，并修剪空目录。用户自建文件不动。

- **Cross-team residue cleanup at install (Track A.2)**:
  `agent_team_init` / `aieconlab_init` now clear the OTHER team's
  exclusive files from `.aiplus/agents/` before writing their own.
  Snapshot mechanism captures clean per-team state; the bare-mirror
  orphans (architect.md, ceo.md, …) that A.1 documented as a known
  limit are now prevented at source.
  / **跨 team 残留清理（A.2）**：两个 init 在写自家文件前先清掉对家 exclusive
  文件。snapshot 现在只存自家干净状态。

- **AEL OpenCode adapter v0.3 (Track B.1)**: 20 prefixed subagents
  (`.opencode/agents/aieconlab-<role>.md`) + 4 slash commands
  (`.opencode/commands/aiel-*.md`). AEL module 0.2.0 → 0.3.0.
  / **AEL OpenCode 适配器 v0.3（B.1）**：20 个角色文件 + 4 个 slash 命令。

- **agent-team OpenCode adapter v0.2 (Track B.2)**: 14 prefixed
  subagents (`.opencode/agents/agent-team-<role>.md`) + 2 slash
  commands. agent-team module 0.2.0 → 0.3.0.
  / **agent-team OpenCode 适配器 v0.2（B.2）**：14 个角色文件 + 2 个 slash 命令。

- **Codex coexistence audit (Track B.3)**: regression tests lock the
  AGENTS.md / AGENTS.aiplus.md dual-team coexistence behavior so
  future changes to the section-append path can't silently break
  the codex view of either team.
  / **codex 共存审计（B.3）**：回归测试锁定 codex 视角下双 team 的可见性。

- **agent-team persona behavior suite (Track C.1)**: mirrors AEL's
  W8 suite — 8 personas × 3 cases (in_scope / boundary / stop_gate),
  Python runner using Anthropic API, dedicated workflow that skips
  on missing API key. 5 offline structural sanity tests run in
  regular CI without API credentials.
  / **agent-team persona 行为测试（C.1）**：8 角色 × 3 case 共 24 个测试。

- **Cross-runtime install matrix test (Track C.2)**: single
  end-to-end test that exercises `install all → add aieconlab →
  set-team → uninstall` across all 3 runtimes with assertions at
  every phase. Regression boundary for any change touching the
  three adapter install paths.
  / **跨 runtime 安装矩阵测试（C.2）**：4 阶段 e2e 测试覆盖 3 个 runtime 全流程。

## 0.5.17

- **agent-key OS keyring default**: agent-key now uses the OS keyring
  (macOS Keychain / Linux Secret Service / Windows Credential
  Manager) as the default backend — free, zero-config. Bitwarden
  remains an opt-in for users who prefer their existing vault.
- **Persona drift detection (P1.4, P1.6, N3)**: `aiplus doctor` now
  walks `.aiplus/agents/personas/` and compares each persona against
  same-named mirrors under `.claude/agents/` and `.opencode/agents/`.
  Name-mapping table handles the prefixed mirror filenames; trim +
  strip-frontmatter normalize the comparison so wrapped mirrors
  don't trigger false positives. New UPGRADE.md captures the
  human-facing remediation flow.
- **`is_supported_manifest_schema` accepts `0.5.*` pattern (P2.3)**:
  match-based extension replaced with a glob so future minor bumps
  don't require a per-release source edit. Coupled with the
  install.sh fallback invariant test, drift between Cargo.toml and
  supported-schema list is now impossible to merge silently.
- **Release notes from tag annotation (P2.1)**: `release.yml` now
  passes `--notes-from-tag` instead of `--generate-notes`, so the
  git tag's annotated message drives the GitHub Release body. Stops
  the "release notes are PR backlinks" antipattern.
- **Merge policy + branch protection docs (P2.4)**: CONTRIBUTING.md
  documents the squash-merge + delete-branch convention and the
  branch-protection rules that enforce CI-green-before-merge.

## 0.5.16

User-visible fixes for the agent-team + AiEconLab coexistence story that
landed in v0.5.14 / v0.5.15 but still had rough edges in real use.

- **Agent-team is now visible to Claude Code's auto-routing.** Before
  this release, `aiplus install claude-code` (or `aiplus add agent-team`
  on a Claude Code project) wrote `.claude/agents/<role>.md` files
  without YAML frontmatter, so Claude Code's auto-routing never saw the
  team — `architect`, `ceo`, `engineer-a`, `engineer-b`, `qa`, and
  `reviewer` were effectively invisible. Now ships 14 prefixed
  subagents (`agent-team-<role>.md`, 8 core + 6 functional experts)
  with proper frontmatter, plus `/at-status` and `/at-route` slash
  commands and an `AIPLUS-AGENT-TEAM` managed block in CLAUDE.md that
  coexists cleanly with the existing AEL block (#31).
  / **Agent-team 现在能被 Claude Code 自动路由识别。** 之前 14 个 SWE 角色
  没有 YAML frontmatter，Claude Code 看不到。现在每个角色文件有 `name` /
  `description`，并加上 `/at-status` 和 `/at-route` 两个 slash 命令、
  CLAUDE.md 受管块。

- **`aiplus agent status` filters by active team.** With both
  `agent-team` and `aieconlab` installed, the status command used to
  report a confused 37-role roster regardless of which team was active.
  Now `aieconlab` active shows only the 20-role AEL roster, and
  `agent-team` active shows only the SWE roster — matching every other
  command (`route`, `set-team`, `talk`) that already respected the
  active marker (#32).
  / **`aiplus agent status` 按 active team 过滤。** 之前两个模块都装时
  统一显示 37 个混合角色，现在按当前 active team 只显示对应 roster。

- **Research-paper tasks now reach the AEL consultant.** PI tasks like
  "draft scoping note", "data acquisition plan", "referee response",
  and "rebuttal letter" used to score LIGHT and silently skip the
  consultant team (LIGHT tier is consult-skip by design). Tier scoring
  now recognizes 15 research-paper compounds (scoping-note, data
  acquisition, referee, weak-instrument, paper-revision, treaty-port,
  main-spec, …) so genuinely heavy research moves engage the right
  consultant seats. Trivial work (typo fix, version bump) is unchanged
  (#33).
  / **研究类任务现在会触发 AEL consultant。** 之前 "draft scoping note"
  / "data acquisition plan" / "referee response" 都被打成 LIGHT，绕过了
  consultant team。现在 tier scoring 增加了 15 个研究类关键词组合。

- **`aiplus compact prepare` is quiet on fresh installs.** A
  just-installed project has no Owner gate decisions yet, but the seed
  compact templates ship UNKNOWN_PENDING placeholders that historically
  made `compact prepare` (and the PreCompact hook) report
  UNKNOWN_NEEDS_REVIEW on every host compact attempt. Now distinguishes
  the seed-only state and returns the informational
  `FRESH_INSTALL_AWAITING_FIRST_USE` with exit 0; any custom edit to
  the handoff or Owner Gates section moves the project back into the
  normal review loop (#34).
  / **`aiplus compact prepare` 在 fresh install 上不再吵闹。** 之前每次
  host compact 都会因 seed Owner gate 报 UNKNOWN_NEEDS_REVIEW。现在能
  分辨 "seed 状态" 与 "真正需要 review"。

- **`install.sh` offline fallback bumped to current Latest.** The
  hard-coded `VERSION=v0.5.11` fallback (used only when both `gh api`
  and `curl` for the latest release fail) was four releases stale.
  Bumped to v0.5.16, and a new integration test asserts the fallback
  tracks `aiplus-cli` Cargo.toml — future Cargo.toml bumps now require
  the install.sh bump in the same commit, preventing this drift class
  (#35).

- **Fixed RED main from v0.5.15.** Two pre-existing test failures had
  been blocking PR CI test jobs since v0.5.15: (1) the
  `is_supported_manifest_schema` match list stopped at `"0.5.14"`, so
  every fresh v0.5.15 install reported `NEEDS_FIX manifest schemaVersion
  supported` and the integration test suite was red; (2) the
  `agent_route_blocks_dispatch_on_unapproved_owner_gate` parity test
  asserted no dispatch-log entry on refusal, but P1.3 (dispatch
  outcome) changed the behavior to always log with
  `outcome="canceled"`. Both fixed (PRs #37, #46).

## 0.5.1

- Wired Agent Continuity into `aiplus refresh`, `aiplus status`, and
  `aiplus doctor` so memory, identity, Skill Candidate, profile, secret safety,
  and global config state are visible from the normal refresh path.
- Added `aiplus memory list`, `aiplus memory recent`, safer forget output, and a
  more compact `aiplus memory context` packet for runtime agents.
- Improved identity and Skill Candidate UX with `identity list`, summarized
  advisor/CEO context, explicit permission-free identity output, and guidance
  that candidates are not approved skills.
- Updated Codex, Claude Code, and OpenCode project-local guidance for natural
  phrases such as `记住这个`, `忘掉这个`, `新开顾问`, `新开 CEO`, and
  `把这次经验沉淀成 skill`.

## 0.5.0

- Added the public `aiplus-agent-memory` Agent Continuity foundation for local
  Memory Context, Role Identity, and Skill Candidate governance.
- Added `aiplus memory`, `aiplus identity`, and `aiplus skill-candidate`
  foundation commands with project-local stores under `.aiplus/`.
- Added schemas, templates, adapters, synthetic examples, fake-HOME tests,
  project isolation tests, redaction guards, and public/private asset checks.

## 0.4.8

- Rejected empty, whitespace-only, and `PENDING_OWNER_INPUT_DO_NOT_USE`
  Bitwarden secret values as not configured.
- Preserved metadata-only output while returning
  `reason=secret_placeholder_or_empty` for placeholder or empty requested
  aliases.
- Kept unrequested placeholder aliases from blocking best-effort
  `secret-broker run -- <command...>` and selective runs for valid aliases.

## 0.4.7

- Added selective `secret-broker run` injection with `--aliases a,b` and
  repeated `--alias a`, so requested provider keys can be injected without
  unrelated placeholder providers blocking the command.
- Changed bare `secret-broker run -- <command...>` to best-effort compatibility
  behavior: inject aliases that resolve, report skipped aliases as metadata, and
  avoid printing secret values.
- Added first-class Kimi metadata that treats `kimi` as Kimi Code membership
  (`https://api.kimi.com/coding/v1`, model `kimi-for-coding`) while documenting
  Kimi Open Platform / Moonshot as a separate key system.

## 0.4.6

- Fixed real Bitwarden `secret-broker resolve` by resolving an alias key/name to
  a Bitwarden secret ID in memory before calling `bws secret get`.
- Added safe resolver metadata output (`secret_key`, `secret_id_found`) without
  printing secret IDs or secret values.
- Kept secret values out of logs, docs, tests, and default command output while
  preserving `secret-broker run -- <command...>` as the explicit env-injection
  path.

## 0.4.5

- Added `aiplus profile migrate` and `aiplus profile cleanup` so legacy
  `work-with-zhiwen` user-level profile registrations can be backed up and
  removed after the canonical `aiplus-work-with-zhiwen` profile is installed.
- Updated `aiplus profile status` to report only active canonical profiles in
  `profiles=[...]` while listing legacy registrations separately with the cleanup
  next step.
- Clarified `aiplus secret-broker doctor` output when `bws` is installed but the
  Bitwarden token is not configured.

## 0.4.4

- Changed private profile installation to a generic source-based flow so public
  AiPlus no longer embeds private profile content or private Bitwarden alias
  namespaces.
- Moved private secret alias inventory to user-installed profile packages.
- Added `aiplus profile uninstall` for reversible user-level profile removal.

## 0.4.3

- Added private-profile installed alias support for `aiplus secret-broker`.
- Added test coverage that installed aliases appear in `aiplus secret-broker
  list`, resolve without printing secret values by default, and unknown aliases
  remain blocked.
- Clarified that real Bitwarden smoke checks require the Bitwarden Secrets
  Manager `bws` CLI plus a private read-only machine account token.
- Kept secret values out of normal `list`, `status`, and default `resolve`
  output. `run -- <command...>` remains the explicit runtime-only injection path.

## 0.4.2

- Added user-level private profile commands for collaboration preferences under
  `~/.config/aiplus/`.
- Added `aiplus secret-broker` with mock and Bitwarden `bws` provider paths,
  approved alias mapping, metadata-only status/list/resolve output, and
  child-process environment injection via `run -- <command...>`.
- Added explicit warnings that `secret-broker run` only keeps AiPlus from
  printing or persisting secrets; the invoked child command can still print, log,
  transmit, or store environment variables.
- Updated installed agent guidance for natural-language profile and secret
  status triggers while keeping secret values out of chat, logs, compact files,
  repos, and release artifacts.
- Preserved v0.3.1 compact savings and update semantics.

## 0.3.1

- Fixed Compact Savings all-time totals so projected `prepare` and candidate
  `checkpoint` events do not count as completed savings.
- Defined compact savings event semantics: `prepare=projected`,
  `checkpoint=candidate`, and successful `resume=completed`.
- Deduplicated completed compact cycles by `checkpointId`, so repeated resume
  does not double-count the same compact cycle.
- Added `aiplus self update` for checksum-verified user-level CLI updates with
  dry-run, backup, staged replacement, and smoke-check output.
- Added `aiplus update all` to update the CLI and current project guidance in
  one command when safe.
- Clarified pricing update/status output with `pricing_fetch_mode`,
  `pricing_source`, cache age, `billing_data=no`, and `uploads=none`.
- Added natural-language update guidance for "update AiPlus", "升级 AiPlus",
  "update the aiplus command", and project-only update requests.

## 0.3.0

- Added Compact Savings Estimate with project-local
  `.codex/compact/savings-ledger.jsonl` aggregate events.
- Added `aiplus compact savings` and `aiplus compact savings --json`.
- Added `aiplus pricing status` and `aiplus pricing update`; savings reports
  read cached pricing by default, while explicit pricing update fetches public
  pricing data.
- Added conservative local token savings, weighted reduction percentage, and
  estimated USD savings reporting. Reports are estimates only, not billing data.
- Added safe unknown-model behavior: token savings and reduction still report,
  while USD savings become unavailable or partial when pricing is missing.
- Documented that AiPlus does not upload prompts, project files, checkpoints,
  savings ledgers, secrets, billing data, or usage history.

## 0.2.1

- Fixed dogfood upgrade behavior for legacy compact handoffs by adding missing
  v0.2 role-aware sections during install/update while preserving existing
  handoff content and backing up the original file.
- Changed blocked compact checkpoint behavior so `BLOCKED_BY_OWNER_GATE` does
  not create a normal checkpoint JSON by default.
- Added public repo hygiene ignores for project-local dogfood install artifacts
  such as `.aiplus/`, `.codex/`, `.claude/`, `.opencode/`, and generated
  `AGENTS.md`.
- Added v0.2 Compact Readiness & Recovery:
  `aiplus compact prepare`, readiness states, `aiplus compact score`,
  `checkpoint --level light|standard|full`, and role-aware resume guidance.
- Made natural language the primary compact interface for ordinary users:
  "prepare compact", "save progress", "continue", "帮我准备 compact", "保存进度",
  and "继续" map to agent use of AiPlus backend commands.
- Documented that compact CLI commands are agent backend tools, advanced manual
  fallbacks, and maintainer debugging commands, not beginner memorization
  requirements.
- Removed active Node `compactctl.mjs` guidance from installed and
  ordinary-user compact paths.
- Made Rust-native `aiplus compact prepare`, `score`, `checkpoint`, `validate`,
  and `resume` the only supported compact execution commands.
- Added missing-`aiplus` guidance: install AiPlus or fix PATH instead of falling
  back to Node.
- Updated bundled Auto Compact docs so legacy Node references are archived
  history or compatibility-test fixtures only.

## 0.1.2

- Added explicit AiPlus refresh triggers for already-open sessions:
  `AiPlus 刷新`, `刷新 AiPlus`, `aiplus refresh`, `aiplus status`,
  `AiPlus status`, `继续 AiPlus`, and `resume AiPlus`.
- Added `aiplus refresh` as a concise helper command for agents and users.
- Strengthened installed `.aiplus/AGENTS.aiplus.md` guidance so AiPlus status is
  reported before unrelated project refresh when the user asks for AiPlus.
- Documented project-specific refresh conflict handling while preserving generic
  `刷新` / `refresh` as AiPlus-first after installation.

## 0.1.1

- Fixed existing-project `aiplus install codex` upgrades so old AiPlus managed
  files are backed up and refreshed without requiring ordinary users to know
  `--force --backup --yes`.
- Preserved existing `.codex/compact/` state during install/upgrade.
- Updated generated refresh guidance so `刷新` and `refresh` are treated as
  AiPlus refresh first, with a concise installed-status response.
- Refined Auto Compact checkpoint/resume and Auto Team Consultant activation
  guidance in generated project instructions and bundled module docs.
- Kept the v0.1.1 installer on the verified macOS Apple Silicon release asset
  path with checksum verification and user-level `~/.local/bin/aiplus` install.

## 0.1.0

- Published v0.1.0 as the first practical binary-installed AiPlus CLI release.
- Added `install.sh` for checksum-verified user-level install to
  `~/.local/bin/aiplus`.
- Documented best-effort automatic compact resume behavior and natural
  continuation phrases.
- Rewrote public README and README.zh-CN beginner flow to use copy-pasteable
  installer commands instead of source-build placeholders.
- Standardized human-facing product naming to `AiPlus` while keeping the
  command, binary, repo, and crate identifiers as `aiplus`/`aiplus-cli`.
- Added an Owner-approved v0.1.0 GitHub Release path with a verified macOS Apple
  Silicon binary, `checksums.txt`, and checksum-verifying install script.
- Added Rust-first `aiplus` CLI workspace.
- Added local vendored AiPlus module asset snapshot.
- Added project-local install/update/add/status/doctor/uninstall workflows.
- Added Codex, Claude Code, OpenCode, and all-runtimes adapter support.
- Added Rust parity and safety tests.
- Documented Node CLI as archived historical reference.
- Replaced compact bridge limitation with Rust-native compact status
  `COMPACT_RUST_NATIVE_STATUS=PASS`.

## Public-ready candidate docs

- Documented recommended public repo name `aiplus`.
- Documented public repo structure with Rust workspace as root.
- Added v0.1.0 distribution plan.
- Added binary artifact matrix with macOS Apple Silicon verified first and other
  platforms planned.
- Added migration guide from archived Node CLI.
- Added QA release-readiness checklist.
- Kept installed manifest schema `0.2.1` for compatibility.
- Applied Owner-approved Apache-2.0 licensing to the Rust mainline/public-ready
  package metadata and docs.
