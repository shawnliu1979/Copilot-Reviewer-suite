# Copilot Reviewer 套件

一套可移植的 Copilot 配置模板：一个**通用的只读 reviewer 子 agent**（代码与文档都审），以及一个**主 agent 调用协议 skill**。同一套文件可安装到**用户级**（默认）或**项目级**（`--project`）。所有自定义条目统一带 `shawnliu1979-` 前缀，避免与团队仓库、插件或 marketplace 里的同名条目冲突。

本套件**不依赖任何外部 MCP 或网络服务**，全部能力来自 Copilot harness 内置工具。本目录只是模板文件，**不会自动生效**；需要由你自己运行 `install.sh` 安装。脚本只复制本目录内的 3 个文件到目标配置目录，不安装任何运行时、不下载依赖、不修改任何 VS Code 设置，也不会覆盖已存在的同名文件（除非显式 `--force`）。登记块**不参与安装**——它是要由你手工追加进项目根 README 的内容，原文在第 5 节，不是 Copilot 配置文件。

## 1. 目录与路径映射

> **路径书写约定**：本文档不写入任何本机绝对目录。文件引用一律用**相对路径**（以本套件目录为基准）；`~`、`<repo>`、`$REPO_ROOT`、`$COPILOT_HOME` 均为抽象占位符或官方规范位置，不指向具体磁盘结构。命令示例均以套件目录为当前目录。

```
copilot-user-kit/
├── install.sh                              # 安装脚本（--user / --project），本身不需要安装
├── README.md                               # 本说明，不需要安装
├── agents/
│   ├── shawnliu1979-reviewer.agent.md      # → <目标>/agents/shawnliu1979-reviewer.agent.md
│   └── shawnliu1979-implementer.agent.md   # → <目标>/agents/shawnliu1979-implementer.agent.md
└── skills/
    └── shawnliu1979-review-loop/
        └── SKILL.md                        # → <目标>/skills/shawnliu1979-review-loop/SKILL.md
```

`<目标>` 由安装参数决定，两类目录都是 **Copilot harness 的原生位置**（`~` 代表用户家目录，`<repo>` 代表仓库根，二者均为占位符）：

| 类型 | 用户级（默认，`--user`） | 项目级（`--project`） |
|---|---|---|
| 目标根 | `~/.copilot/` | `<repo>/.github/` |
| 自定义 agent | `~/.copilot/agents/*.agent.md` | `<repo>/.github/agents/*.agent.md` |
| Skill | `~/.copilot/skills/<name>/SKILL.md` | `<repo>/.github/skills/<name>/SKILL.md` |
| 生效范围 | 跨所有工作区 | 仅当前仓库，可进版本库共享给团队 |
| 自定义指令（本套件不含） | `~/.copilot/instructions/` | `.github/copilot-instructions.md` 或 `AGENTS.md` |

用户级根目录可用环境变量 `COPILOT_HOME` 覆盖（默认 `$HOME/.copilot`）。项目级目录按 `<repo>/.github/agents` 与 `<repo>/.github/skills` 拼接，`<repo>` 省略时取当前工作目录。

### 命名约定

| 条目 | 全名 | 文件名 / 目录名 |
|---|---|---|
| 只读审核者 | `shawnliu1979-reviewer` | `agents/shawnliu1979-reviewer.agent.md` |
| 主 agent | `shawnliu1979-implementer` | `agents/shawnliu1979-implementer.agent.md` |
| 调用协议 skill | `shawnliu1979-review-loop` | `skills/shawnliu1979-review-loop/SKILL.md` |

前缀取自全局唯一的 GitHub 账号 `shawnliu1979`。继承者**必须遵守三条规则**，否则委派或加载会直接失效：

1. **连字符形式**：Skill 的 `name` 只允许小写字母、数字、连字符（≤64 字符），禁止斜杠、点号与任何 namespace prefix —— 带斜杠的 scope 写法、带点号的反向域名写法都不合法。
2. **名称与目录同步**：Skill 的 `name` 必须与其父目录名完全一致，改名要两处同时改。
3. **委派用全名**：一律写 `shawnliu1979-reviewer` 等全名，缩写成 "reviewer" 会让前缀失效。

选型理由（前缀为何存在、长度核算）见第 6 节第 11 条。

## 2. 安装（请你自己执行，我不会代跑）

脚本用自身所在目录定位模板，本身可从任意位置调用；下面的命令示例统一采用**相对路径**写法，以套件目录为当前目录（若套件目录名为 `copilot-user-kit`，从它的父目录进入即可）：

```bash
cd copilot-user-kit       # 相对路径进入套件目录；按你实际放置的位置调整
chmod +x install.sh       # 只需一次
./install.sh --dry-run    # 强烈建议：先确认将写入哪里、写什么，此步不写入任何文件
```

### 参数

| 命令 | 效果 |
|---|---|
| `./install.sh` | **默认用户级** → `~/.copilot/` |
| `./install.sh --user` / `-u` | 显式用户级，同上 |
| `./install.sh --project` / `-p` | **项目级** → 当前目录的 `.github/` |
| `./install.sh --project ../myrepo` | 项目级，指定仓库根（相对路径示例） |
| `./install.sh --project=../myrepo` | 同上，等号写法 |
| `./install.sh -n` / `--dry-run` | 只打印动作，不创建目录、不写文件 |
| `./install.sh -f` / `--force` | 覆盖已存在的同名文件（默认跳过并提示） |
| `./install.sh -h` / `--help` | 完整帮助 |

作用域参数可组合，最后一个生效（例如 `--project ../myrepo --user` 会退回用户级）。`--project` 的参数既可用相对路径，也可用你自己环境里的其它写法。

### 实际执行

确认 `--dry-run` 输出无误后，二选一：

```bash
./install.sh                        # 用户级（默认）
./install.sh --project ../myrepo     # 项目级
```

脚本内置护栏：项目目录必须已存在；拒绝把项目级配置写进 `/` 或 `$HOME`；目标不是 git 仓库根时给出提示但不阻断；同名文件默认跳过并逐条列出。每次运行都会打印作用域、目标根、逐文件动作与「复制/跳过」汇总。脚本用 glob 与 `find` 遍历模板，条目改名不会影响复制逻辑。

## 3. 验证

1. **项目级安装**时，必须在**以该仓库为工作区打开的 VS Code 窗口**里验证；用户级则任意窗口可见。
2. Chat 视图选 **Copilot** harness，运行 `Chat: Open Customizations`，在 **Agents** 里应看到 `shawnliu1979-implementer`；`shawnliu1979-reviewer` 因 `user-invocable: false` 不出现在下拉框，但会在自定义编辑器里列出。
3. 在 **Skills** 里应看到 `shawnliu1979-review-loop`；在 chat 输入框输入 `/` 应能看到 `/shawnliu1979-review-loop`。
4. Chat 视图右键 → **Diagnostics**，检查三个文件都被加载且无解析错误。
5. 选 `shawnliu1979-implementer`，让它做一个极小的文档改动，然后检查**工具调用记录**里确实发生了一次委派（response 里光描述"我会 review"不算）。
6. 检查该次委派的工具活动只有 `read` / `search`，没有 `edit` / `execute`。
7. 若用户级与项目级都装了同名条目，自定义编辑器会出现重复；只保留一处即可（卸载就是删除对应目录下那 3 个文件）。
8. 把第 5 节的登记块追加到一个测试项目的根 `README.md`，并把其中一行改成指向真实存在的规约文件；改一处违反它的内容，检查工具活动里 reviewer 确实 `read` 了根 README 与该规约文件、finding 同时引用了变更行与规约条款行。再删掉登记块，确认它不输出任何「未找到规约」之类的内容，verdict 不受影响。
9. **五要素验收**：故意从委派文本里删掉一个变更文件路径，但任务包里的 `git status --porcelain` 输出仍包含它。reviewer 应据该清单审到它，或明确在 `Unverified` 里指出清单不全 —— 出现「未提及该文件且无说明」即不合格。
10. **读取预算验收**：检查一次委派的工具活动，`Context:` 行列出的路径数应与实际 `read` 一致，且不含重复路径；总数不超过 12（变更文件本身不计）。
11. **超时降级验收**：中断一次委派（或在测试项目中把范围放大到超时），确认主 agent 只重试一次、随后把该面记入 `Unverified` 并继续，而不是无界重试或谎报 PASS。

## 4. 使用方式

* **推荐**：在 Agent 下拉框选 `shawnliu1979-implementer`，正常下任务。它通过 `skills: ['shawnliu1979-review-loop']` 固定加载调用协议，每次改动后自动委派 `shawnliu1979-reviewer`，修复 → 再 review，直到 `REVIEW: PASS` 或满 3 轮。
* **不切 agent**：保持通用 agent，在任务里显式写 `/shawnliu1979-review-loop`，或直接写「完成后委派 shawnliu1979-reviewer 子 agent 审查」。
* Skill 的 `description` 也支持按相关性自动加载，但官方明确说明「发现 ≠ 保证每次都调用」。要可靠触发，请显式点名，并使用全名。

**装好之后还有一步：** 若希望 reviewer 按你项目的规约审查，需要在项目根 README 里登记规约索引，见下一节。不登记不会报错，但规约检查会整体跳过 —— 这是本套件最容易被忽略的一环。

## 5. 规约登记（项目根 README，可选但强烈建议）

这一节决定 reviewer **是否**按你的项目规约审查：登记了就按清单逐条比对，不登记就静默跳过、只做通用代码/文档审查。装完不等于能用上规约检查，务必读一遍。

规约检查**完全由根目录 README 驱动**：reviewer 只读工作区根目录的 `README.md`（不存在时尝试 `readme.md`），只认一个名为 `agent-review-conventions` 的登记块，**不会**自行扫描 `AGENTS.md`、`.github/copilot-instructions.md`、子目录 README 或其它文件。

登记块原文只有这一份，就保存在本节。`install.sh` 不安装它，需要你手工追加到目标项目根 README。直接复制下面代码块内的全部内容（不要带外层围栏）：

```text
<!-- BEGIN agent-review-conventions
# 本项目规约文档索引，供 shawnliu1979-reviewer 读取。
# 每行格式：[@instructions|@index] <相对仓库根的路径> [| <适用文件 glob，多个用逗号分隔>]
#   路径段 = 一份文档（文件），不会自动展开目录。
#   glob 段 = 该条目适用于哪些变更文件；省略表示 **（全部变更文件）。
#   @instructions = 规约正文，按条款比对（不带前缀的旧写法等价于此）。
#   @index        = 文档体系导航，只用于定位，不单独据此出 finding。
# 下面四行只是示例：路径、glob、条目数、注释行都可自由增删改，
# 套件不预置任何路径，也不读取本块之外的 README 内容。
# 删除本块、留空、或只留注释行 = 跳过整个规约检查。
@instructions docs/engineering/CODE_STYLE.md | src/**/*.ts,src/**/*.tsx
@instructions CONTRIBUTING.md
@index docs/README.md | **/*.md
docs/WRITING_GUIDE.md | **/*.md
END agent-review-conventions -->
```

粘贴位置可放在目标 README 的任意处，建议末尾。请用**源码视图**粘贴，不要粘进富文本编辑器，注释定界标记会被吞掉。

块内每一行都可以按你的项目自由增删改：路径、glob、条目数、注释行都归你所有，套件不预置、不假设任何路径。

### 登记块是数据，不是配置

* **完全可编辑。** 块内每一行的路径、glob、条目数量、注释文字都可自由增删改名；示例里的 `docs/engineering/CODE_STYLE.md`、`CONTRIBUTING.md`、`docs/WRITING_GUIDE.md` 只是占位。套件不预置、不假设、不缓存任何路径，reviewer 每次委派现场读取，块里写什么就读什么。就规约机制而言，套件硬编码的只有三样：根 README 的文件名、标记名、每行格式。
* **块是索引，不是规约本身。** reviewer 只把块内条目当作清单；README 中块外的文字一律不作为规约，仓库里的其它规约文件也不会被主动扫描。它会按清单去 `read` **列出的规约文件正文**，再与变更文件对照——读的是清单指向的内容，不是块本身那几行字。
* **路径段指向单个文件。** 每行路径段是一份规约文档，不会自动展开目录。若规约分散在某个目录里，请逐行列出；想圈定「适用于哪些变更文件」，用 `|` 后面的 glob 段表达（如 `src/**/*.ts`、`docs/**`），省略等价于 `**`。
* **块外零读取、缺失即跳过。** 删除整块、留空、或只留 `#` 注释行 → 跳过整个规约检查：不报告缺失、不写入 Unverified、不影响 `REVIEW: PASS`。
* **块内两类别混用。** `@instructions` 条目是审核标准，违反须引用条款行；`@index` 条目只是文档地图，供 reviewer 顺藤摸瓜找到覆盖变更路径的说明文档，**不单独据此出 finding**。无前缀行按 `@instructions` 处理，旧块无需改写。

| 项 | 规则 |
|---|---|
| 位置 | 必须是**工作区根目录**的 `README.md`（回退 `readme.md`）；子目录 README、其它文件名一律不读 |
| 标记 | 起止为一对 HTML 注释，名字分别是 `BEGIN agent-review-conventions` 与 `END agent-review-conventions`；字面以上方代码块为准（与模板文件一致），必须完全一致、成对出现 |
| 条目 | 每行一份文档：`[@instructions\|@index] <相对根的路径> [\| <适用文件 glob>]`；前缀与路径、glob 均可自由编辑，模板四行只是示例 |
| 前缀 | `@instructions` = 规约正文，按条款比对；`@index` = 文档体系导航，只定位不判罚；**无前缀等价于 `@instructions`** |
| 路径 | 相对仓库根；禁止绝对路径、`~`、`..`；**指向单个文件，不自动展开目录** |
| glob | 可选，逗号分隔；省略表示 `**`，即对所有变更文件生效；只对**匹配到的变更文件**应用该规约 |
| 预算 | 块内条目读取计入 reviewer 的 12 次启动读取预算，其中 `@index` 条目最多 3 次 |
| 关闭 | 整块删除、留空、或只留 `#` 注释行 → 跳过整个规约检查 |

| 根 README 状态 | reviewer 行为 |
|---|---|
| 无登记块 / 块内无条目 | **跳过整个规约检查**：不报告缺失、不写入 Unverified、不影响 `REVIEW: PASS` |
| 有块且列出路径 | 只读列出的文件，按 glob 应用到对应变更文件；违反项须同时引用 `变更文件:行` 与 `规约文件:行` |
| 路径不存在 / 不可读 | 记入 Unverified，**不算 finding**、不阻断 |
| 规约与仓库现状冲突 | 报告冲突本身，不单方面裁决谁对 |
| 规约文件本轮被修改 | 明确标注，不用新写的规则评判未改动的文件 |

两个要点：**不区分对象类型** —— 代码与文档都走这套流程，模板里 `docs/WRITING_GUIDE.md | **/*.md` 就是给文档 review 用的；**只做文本对照** —— reviewer 不能跑 lint / format / build / test，工具链强制的规约由主 agent 在 review 循环之外自行验证。委派协议是五要素，其中规约内容仍由 reviewer 自己按登记块读取，主 agent 只给路径与用户级指令原文。

## 6. 设计决策与已知限制

1. **只读边界靠 `tools`，不靠措辞。** `shawnliu1979-reviewer.agent.md` 的 `tools: ['read', 'search']` 才是硬约束。官方明确指出「不要编辑文件」这类指令不是工具级限制。Copilot harness 的内置工具别名为 `execute` / `read` / `edit` / `search` / `agent` / `web` / `todo`。
2. **显式 tools 会排除其余所有工具。** `shawnliu1979-reviewer` 只列了 `read` / `search`，因此终端、扩展工具与外部 MCP 一律不可见。这也是本套件不引入外部 MCP 的原因：给一个最小权限的只读审核者开外网输入面，收益不抵风险。核对第三方 API 用仓库内的类型定义、lockfile、`node_modules` 里的 `.d.ts` 与项目自身文档即可，无需出网。若将来确需扩展其能力，必须显式写进 `tools` 并单独评估。
3. **不要用 `handoffs:`、`agents:` allowlist、`argument-hint`** —— 这里指的是 **custom agent** 的 frontmatter，Copilot harness 不接受这些字段（Local-only）。Skill 的 `argument-hint` 是另一回事，官方支持，本套件已使用。委派用自然语言点名 + 原生 `task` 工具。
4. **不要依赖 `include-custom-instructions` / `mcp-servers` / `strict-tools-list` / `model-policy`。** 编辑器提供这些字段的补全和校验，但转换到 SDK 自定义 agent 配置时**不会转发**，因此不能用来控制运行时行为。
5. **规则写进 agent body，而不是全局 instructions。** 全局指令会被包括 `shawnliu1979-reviewer` 在内的所有 agent 继承，容易污染它的判断；body 指令才是随 agent 一起生效的。
6. **subagent 无状态。** 每次委派都是独立调用，不继承主会话历史。所以 `shawnliu1979-review-loop` 强制主 agent 每轮重传「改动摘要 / 变更文件 / 上轮 findings 与处置 / 审核范围」。
7. **循环上限写死为 3 轮**，并以 `REVIEW: PASS` / `REVIEW: FINDINGS (n)` 作为机器可判的终止信号。`chat.agent.maxRequests` 默认 **25**，是整轮请求预算而非 review 轮次，撞上会被截断而非优雅收尾。
8. **作用域差异。** 用户级跨所有工作区生效，因此两个 agent 刻意保持通用，不含任何项目路径、命令或团队规范。项目级只在当前仓库生效，适合把审核规范随仓库共享给团队，但文件会进入该仓库的版本库。建议**只装其中一处**；某项目的专属约定放该仓库自己的 `.github/copilot-instructions.md`。
9. **指令是软约束。** 官方原话：*Instructions guide the model. They don't guarantee compliance*。若发现主 agent 跳过 review，用验证步骤 5 的工具活动记录来确认，并在任务 prompt 里显式点名。
10. 企业托管的 Copilot 策略可能限制自定义 agent 与 skill，若加载失败先查组织策略。
11. **命名前缀不是装饰。** `name` 是委派的解析键：官方示例用 *"Use the Codebase Researcher subagent..."* 这类按名点名的方式，名字大小写敏感。用户级、工作区级、插件与组织级来源会合并进同一清单，同名条目无法区分，点名可能命中非预期实例。`shawnliu1979-` 取自全局唯一的 GitHub 账号；又因 Skill 的 `name` 受字符集约束且必须与目录名一致，前缀只能用连字符形式。`shawnliu1979-implementer.agent.md` 与 SKILL.md 里的自然语言点名也必须用全名，缩写会让前缀失效。三个 name 长度为 21 / 24 / 24 字符，均在上限内。
12. **规约检查是索引驱动，不做全仓扫描，但允许受控读取指令。** 只认工作区根 `README.md` 里的 `agent-review-conventions` 块，reviewer 不自行 glob `AGENTS.md` / `CONTRIBUTING.md` / 子目录 README。原因：subagent 不自动继承项目指令（`include-custom-instructions` 运行时不转发），让模型自行判断「哪些文件算规约」既不稳定又吃上下文；单一登记块把「有没有、在哪、适用谁」变成可显式声明的事实。为避免 reviewer 无入口乱撞，agent body 内置**上下文启动协议**：固定顺序读取根 README → 登记块 → `@instructions` → `@index`，受 12 次读取预算与「连续 2 次失败即停」约束；读取只用于定位，不扩大 review 范围。**用户级指令位于工作区外，reviewer 读不到，由主 agent 在委派中原样附上。** 代价是**未登记即不检查** —— 这是有意的：没有就跳过，不猜、不编造、不降级 verdict。代码与文档一视同仁，不设对象类型开关。
13. **登记块只有 README 第 5 节这一份原文；块内容是可编辑数据，不是套件配置。** 套件不再维护独立的模板文件，避免同一字面出现多份副本需要人工同步。登记块**不参与安装**：它是要被追加进项目 README 的内容，放进 `~/.copilot/` 或 `.github/` 都不会被读取。块内每一行的路径、glob、条目数与注释都归项目所有，可随时增删改；reviewer 只消费块内清单，块外文字与其它规约文件一律不读，且 `read` 的目标是清单指向的规约正文而非块本身。路径段不自动展开目录，目录范围请用 glob 段表达。
14. **文档不写入本机绝对路径。** 所有文件引用均为相对路径（以套件目录为基准）；`~`、`<repo>`、`$REPO_ROOT`、`$COPILOT_HOME` 是抽象占位符或 Copilot 官方规范位置，不代表任何具体机器的目录结构。这样本套件可原样复制、提交进版本库或分享给他人，无需按放置位置改写文档。
15. **子 agent 超时只能靠运行时配置 + 协议兜底。** Copilot CLI 的 `/subagents` 提供 `timeoutSeconds`、`maxConcurrentSubagents`、`maxTotalSubagents`、`maxAiCredits`，这是 harness 的硬上限，agent body 与 skill 都无法设置；VS Code 侧是否有等价面板未确认，不作承诺。协议层只能做三件事：把单次委派按审查面拆小、以 `REVIEW: PASS` / `REVIEW: FINDINGS (n)` 末行判定是否完成、超时后**只重试一次**并计入 3 轮上限。不要往委派文本里写「请在 N 秒内完成」——模型没有可靠墙钟，写了只占上下文。重试无界会烧穿 `chat.agent.maxRequests`（默认 25）导致整轮被截断。

## 7. 文件职责一览

| 文件 | 职责 |
|---|---|
| `install.sh` | 安装脚本。默认用户级，`--project` 切项目级；支持 dry-run / force / help |
| `agents/shawnliu1979-reviewer.agent.md` | 只读审核者。通用代码 + 文档审核清单、根 README 索引驱动的规约检查、结构化 finding 格式、PASS/FINDINGS 终止标记 |
| `agents/shawnliu1979-implementer.agent.md` | 主 agent。持有工作树写权限，通过 `skills` 固定加载调用协议 |
| `skills/shawnliu1979-review-loop/SKILL.md` | 主 agent 如何调用 reviewer：五要素委派包、按审查面拆分、结果与 `Context:` 核验、超时降级、3 轮上限 |
| README 第 5 节代码块 | 规约登记块原文，也是唯一副本。**不安装**，由用户手工追加到项目根 README；块内路径/glob 可自由编辑 |
| `LICENSE` | GPL-3.0 官方许可原文（未改动）。全项目适用，分发与修改须遵守其条款 |
| `.gitignore` | 忽略 macOS 杂项、编辑器临时文件与脚本日志 |

## 8. 许可证

本项目以 **GNU General Public License v3.0（GPL-3.0）** 发布，完整条款见根目录 [LICENSE](./LICENSE)。GPL-3.0 是强 copyleft 许可：分发本项目或其衍生作品时，须以同一许可提供完整对应源码并保留版权与许可声明；不提供任何担保。若需并入闭源分发，须另行取得版权持有人的书面许可。

`install.sh` 文件头带 `SPDX-License-Identifier: GPL-3.0-only` 标识。
