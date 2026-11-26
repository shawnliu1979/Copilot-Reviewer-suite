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
index in the workspace-root README and only the files listed there. The main agent
does not supply convention content; the four context items below stay unchanged.
This applies to code and documentation alike. If the index is absent, the reviewer
skips convention checking silently — do not treat that as a failed review and do
not start an extra round because of it.

Every delegation MUST include these four items, because subagent calls are stateless
and do not inherit the main conversation:

* **Change summary** — what was changed in this round and why.
* **Changed files** — explicit paths, including newly created or deleted ones.
* **Previous findings** — the prior round's findings and, for each, whether it was
  fixed or dismissed with a reason. Write "first round" when there is no prior round.
* **Scope** — what to review, and what is explicitly out of scope.

Example delegation text:

```
Delegate to the shawnliu1979-reviewer subagent. Read-only review, do not edit files.
Change summary: <...>
Changed files: <...>
Previous findings and disposition: <... / first round>
Scope: review only these changes; ignore unrelated pre-existing code.
Return findings in the specified format and end with REVIEW: PASS or REVIEW: FINDINGS (n).
```

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

## 4. Termination

Stop when either condition is met:

* The shawnliu1979-reviewer returns `REVIEW: PASS`.
* **3 rounds** have been completed. This is a hard cap.

On hitting the cap, stop editing. Output a short unresolved-items list and state that
the loop was capped. Do not start a fourth round, do not silently continue, and do
not claim the change passed review.

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
