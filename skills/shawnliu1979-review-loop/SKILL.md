---
name: shawnliu1979-review-loop
description: "Run after ANY code or documentation change. Delegates a read-only review to the shawnliu1979-reviewer subagent, applies confirmed findings, and re-reviews until REVIEW: PASS or 3 rounds. Use whenever files are created, modified, or deleted, including small edits. Owner: shawnliu1979."
argument-hint: '[optional: task summary or changed files]'
---

# Review loop protocol

This skill defines how the **main agent** calls the shawnliu1979-reviewer subagent. It is loaded
into the main agent's context. Invoke it explicitly with `/shawnliu1979-review-loop`, or rely on
automatic loading when a request involves changing files.

## 1. When to run

Run once per completed implementation step — after files change, before reporting
the task as done. This includes documentation-only changes. Do not run it before
any change exists.

## 2. How to delegate

Ask for the **shawnliu1979-reviewer** subagent by name in natural language. The Copilot harness
delegates via its native `task` tool; you do not construct the tool call yourself.

Always use the full prefixed name. Do not shorten it to a bare "reviewer" — that
name is not unique and may resolve to a different agent from a repository or plugin.

Project conventions are the reviewer's own responsibility. It reads the convention
index in the workspace-root README and only the files listed there. You supply
paths and user-level instruction text, never a summary of the rules — pasting a
digest makes the reviewer judge your paraphrase instead of the source. This
applies to code and documentation alike. If the index is absent, the reviewer
skips convention checking silently — do not treat that as a failed review and do
not start an extra round because of it.

Every delegation MUST include these five items, because subagent calls are stateless
and do not inherit the main conversation:

* **Change summary** — what was changed in this round and why.
* **Changed files** — explicit paths, including newly created or deleted ones.
  Derive the list from git (`git status --porcelain`, or
  `git diff --name-status <base>`), never from memory. Paste the command output.
  A hand-written list is how files go missing.
* **Previous findings** — the prior round's findings and, for each, whether it was
  fixed or dismissed with a reason. Write "first round" when there is no prior round.
* **Scope** — what to review, and what is explicitly out of scope.
* **Repository context packet** — build it once per task, reuse it every round:
  * repository root, primary language, package manager;
  * verified build / test / lint commands and a one-line result summary (the
    reviewer cannot run them);
  * for each changed document, the path of the index that lists it;
  * documentation map: doc root, index entry point, and the 2–5 documents that
    govern the area being changed;
  * project instruction paths, plus the **pasted text** of user-level
    instructions (`~/.copilot/instructions/`), which the reviewer cannot read;
  * excluded areas the reviewer must not search (`vendor`, `dist`, `build`,
    generated output, `node_modules`).

Example delegation text:

```
Delegate to the shawnliu1979-reviewer subagent. Read-only review, do not edit files.
Change summary: <...>
Changed files: <pasted git status --porcelain>
Previous findings and disposition: <... / first round>
Scope: review only these changes; ignore unrelated pre-existing code.
Repository context packet: <...>
Return findings in the specified format, include the Context: line, and end with
REVIEW: PASS or REVIEW: FINDINGS (n).
```

## 2.1 One delegation, one review surface

Split by surface, not by file count: correctness, documentation consistency, and
convention compliance are separate delegations when a change touches all three.
A single delegation that audits a whole repository is the main cause of timeouts
and of reads that never converge.

Keep every delegation atomic: one surface, one scope, one pass/fail signal.

## 3. How to handle the result

* `REVIEW: PASS` — stop the loop and report completion, including anything the
  shawnliu1979-reviewer listed under "Unverified".
* `REVIEW: FINDINGS (n)` — judge each finding against the actual code. Fix the ones
  that hold. For ones that do not hold, write down a one-line reason and dismiss them.
  Then start the next round with the updated context.
* Convention-derived findings follow the same verification rule and must cite both
  the changed `file:line` and the convention `file:line`. A finding that quotes a
  rule without a clause reference is not verifiable — dismiss it with a reason.
* Never apply a finding you cannot verify, and never argue with the shawnliu1979-reviewer inside
  its own conversation — subagent views are read-only. Send corrections through the
  next delegation's context instead.

Verify the run actually happened before trusting the verdict:

* The response's last line must be exactly `REVIEW: PASS` or `REVIEW: FINDINGS (n)`.
  Anything else — empty, truncated, prose only — is an **incomplete run**, not a
  result. Handle it per §3.1; do not treat it as PASS and do not guess findings.
* Check the `Context:` line against what the task actually required. If the reviewer
  was supposed to read a project instruction file or a documentation index and the
  line does not list it, the run is incomplete for that surface.
* Complete the check from the delegation's own tool activity, not from the report
  text. A response that says it read a file is not evidence that it did.

## 3.1 Timeout and incomplete runs

There is no per-call timeout switch in this protocol. Bound the work and make the
outcome judgeable instead:

* **Hard ceiling (host-side, when available).** In the Copilot CLI, `/subagents`
  exposes `timeoutSeconds`, `maxConcurrentSubagents`, `maxTotalSubagents`, and
  `maxAiCredits`. Set `timeoutSeconds` to 180–300 and
  `maxConcurrentSubagents` to 1 for review work. These are runtime settings, not
  something this skill or the agent body can set. In VS Code the equivalent panel
  was not confirmed; do not claim it exists.
* **Soft ceiling (this protocol).** An incomplete run is one that returns without
  a verdict line, or one that reports far fewer `Context:` paths than the task
  required. Treat both identically.

Recovery is bounded and never a loop:

1. **First incomplete run** — re-delegate the same surface once, with the packet
   unchanged plus a narrowed scope naming the 3–5 files to read and the rest to
   skip.
2. **Second incomplete run** — stop that surface. Record it under the final report
   as `Unverified: review timed out — <surface> not covered`. Move to the next
   surface. Do not retry with a different model, and do not widen the read budget.
3. **Count it.** Every re-delegation of §3.1 consumes one of the 3 rounds in §4.
   A timeout is not a free retry: the whole run shares
   `chat.agent.maxRequests` (default 25), so unlogged retries truncate the task
   instead of finishing it.

Do not write time limits into the delegation text. The model has no reliable wall
clock; a stated deadline only spends context and changes nothing.

## 4. Termination

Stop when either condition is met:

* The shawnliu1979-reviewer returns `REVIEW: PASS`.
* **3 rounds** have been completed. This is a hard cap.

On hitting the cap, stop editing. Output a short unresolved-items list and state that
the loop was capped. Do not start a fourth round, do not silently continue, and do
not claim the change passed review. This includes rounds consumed by §3.1 retries.

Be aware that `chat.agent.maxRequests` defaults to **25** for the whole run. A loop
that thrashes can exhaust this budget and be truncated mid-task. Three rounds is
deliberately conservative.

## 5. Guardrails

* The shawnliu1979-reviewer is read-only by construction (`tools: ['read', 'search']`). Do not
  ask it to fix anything, and do not try to widen its tools to make it do so.
* Instructions are guidance, not enforcement. Verify in the tool activity that a
  delegation actually happened; a response that merely describes a review is not one.
* Keep findings and code edits in the main conversation. The loop's value is that
  review intermediate work stays out of the main context.
* Convention checks are text-only. The reviewer may read the root README and the
  listed convention files, but cannot run linters, formatters, builds, or tests.
  Verify tooling-enforced rules yourself, outside the review loop.
* Do not use `agents:` allowlists, `handoffs:`, or `runSubagent` — these are
  Local-harness-only and are not recognized by the Copilot harness.
