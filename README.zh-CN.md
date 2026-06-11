# AiPlus


[English README](README.md)

![AiPlus：把单个 AI coding agent 升级成一支协同团队。图中是项目 lobby 的真实 17 角色名册（12 核心角色 + 2 评审席 + 3 专家），下方是一行可复制的安装命令，以及贯穿七个阶段的工作流条带：记住决策 → 派活 → 团队协作 → 安全交接 → 状态报告 → 自我纠偏 → 可审计。底部是凭据徽章：最新 tag v0.7.23、100% 本地、无遥测。](docs/screenshots/readme-hero-zh.webp)

**把单个 AI coding helper，升级成一支协同团队。**

用 AI 构建，用来像真正的软件团队那样管理 AI 写的代码。AiPlus 是一套本地命令行工具，面向用 Codex、Claude Code 或 OpenCode 写软件的人。它给你的 AI 工作配上项目记忆、一支基于角色的小团队、更安全的交接、更清晰的状态报告、校准过的工时估计、机器级 API key，并在 agent 忘记调用 AiPlus 自己的工具时温和地把它纠回来。

我用 AI coding agent 全职写代码已经有大半年 —— 平时主要 Claude Code，偶尔 Codex 拿第二意见，长任务上 OpenCode。大约四个月之后，我发现自己在同一周里把同一个架构决策对同一个 agent 解释了第四遍 —— 顺带把同一把 API key 也对同一个 agent 重新粘贴了第四遍。AiPlus 就是我为治这几件每天烧时间的事写的七个小 Rust 模块（Agent Team 一个模块同时治两件）。坦白讲这件事的元层：**我用 AI agent 构建了管理 AI agent 的工具链** —— 这句话听起来有多套娃就有多套娃，但这是这个 repo 存在的真实理由。今天能跑的就在这儿；还没做的事在 [`docs/roadmap/`](docs/roadmap/)。

```bash
curl -fsSL https://raw.githubusercontent.com/izhiwen/AiPlus_StarWeaver/main/install.sh | bash
```

[开始使用](#get-started) ·
[Releases](https://github.com/izhiwen/AiPlus_StarWeaver/releases/latest) ·
[在 GitHub 上 Star](https://github.com/izhiwen/AiPlus_StarWeaver)

![首次运行的终端录屏：进入项目目录直接运行 aiplus，首次裸跑会自动为每个检测到的运行时安装适配器，然后打开 lobby——角色名册按 core team / review bench / on-demand experts 分组，每个角色都有编号、可直接选。](docs/screenshots/tour.gif)

---

## The AiPlus Pipeline

每一个 AiPlus session 都把工作推过七个阶段。每个阶段都由某个具体模块驱动，整条链路全程本地、可查、防篡改。下面的双语阶段标签在两份 README 中完全一致。

![AiPlus 七阶段流水线流程图：记住决策（Agent Memory）→ 派活（Agent Team）→ 团队协作（Agent Team）→ 安全交接（Compact Reminder）→ 状态报告（Agent Team）→ 自我纠偏（Self-Correct Framework）→ 可审计（Agent Team，防篡改哈希链 dispatch log）。各阶段以箭头相连，每个阶段都标注了驱动它的模块。](docs/screenshots/pipeline-zh.webp)

| 阶段 | 做什么 | 由谁驱动 |
|------|--------|----------|
| 记住决策 memory | 把项目约定、命名规则、架构决定存成 `.aiplus/memory/` 里的本地 JSONL，写入前先脱敏 | Agent Memory |
| 派活 dispatch | CEO 给任务定级 LIGHT / MEDIUM / HEAVY 并派给正确的角色；`agent_route_score_only` 先预览 staffing | Agent Team（CEO 派活） |
| 团队协作 team | 有名角色并行各司其职 —— 产品、设计、工程、评审、安全、QA、整合 —— 每个角色都有独立人设和内存命名空间 | Agent Team |
| 安全交接 handoff | 在撞上下文上限或 compaction 之前，AiPlus 准备结构化交接和一个 checksum 校验过的 capsule，之后据此自动续接 | Compact Reminder |
| 状态报告 status | CEO 跟踪进度、汇报 blocker、保留在途任务的事实来源；报告含一行 `小白版=` 通俗摘要 | Agent Team（派单报告） |
| 自我纠偏 self-correct | agent 忘了走项目工作流时，Self-Correct Framework 把它温和地纠回 AiPlus 自己的工具，而不是漂去临时 shell 命令 | Self-Correct Framework |
| 可审计 audit | dispatch log 是一条防篡改哈希链；`aiplus agent audit verify-log` 能检出事后改动或被删条目 | Agent Team（防篡改哈希链 dispatch log；`aiplus agent audit verify-log`） |

---

## Capabilities

七个项目本地的小 Rust 模块，加一个 companion 模板，再加一支常驻角色团队。每个模块单独维护； `aiplus install` 会自动把它们装到 `.aiplus/modules/aiplus-<name>/`。

### 模块

- ****Agent Memory**** —— Agent 不再失忆。项目约定、命名规则、架构决定，作为本地 JSONL 存在 `.aiplus/memory/`。写入前会过 12 条 redaction 规则剥敏感串，所以你可以放心记偏好，不用担心泄漏。
- ****Compact Reminder**** —— **长对话省 token**。长 Claude Code / Codex / OpenCode session 会两头漏 token：忘了 `/compact`、agent 每轮都得重读越来越大的历史；`/compact` 时机不对又会丢任务状态、下一个 session 头 20% 全花在重新解释已经决定过的事上。本模块在 token 阈值 + 任务切点双信号下提示恰当的 compact 时机，自动准备结构化交接，并用 checksum 校验过的 capsule 自动续上 —— **让 token 花在新工作上，而不是重建上下文**。

  ![安全交接 / compact 流程的图解动画：长会话的上下文条逐渐填满逼近 token 阈值，AiPlus 在恰当时机保存一个 checksum 校验过的交接 capsule，下一个 session 精简续接，让 token 花在新工作上而不是重建上下文。](docs/screenshots/handoff-zh.webp)
- ****Agent Key**** —— **不再每个 session 重配 key**。**免费、零配置默认**：每个 key 直接存在你机器的 OS keyring 里（macOS Keychain / Linux Secret Service / Windows Credential Manager），从不落盘。每台机器一次性：

  ```bash
  aiplus secret-broker set --alias openai --auto-prompt
  ```

  之后任何项目的任何 Claude Code / Codex / OpenCode session 都自动拿到 key：

  ```bash
  aiplus secret-broker run --aliases openai,anthropic -- python my_agent.py
  ```

  值默认不打印、绝不进 git。需要多机同步或团队共享 → opt-in 切到 Bitwarden Secrets Manager 后端（`export AIPLUS_SECRET_PROVIDER=bws`），同样 alias 接口，需要付费订阅。
- ****Auto Team Consultant**** —— Agent 不再忽略关键事项。**一个虚拟团队**（5 位专家成员 + 你项目的用户 persona，**坐同一桌**）会在每次重要 plan 之前被咨询。Coordinator 按复杂度和风险决定咨询规模，让你拿到真实评审团队的价值，但不在每次提交都付成本。
- ****Agent Team**** —— 用常驻团队取代单 Agent 的**角色漂移**。每个角色都有独立人设、工作区和内存命名空间。Coordinator 把任务路由给正确角色，保存对话记录，清理过时工作区。团队自带：
  - **Session 绑定的角色激活和 lobby 选角色** —— 开新 session 时选好需要的角色，也可以直接运行 `aiplus` 进入项目 lobby 选择角色或续接 session；已安装的 runtime instructions 会加载对应 persona 和内存。AiPlus 不声明可以在一个已经绑定角色的 session 里自由切换角色。
  - **理解意图的安全门** —— 做任何危险操作之前（删文件、发布改动、跑受保护的命令），Coordinator 会先理解你到底想做什么，而不只是匹配你打的字眼。改个说法、加引号已经骗不过它了。
  - **评审和 QA 并行** —— review 步骤和 QA 步骤同时跑，每个角色的工作区在任务之间保持就绪，不再每次从头建，迭代更快，质量门槛不变。

  （完整 17 角色名册见下。）
- ****Agent Velocity**** —— Agent 不再瞎报工时。每次估时和实际完成时间记成本地 JSONL。Human-time bias 自动检测。后续估时用基于你自己历史校准过的 AI-native p50 / p90 数字。
- ****Token Cost**** —— `aiplus agent token-cost` 读取 dispatch log，按 1 小时 / 8 小时 / 24 小时统计 token 消耗和 USD 成本，并列出最贵 task。定价来自社区维护的 per-model 表，带离线兜底和本地 override；也可直接跑 standalone `aiplus-token-cost`。

另外还有 **自然语言工具发现**：`aiplus install` 会写入项目本地 skill 和 preamble，让 Codex / Claude Code / OpenCode 在用户自然问成本、计划、审计、派单、团队状态时优先调用 AiPlus 的 `agent_*` MCP 工具，而不是绕去 shell grep、解析 CLI 输出，或只背训练数据。用户说 "implement X" 时，第一步应是 `agent_route_score_only`，不是直接背 checklist。

### Companion 模板

- ****AiPlus-Work-with-Me**** —— 上面七个模块都是 *项目本地* 的，AiPlus-Work-with-Me 是叠在它们之上的 **用户级 profile 包**：协作风格、项目地图、工具偏好 —— 填一次，所有项目都继承。它 **不会** 被 `aiplus install` 自动装上 —— 是显式 opt-in。复制它、填占位符（`USER.md` / `sync/projects.toml` / `secret-aliases.tsv`），然后 `aiplus profile install AiPlus-Work-with-Me --user --yes` 一次装完。私有 profile 存在 `~/.config/aiplus/profiles/`，**永远不会**被打包进公共仓库。

### 17 角色团队

`aiplus install` 默认装上 17 个在役角色的 SWE 团队 —— **12 核心角色 + 2 评审席 + 3 按需功能专家**，另有 5 个在规划中 —— 全部可作为 subagent 路由。完整 persona 文档在 [`.aiplus/agents/personas/`](.aiplus/agents/personas/)。

![一张路由示意图：左侧是自然语言请求（例如「修一下这个 bug」「评审这个 PR」「安全 / 权限检查」「这个大概要多久？」），流向 CEO；CEO 按风险给每个任务定级 LIGHT、MEDIUM 或 HEAVY 并分配匹配角色。LIGHT 交给单个工程师，跳过 architect、reviewer、qa；MEDIUM 引入 2-3 个匹配风险轴的角色；HEAVY 跑完整评审席，含 advisor。说「帮我实现某功能」时，第一步先触发 agent_route_score_only 预览配人，确认后才开始干活。](docs/screenshots/routing-zh.webp)

**12 核心角色**

- `advisor` —— 帮 Owner 判断方向与取舍的反思型第二意见。
- `ceo` —— 派活、排序、跟踪进度、汇报风险的执行协调者。
- `architect` —— 系统设计，以及那些以后难改的结构决定。
- `pm` —— 把需求拆成范围裁剪、验收标准、定义「做完」。
- `ui-designer` —— UI/UX 方案、交互流程、状态、用户路径。
- `ai-integration` —— LLM/agent 工作流、prompt、eval、兜底、成本/延迟。
- `engineer-a` —— 主力实现，默认工程师。
- `engineer-b` —— 第二工程师，需要并行时分担实现工作。
- `integration-manager` —— 中立的 lane 整合发现、dry-run 计划、冲突检查。
- `reviewer` —— 对抗式代码评审，给 PASS / REVISE / BLOCKED 结论。
- `security-reviewer` —— 检查权限、secret、计费、隐私风险。
- `qa` —— 行为验证者，给可复现的 PASS / FAIL 证据。

**2 评审席**（读 / 验证 / 报告 / 建议；不做实现）

- `release-manager` —— 发版就绪度、CI / 检查、smoke、产物、checklist。
- `evidence-auditor` —— 主张对证据的审计；找出过时或缺失的证据。

**3 按需功能专家**（CEO 在核心角色不够用时咨询）

- `tech-writer` —— README、文档、上手流程、错误信息文案清晰度。
- `devops` —— CI/CD、部署、回滚、监控、on-call 体验。
- `researcher` —— 最佳实践搜寻者、benchmark 方法论检查者。

CEO 给进来的任务定级 LIGHT / MEDIUM / HEAVY：LIGHT 任务跳过 Architect/Reviewer/QA，MEDIUM 任务咨询匹配风险轴的 2–3 个角色，HEAVY 任务跑全表，含 Advisor。

![Lobby 选角色胶片：运行 aiplus，角色名册按核心团队 / 评审席 / 按需专家分组出现；输入编号选择角色（这里是 ceo），会话随即绑定到该角色——记忆载入，但不授予任何权限。](docs/screenshots/lobby-filmstrip-zh.webp)

![派活流程的图解动画：任务进来，CEO 角色给它评级并用 agent_route_score_only 预览配人，把工作扇出给匹配的角色（engineer-a、reviewer、qa）在并行车道推进，再扇入成一份 Owner 把关的状态报告，附大白话「小白版」摘要。](docs/screenshots/dispatch-zh.webp)

---

## Before / After

| 痛点 | 用前 | 用后 |
|------|------|------|
| **AI 跨 session 就忘** | 周一教过 naming 规则，周三又问；同一架构决定讲过四遍 | 项目决定和任务状态留在项目里，下个 session 直接续上 |
| **API key 反复粘贴** | 每个新对话 / 新项目都要把 `OPENAI_API_KEY` 贴进 shell、`.env` 或 prompt | 在机器上设一次 secret alias，之后从任何 session 复用，原始 key 不进对话 |
| **`/compact` 反复烧 token** | 忘了 `/compact` 导致 agent 重读越来越长的历史；compact 时机不对又让下个 session 重新解释已决定的事 | 恰当时机的 compact 信号 + 结构化交接 + checksum 校验续接，让 token 花在新工作上 |
| **一个 AI 戴所有帽子** | 同一个 assistant 既做 plan、又写代码、又自评、又宣布完工 | 有名团队：产品、设计、工程、评审、安全、QA、整合、面向 Owner 的协调各有其人 |
| **任务管不到底** | 谁负责、什么算做完、卡在哪都说不清 | CEO 派活、跟踪状态、汇报 blocker，保留在途任务的事实来源 |
| **危险操作太容易混进去** | push、release、改 secret、改账号容易混进普通 coding 指令里 | 高风险操作 Owner-gated：agent 准备建议，Owner 显式批准 |
| **估时锚定在「人类工程师小时数」** | 报「五小时」做 refactor，结果 20 分钟干完；下次又报五小时 | 估时用基于你自己历史校准过的 AI-native p50 / p90 数字 |

---

## Why it matters + audience + safety

### 谁会用这个

AiPlus 先服务软件工程师，同时支持 opt-in 研究模块，底座（substrate）共享：

- **软件工程师** —— 用 Claude Code / Codex / OpenCode 写代码的。`aiplus install` 默认装 17 个在役角色的 SWE 团队（12 核心 + 2 评审席 + 3 专家）。
- **应用经济学研究者** —— 写论文、做 replication package、跑 LLM-as-measurement。`aiplus add aieconlab` 装上 **AdamSmith: AiEconLab (AEL)**，这是 bundled opt-in module，提供面向经济学 plan-time review 的研究角色和专家评审。
- **AI agent 研究者** —— 做 agent benchmark、实验设计、复现实验和论文写作。`aiplus add agentsciencelab` 装上 **AgentScienceLab (ASL)**，这是 bundled opt-in module。AEL 和 ASL 都不会随默认安装自动装上。

这些受众共用七个 substrate 模块：`aiplus-agent-memory` / `aiplus-compact-reminder` / `aiplus-auto-team-consultant` / `aiplus-agent-team` / `aiplus-agent-key` / `aiplus-agent-velocity` / `aiplus-token-cost`。

![一张分层示意图。底部是共享的项目本地 substrate 模块底座（记忆、团队、key、velocity 等），由 aiplus install 安装。其上是三条受众车道：默认安装的软件工程团队，以及通过 aiplus add 选装的应用经济学（AdamSmith: AiEconLab）和 AI agent 研究（AgentScienceLab）实验室包。整个栈之上漂浮着一层用户级 Work-with-Me profile：填一次、所有项目都继承；它是 opt-in 的，存在 ~/.config/aiplus 下，永远不会被打包进公共仓库。](docs/screenshots/substrate-zh.webp)

### 安全边界

AiPlus 把本地 AI coding 工作牢牢握在 Owner 手上。除非 Owner 显式批准被 gated 的动作，正常使用中它 **不会** push、publish、release、改 secret、改外部账号、改全局 agent 配置，也不会碰生产环境。

它 **不会**：

- 上传项目数据、prompt、transcript 或发送遥测（telemetry）；不云同步；不调外部服务。
- 在 memory / 交接文件 / task ledger 里存原始 secret。
- 自己批准 push、merge、tag、release、发包或外部账号变更。
- 在正常使用中改你的全局 agent 配置。

值得了解的几道防线：

- dispatch log 带 **防篡改哈希链**；`aiplus agent audit verify-log` 能检出事后的改动或被删掉的条目。
- **Mac Secure Enclave commit 签名** 通过 `aiplus identity setup-signing` opt-in 开启，签名私钥留在硬件里。

这些防线帮助证据留存和评审 —— 它们 **不是** 安全或合规认证。**Owner Auth 是 roadmap / spec，不是实时授权** —— 日志、Advisor 文字、team memory、本地笔记都只能作为 review evidence，不能授权 push、merge、tag、release、publish、改 secret、碰外部账号或改全局设置。

---

## Get started

### 安装 AiPlus

```bash
curl -fsSL https://raw.githubusercontent.com/izhiwen/AiPlus_StarWeaver/main/install.sh | bash
```

这会在你机器上装好 `aiplus` 命令。

### 把 AiPlus 装进你的项目

```bash
cd MyProject
aiplus
```

第一次在项目里运行 `aiplus`，它会替你把一切装好 —— 项目本地的规则、团队文件，以及为你已安装的 AI coding 工具（Claude Code、Codex、OpenCode）装上默认的 17 角色 SWE 团队 —— 然后直接把你带进 lobby。按 Enter 从 CEO 开始，或挑任意角色。你没装的 runtime 会被自动跳过，全程**不动你的全局配置**。

![终端录屏：在项目里首次运行 aiplus，自动为每个检测到的运行时安装适配器（不动全局配置），初始化 .aiplus/，并打开分组角色 lobby——零配置上手，无需单独的安装步骤。](docs/screenshots/install.gif)

进去之后，你不用记命令。直接用自然语言问 agent —— "都装好了吗？""装了哪些？" —— 它会替你跑对应的检查。

*可选：只想装一个 runtime，运行 `aiplus install claude-code`（也可 `codex`、`opencode`、`all`）。以后更新，运行 `aiplus update`。*

### 状态

最新发布：**`v0.7.23`**，可从 [Releases](https://github.com/izhiwen/AiPlus_StarWeaver/releases/latest) 获取（预编译二进制覆盖 Apple Silicon macOS 和 Intel Windows，并发布 checksums）。`main` 分支持续活跃开发；`main` 可能包含比最新 tag 更新的内容 —— 已发布能力以最新 tag 和 release notes 为准。README 里某些细节，在明确标注时，可能描述比最新 tag 更新的工作。

如果它帮你省了时间，欢迎 [在 GitHub 上给 AiPlus 点个 Star](https://github.com/izhiwen/AiPlus_StarWeaver)。

### License

Source available. [License](LICENSE).

