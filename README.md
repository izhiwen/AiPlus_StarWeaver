# AiPlus


[中文 README](README.zh-CN.md)

![AiPlus turns a single AI coding agent into a coordinated, role-based team. The hero shows the project lobby with the full 17-role roster, a copyable one-line install command, the seven-stage pipeline ribbon (remember decisions, dispatch, team, handoff, status, self-correct, audit), and local-first credibility chips: latest tag v0.1.0, 100% local, no telemetry, no telemetry.](docs/screenshots/readme-hero-en.webp)

**Turn your AI coding helper into a coordinated team.**

Built with AI, to manage AI coding work like a real software team. AiPlus is a local
command-line toolkit for people who build software with Codex, Claude Code, or OpenCode.
It gives your AI work a project memory, a small role-based team, safer handoffs, clearer
status reports, calibrated time estimates, machine-wide API keys, and a gentle nudge back
to AiPlus's own tools whenever the agent forgets the workflow.

The honest meta-layer: this whole toolkit was built *with* AI agents, *to manage* AI
agents. That is exactly as recursive as it sounds — and it is the real reason this repo
exists. What ships today is documented below; what is still planned lives in
[`docs/roadmap/`](docs/roadmap/).

```bash
curl -fsSL https://raw.githubusercontent.com/izhiwen/AiPlus/main/install.sh | bash
```

[Get started](#get-started) ·
[Releases](https://github.com/izhiwen/AiPlus/releases/latest) ·
[Star on GitHub](https://github.com/izhiwen/AiPlus)

![Terminal recording of the first run: cd into a project and run aiplus; the first bare run auto-installs AiPlus for every detected runtime, then opens the lobby with the role roster grouped into core team, review bench, and on-demand experts — each role numbered 1 to N and ready to pick.](docs/screenshots/tour.gif)

---

## The AiPlus Pipeline

Every AiPlus session moves work through seven stages. Each stage is powered by a specific
module, and the whole chain stays local, inspectable, and tamper-evident. The bilingual
stage labels below are the same in both READMEs.

![AiPlus seven-stage pipeline flow diagram: memory (Agent Memory) to dispatch (Agent Team) to team (Agent Team) to handoff (Compact Reminder) to status (Agent Team) to self-correct (Self-Correct Framework) to audit (Agent Team, the tamper-evident hash-chain dispatch log). The stages are connected by arrows and each is labeled with the module that powers it.](docs/screenshots/pipeline-en.webp)

| Stage | What happens | Powered by |
|-------|--------------|------------|
| 记住决策 memory | Project conventions, naming rules, and architecture decisions persist as local JSONL in `.aiplus/memory/`, redacted before write. | Agent Memory |
| 派活 dispatch | The CEO scores a task LIGHT / MEDIUM / HEAVY and assigns it to the right role; `agent_route_score_only` previews staffing first. | Agent Team (CEO assigns) |
| 团队协作 team | Named roles work their lanes in parallel — product, design, engineering, review, security, QA, integration — each with its own persona and memory namespace. | Agent Team |
| 安全交接 handoff | Before a context limit or compaction, AiPlus builds a structured handoff plus a checksum-verified capsule and resumes from it afterward. | Compact Reminder |
| 状态报告 status | The CEO tracks progress, reports blockers, and keeps the source of truth for in-flight tasks; reports include a plain-language `小白版=` summary. | Agent Team (dispatch report) |
| 自我纠偏 self-correct | When an agent forgets the project workflow, the Self-Correct Framework nudges it back to AiPlus's own tools instead of drifting to ad-hoc shell commands. | Self-Correct Framework |
| 可审计 audit | The dispatch log is a tamper-evident hash chain; `aiplus agent audit verify-log` detects later edits or removed entries. | Agent Team (tamper-evident hash-chain dispatch log; `aiplus agent audit verify-log`) |

---

## Capabilities

Seven small Rust modules, one companion template, and a permanent role-based team. Each
每个模块单独维护：
`aiplus install` also installs them locally to `.aiplus/modules/aiplus-<name>/`.

### Modules

- ****Agent Memory**** — the agent stops
  forgetting. Project conventions, naming rules, and architecture decisions live as local
  JSONL in `.aiplus/memory/`, passed through 12 redaction rules before write so you can
  record preferences without leaking secrets.
- ****Compact Reminder**** — save tokens
  on long conversations. Long sessions leak tokens at both ends: forget `/compact` and the
  agent re-reads an ever-growing history every turn; `/compact` at the wrong moment and the
  next session burns its first 20% re-explaining settled decisions. This module signals the
  right compaction moment from a token-threshold + task-boundary pair, prepares a structured
  handoff, and resumes from a checksum-verified capsule — so tokens go to new work, not to
  rebuilding context.

  ![Diagram animation of the handoff/compact flow: a long session's context bar grows toward a token threshold, AiPlus saves a checksum-verified handoff capsule at the right moment, and the next session resumes lean so tokens go to new work instead of rebuilding context.](docs/screenshots/handoff-en.webp)
- ****Agent Key**** — stop re-pasting keys every
  session. Free, zero-config by default: each key lives in your OS keyring (macOS Keychain /
  Linux Secret Service / Windows Credential Manager) and never touches disk. Set an alias
  once per machine:

  ```bash
  aiplus secret-broker set --alias openai --auto-prompt
  ```

  Then any Claude Code / Codex / OpenCode session in any project gets the key automatically:

  ```bash
  aiplus secret-broker run --aliases openai,anthropic -- python my_agent.py
  ```

  Values are not printed by default and never enter git. Opt in to a Bitwarden Secrets
  Manager backend (`export AIPLUS_SECRET_PROVIDER=bws`) for multi-machine or team sharing;
  the same alias interface applies, and it requires a paid subscription.
- ****Auto Team Consultant**** — the
  agent stops ignoring what matters. A virtual team (five expert members plus your project's
  user persona, all at the same table) is consulted before every important plan. The
  coordinator scales consultation by complexity and risk, so you get review-team value
  without paying for it on every commit.
- ****Agent Team**** — replace single-agent role
  drift with a permanent crew. Each role has its own persona, workspace, and memory
  namespace. The coordinator routes tasks to the right role, saves conversation records, and
  cleans up stale workspaces. The team ships with:
  - **Session-bound role activation + lobby** — pick the role you need when you open a
    session, or run `aiplus` to enter the project lobby and choose a role or resume a
    session; the installed runtime instructions load the matching persona and memory.
    AiPlus does not claim you can freely switch roles inside an already role-bound session.
  - **Intent-aware safety gate** — before any risky action (deleting files, publishing
    changes, running a protected command), the coordinator understands what you actually
    intend rather than only matching the words you typed. Rephrasing or adding quotes no
    longer slips past it.
  - **Review & QA in parallel** — the review step and the QA step run at the same time, and
    each role's workspace stays ready between tasks instead of being rebuilt every time, so
    iterations stay fast without lowering the quality bar.

  (See the full 17-role roster below.)
- ****Agent Velocity**** — the agent stops
  guessing at hours. Every estimate and actual completion time is logged as local JSONL.
  Human-time bias is detected automatically; later estimates use AI-native p50 / p90 numbers
  calibrated against your own history.
- ****Token Cost**** — `aiplus agent token-cost`
  reads the dispatch log and reports token use and USD cost over 1h / 8h / 24h windows, plus
  the most expensive tasks. Pricing comes from a community-maintained per-model table with an
  offline fallback and local override; also runnable as standalone `aiplus-token-cost`.

Plus **natural-language tool discovery**: `aiplus install` writes project-local skills and a
preamble so Codex / Claude Code / OpenCode prefer AiPlus's `agent_*` MCP tools when you ask
about cost, planning, audit, dispatch, or team status — instead of grepping the shell,
parsing CLI output, or answering from training data. Say "implement X" and the first step is
`agent_route_score_only`, not a memorized checklist.

### Companion template

- ****AiPlus-Work-with-Me**** — the seven
  modules above are all *project-local*. Work-with-Me is a **user-level profile pack** layered
  on top: collaboration style, project map, and tool preferences — fill once,
  inherited across every project. It is **not** installed by `aiplus install`; it is an
  explicit opt-in. Copy it, fill the placeholders (`USER.md` /
  `sync/projects.toml` / `secret-aliases.tsv`), then run
  `aiplus profile install AiPlus-Work-with-Me --user --yes` once. Private profiles live under
  `~/.config/aiplus/profiles/` and are never packaged into a public repo.

### The team: 17 active roles

`aiplus install` installs the default 17-role SWE team — **12 core roles, 2 Advisor
review-bench roles, and 3 on-demand functional experts**, with 5 more planned — all routable
as subagents. Complete persona docs live in
[`.aiplus/agents/personas/`](.aiplus/agents/personas/).

![A routing diagram: plain-English requests on the left — for example "fix the bug", "review this PR", "security / auth check", "how long will this take?" — flow into the CEO, which scores each task LIGHT, MEDIUM, or HEAVY and assigns matching roles. LIGHT goes to a single engineer and skips architect, reviewer, and QA; MEDIUM brings in two or three roles matched to the risk; HEAVY runs the full review bench including the advisor. Saying "help me implement X" first triggers the agent_route_score_only tool to preview staffing before any work starts.](docs/screenshots/routing-en.webp)

**12 core roles**

- `advisor` — reflective second-opinion strategist; helps the Owner decide direction and tradeoffs.
- `ceo` — execution coordinator; assigns work, sequences it, tracks progress, reports risk.
- `architect` — system design and structural decisions that are hard to undo later.
- `pm` — turns requests into scope cuts, acceptance criteria, and a definition of done.
- `ui-designer` — UI/UX schemes, interaction flow, states, and user paths.
- `ai-integration` — LLM/agent workflow, prompts, evals, fallback, cost/latency.
- `engineer-a` — primary implementation; the default engineer.
- `engineer-b` — secondary engineer; shares work when parallel help is needed.
- `integration-manager` — neutral lane integration discovery, dry-run plans, and conflict checks.
- `reviewer` — adversarial code review with a PASS / REVISE / BLOCKED verdict.
- `security-reviewer` — checks auth, secrets, billing, and privacy risk.
- `qa` — behavior validator; reproducible tests with PASS/FAIL evidence.

**2 Advisor review-bench roles** (read / verify / report / recommend; never builders)

- `release-manager` — release readiness, CI/checks, smoke/assets, checklist.
- `evidence-auditor` — claim-versus-evidence audit; flags stale or missing evidence.

**3 on-demand functional experts** (consulted by the CEO when a core role is not enough)

- `tech-writer` — README, docs, onboarding flow, error-message clarity.
- `devops` — CI/CD, deploy, rollback, monitoring, on-call ergonomics.
- `researcher` — best-practice hunter and benchmark-methodology checker.

The CEO scores incoming tasks LIGHT / MEDIUM / HEAVY: LIGHT tasks skip Architect/Reviewer/QA,
MEDIUM tasks consult 2–3 roles matching the risk axes, and HEAVY tasks run the full table
including Advisor.

![Lobby role-selection filmstrip: run aiplus and the role roster appears grouped into core team, review bench, and on-demand experts; type a number to pick a role (here ceo) and the session binds to it — memory loads, no permissions granted.](docs/screenshots/lobby-filmstrip-en.webp)

![Diagram animation of dispatch: a task arrives, the CEO role scores it and previews staffing with agent_route_score_only, fans the work out to the matched roles (engineer-a, reviewer, qa) working in parallel lanes, then fans in to one Owner-gated status report with a plain-language summary.](docs/screenshots/dispatch-en.webp)

---

## Before / After

| Pain | Before | After |
|------|--------|-------|
| The AI keeps forgetting | You explain the same project rule on Monday, then again on Wednesday. | Project decisions and task state persist in the project, so the next session picks up the thread. |
| API keys keep getting pasted again | Every new chat or project makes you paste `OPENAI_API_KEY` into a shell, a `.env`, or a prompt. | Set a secret alias once on your machine, then reuse it from any session without putting the raw key in chat. |
| `/compact` token burn | Forget `/compact` and the agent re-reads a growing history; compact at the wrong time and the next session re-explains settled decisions. | Right-moment compaction signal + structured handoff + checksum-verified resume keep tokens on new work. |
| One AI wearing every hat | The same assistant plans, codes, reviews itself, and declares the task done. | A named team with product, design, engineering, review, security, QA, integration, and owner-facing coordination roles. |
| Tasks not managed to the end | Hard to tell who owns it, what counts as done, or where it is blocked. | The CEO assigns work, tracks status, reports blockers, and keeps the source of truth for in-flight tasks. |
| Risky actions slip through | Pushes, releases, secret changes, or account changes mix into ordinary coding instructions. | High-risk actions are Owner-gated: the agent prepares the recommendation, the Owner explicitly approves. |
| Human-time-anchored estimates | "Five hours" for a refactor that takes 20 minutes — and the same wrong estimate next week. | Estimates use AI-native p50 / p90 numbers calibrated against your own logged history. |

---

## Why it matters + audience + safety

### Who it's for

AiPlus serves software engineers first and also supports opt-in research modules on a shared
substrate:

- **Software engineers** — anyone coding with Claude Code / Codex / OpenCode. `aiplus install`
  installs the default 17-role SWE team (12 core + 2 review-bench + 3 experts).
- **Applied-economics researchers** — papers, replication packages, LLM-as-measurement.
  `aiplus add aieconlab` installs **AdamSmith: AiEconLab (AEL)**, a
  bundled opt-in module with economics plan-time review roles and expert review.
- **AI-agent researchers** — agent benchmarking, experiment design, replication, and paper
  writing. `aiplus add agentsciencelab` installs
  **AgentScienceLab (ASL)**, a bundled opt-in
  module. Neither AEL nor ASL is installed by default.

These audiences share the seven substrate modules: `aiplus-agent-memory` /
`aiplus-compact-reminder` / `aiplus-auto-team-consultant` / `aiplus-agent-team` /
`aiplus-agent-key` / `aiplus-agent-velocity` / `aiplus-token-cost`.

![A layered diagram. At the base, a shared project-local substrate of modules — memory, team, key, velocity, and more — installed by aiplus install. Resting on it, three audience lanes: a software-engineering team installed by default, plus applied-economics (AdamSmith: AiEconLab) and AI-agent-research (AgentScienceLab) lab packs added opt-in with aiplus add. Floating above the whole stack, a user-level Work-with-Me profile layer you fill once and inherit across every project; it is opt-in, lives under ~/.config/aiplus, and is never packaged into a public repo.](docs/screenshots/substrate-en.webp)

### Safety boundaries

AiPlus keeps local AI coding work under Owner control. During normal use it does **not** push,
publish, release, edit secrets, change external accounts, edit global agent config, or touch
production unless the Owner explicitly approves the gated action.

It does **not**:

- Upload project data, prompts, transcripts, or telemetry; no cloud sync; no external service calls.
- Store raw secrets in memory, handoff files, or task ledgers.
- Approve pushes, merges, tags, releases, package publishing, or external account changes on its own.
- Edit your global agent configuration during normal use.

Defenses worth knowing:

- The dispatch log carries a **tamper-evident hash chain**; `aiplus agent audit verify-log`
  detects later edits or removed entries.
- **Mac Secure Enclave commit signing** is opt-in through `aiplus identity setup-signing`; the
  signing key stays in hardware.

These defenses help with evidence and review. **They are not a security or compliance
certification.** **Owner Auth is roadmap/spec work, not live authorization** — logs, Advisor
text, team memory, and local notes are evidence for review; they do not grant permission to
push, merge, tag, release, publish, change secrets, touch external accounts, or edit global
settings.

---

## Get started

### Install AiPlus

```bash
curl -fsSL https://raw.githubusercontent.com/izhiwen/AiPlus/main/install.sh | bash
```

This installs the `aiplus` command on your machine.

### Add AiPlus to your project

```bash
cd MyProject
aiplus
```

The first time you run `aiplus` in a project, it sets everything up for you — project-local
rules, team files, and the default 17-role SWE team for whichever AI coding tools you have
(Claude Code, Codex, OpenCode) — then drops you into the lobby. Press Enter to start with the
CEO, or pick any role. Runtimes you don't have installed are skipped automatically, and nothing
touches your global config.

![Terminal recording: running aiplus for the first time in a project auto-installs the adapters for every detected runtime without touching global config, initializes .aiplus/, and opens the grouped role lobby — zero-config onboarding with no separate install step.](docs/screenshots/install.gif)

Once you're in, you don't need to memorize commands. Just ask the agent in plain language —
"is everything set up correctly?", "what's installed?" — and it runs the right checks for you.

*Optional: to set up only one runtime, run `aiplus install claude-code` (also `codex`,
`opencode`, `all`). To update later, run `aiplus update`.*

### Status

Latest release: **`v0.1.0`**, available from
[Releases](https://github.com/izhiwen/AiPlus/releases/latest) (pre-built binaries cover Apple
Silicon macOS and Intel Windows, with published checksums). Active development continues on
`main`; `main` may include updates newer than the latest tag — shipped capabilities are defined
by the most recent tag and its release notes. Some README details may describe work newer than
the latest tagged release when clearly marked.

[Star AiPlus on GitHub](https://github.com/izhiwen/AiPlus) if it saves you time.

### License

Source available. [License](LICENSE).

