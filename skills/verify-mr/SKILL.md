---
name: verify-mr
description: >
  Verifies and reviews a GitLab Merge Request against its JIRA ticket's acceptance
  criteria, then writes a Markdown recap file to ~/projects. Works with NO GitLab
  token, MCP or glab — the MR is fetched through `refs/merge-requests/<N>/head` on
  the existing git remote. Goes beyond a code read: it runs the repo's real quality
  gates (tests, static analysis, code style), empirically reproduces every suspected
  defect by executing code, and cross-checks sibling branches for conflicts and
  divergent conventions. Use for "vérifie la MR", "review la MR X du ticket Y",
  "verify MR 276", "check MR against ticket", "review + vérification de MR".
argument-hint: "[JIRA-KEY] [MR number or URL]"
---

# Verify MR — review against the JIRA acceptance criteria

Produce a **verified** review: every claim in the report must be backed by a command
that was actually run or a snippet that was actually executed. No inference-only
findings.

Two references support this skill — read them when you reach the relevant phase:

- `references/verification-playbook.md` — concrete recipes (tokenless MR fetch, quality-gate
  detection, empirical reproduction inside the project container, sibling-branch discovery)
- `references/report-template.md` — the exact skeleton of the output file

## 0. Parse the input

From `$ARGUMENTS`, extract:

- **JIRA key** — pattern `[A-Z]+-[0-9]+` (e.g. `FCP-4577`), or a full `browse/` URL
- **MR** — a bare number, `!276`, or a full `.../merge_requests/276` URL

If either is missing, ask for it and **STOP** — this skill cannot work without both.
From an MR URL, also derive the GitLab project path
(`blv_software/customerfinance/customerpayment/fcp-financial-worker`); its last segment
is the repo name used in the next phase.

## 1. Read the ticket

Call the Atlassian MCP `getJiraIssue` with `cloudId: "support-tech.atlassian.net"`,
`responseContentFormat: "markdown"` and
`fields: ["summary","description","status","issuetype","comment","labels","assignee"]`.

Extract and keep:

- the **business rule** and every **acceptance criterion** — these become the conformity matrix
- everything declared **out of scope** — violating it is a finding
- **PO decisions taken in the comments** — they often override or refine the description
  (e.g. a label format arbitrated after the ticket was written). Comment threads are
  part of the spec.
- linked / twin tickets, and the epic

## 2. Locate the repo and fetch the MR

Find the local clone (usually `~/projects/*/<repo-name>`; `find ~/projects -maxdepth 3 -type d -name '<repo>'`).

**Before touching git, check the working tree is clean** (`git status --porcelain`).
If it is not, do NOT check anything out — report the dirty state and ask how to proceed.

Record the current branch so it can be restored in phase 8. Then follow the tokenless
fetch recipe in the playbook:

```bash
git fetch origin "refs/merge-requests/<N>/head:refs/heads/mr-<N>" --force
git fetch origin <base> -q          # base is usually develop or main
```

Determine whether the MR is **already merged** into the base
(`git merge-base --is-ancestor mr-<N> origin/<base>`). If it is, say so up front — the
review then documents shipped code rather than gating a merge, and `git diff base...mr-N`
will be empty.

Collect: commit list, `--stat`, and the full diff split into source and tests.

## 3. Understand the change

Read the **complete post-change file**, not just the diff hunks — a diff hides the
surrounding contract. Specifically pull in:

- the domain models the changed code constructs (their docblocks often state invariants
  the diff silently breaks or finally honours)
- the callers of anything whose signature or sign convention moved
- how the produced values are aggregated downstream (totals, sums, serialisation)

Note every commit whose `Ref:` tag names a **different ticket** than the one under review —
that is scope creep and belongs in the report.

## 4. Build the conformity matrix

One row per acceptance criterion (including the PO decisions from the comments and the
out-of-scope statements), with: criterion / status ✅⚠️❌ / **where it is verified**
(`file:line` or test name). This is the core of the report — do it before hunting for defects.

## 5. Run the real quality gates

Check out the MR branch, then discover the project's actual targets rather than guessing
(`grep -E "^[a-zA-Z_-]+:" Makefile .make/*.mk` — see the playbook). Run tests, static
analysis and code style.

**Critical:** a failing style or lint check is only a finding if it touches a file in this
MR. Cross-check every reported file against the diff's file list; pre-existing violations
inherited from the base branch must be reported as such, never attributed to the author.

## 6. Prove every finding empirically

For each suspected defect, **execute code that demonstrates it** — do not reason it out.
The playbook gives the reflection-script recipe for calling a private method inside the
project's container. Quote the real output in the report.

Systematically probe these, they are where grouping/aggregation changes break:

- a **zero / empty / null input** that the pre-change code filtered out earlier in the flow
  (guards frequently end up on the wrong side of a newly inserted step)
- `null` vs `''` collapsing into the same map key
- items that **cancel out** and make a whole group disappear
- ordering dependence (does reversing the input change the output?)
- assumptions asserted only in a docblock — feed it input that violates them
- float accumulation and rounding placement

Drop anything you cannot reproduce, or label it explicitly as unverified.

## 7. Cross-check sibling branches

Twin stories editing the same file are a recurring source of trouble:

```bash
git ls-remote --heads origin | grep -iE "<related-ticket-numbers>"
```

For each sibling: its fork point (has it been rebased?), the files it touches (overlap
with this MR?), and whether it solves the *same* sub-problem *differently* (different
delimiter, different guard placement). A twin that handles an edge case this MR misses
is strong evidence the omission is a bug, not a design choice — cite it.

## 8. Restore the repo

Check out the original branch and confirm `git status --porcelain` is empty. Never leave
the user's clone on a review branch. Mention the temporary `mr-<N>` branches at the end
of the report with the command to delete them.

## 9. Write the report

Write to **`~/projects/<jira-key-lowercase>-review-mr-<N>.md`**, following
`references/report-template.md`.

Rules:

- **Write in the language of the JIRA ticket** (French tickets → French report)
- Rank findings by severity 🔴 blocking / 🟠 to arbitrate / 🟡 to note / ℹ️ informational —
  and be honest about severity, a style nit is not 🔴
- Every finding: exact `file:line`, the executed reproduction with its **real** output,
  the concrete fix as a code block, and the test to add
- A dedicated **positives** section — reviews that only list defects are read as hostile
  and get ignored
- End with an actionable checklist and a **method annex** listing every command run, so the
  review can be replayed
- Give a score out of 10 and a clear verdict

## 10. Report back

Summarise in chat: verdict, score, the blocking finding(s) with their reproduction, and
the file path. Do **not** post anything to JIRA or GitLab unless explicitly asked.

## Output

- A Markdown file at `~/projects/<jira-key>-review-mr-<N>.md`
- A chat summary: verdict, score, blocking findings, file path
- The git clone restored to its original branch, working tree clean
