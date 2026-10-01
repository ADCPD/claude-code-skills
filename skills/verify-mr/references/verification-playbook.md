# Verification playbook

Concrete recipes for `verify-mr`. Everything here works **without** a GitLab token,
the GitLab MCP, or `glab`.

---

## 1. Fetch an MR with no token

GitLab exposes every MR head as a hidden ref on the normal remote. If the user can
`git fetch`, they can read any MR of that project.

```bash
cd <repo>
git fetch origin "refs/merge-requests/276/head:refs/heads/mr-276" --force
git fetch origin develop -q
```

Then:

```bash
git log --oneline origin/develop..mr-276          # commits carried by the MR
git diff origin/develop...mr-276 --stat           # scope (3 dots = vs merge-base)
git diff origin/develop...mr-276 -- src/          # source changes
git diff origin/develop...mr-276 -- tests/        # test changes
```

**Always use three dots.** `git diff A..B` also shows what landed on `A` since the fork;
`A...B` shows only what the MR actually changed.

### Detect an already-merged MR

```bash
git merge-base --is-ancestor mr-276 origin/develop && echo MERGED || echo "NOT merged"
```

If `git merge-base origin/<base> mr-<N>` returns the MR head itself, the MR is merged
and `git diff base...mr-N` is empty — inspect the commit directly instead:

```bash
git show <sha> --stat
git show <sha> -- src/
```

Say clearly in the report that the review documents shipped code.

### Read a file as of the MR, without checking out

```bash
git show mr-276:src/Path/To/File.php
git show mr-276:src/Path/To/File.php | grep -n "functionName"
```

Useful for reading models and callers while staying on the user's branch.

---

## 2. Protect the user's clone

Non-negotiable, in order:

```bash
git status --porcelain          # must be empty BEFORE anything
git branch --show-current       # remember it
# ... review ...
git checkout -q <original-branch>
git status --porcelain          # must be empty AFTER
```

If the tree is dirty at the start, stop and ask. Never stash someone else's work.

Temporary branches (`mr-<N>`) are harmless — leave them but tell the user:
`git branch -D mr-276`.

---

## 3. Discover and run the real quality gates

Never guess target names.

```bash
grep -E "^[a-zA-Z_-]+:" Makefile
grep -n "^include" Makefile              # targets often live in .make/*.mk
grep -E "^[a-zA-Z_-]+:" .make/*.mk
```

Believe Symfony projects (`fcp-*`) typically expose:

| Target | Purpose |
| --- | --- |
| `make phpunit arg=<path>` | tests, scoped to a file / folder / class |
| `make phpstan-all` | static analysis, src + tests |
| `make phpcs` | PHP_CodeSniffer |
| `make phpcs-fixer` | PHP-CS-Fixer, dry-run |
| `make tests` | PHPUnit + Behat |
| `make code` | all quality checks |
| `make ci` | full pipeline |

Scope the test run to the touched area first (fast feedback), then widen if the change
looks risky.

### Never attribute a pre-existing failure to the author

`make phpcs-fixer` commonly reports many files across the repo. Cross-check each one
against the MR's file list:

```bash
git diff origin/develop...mr-276 --name-only
```

Any reported file absent from that list is inherited from the base branch. Report it as
"pre-existing on `<base>`, not introduced by this MR". Getting this wrong destroys the
review's credibility.

If in doubt, run the same gate on the base branch and diff the two outputs.

---

## 4. Prove a finding by executing it

A review claim that was reasoned out but never run is a guess. Call the real code.

The reflection recipe — the script must sit **inside** the mounted project directory so
the container can see it:

```bash
cat > ./probe-tmp.php <<'PHP'
<?php
require '/app/vendor/autoload.php';

use App\Domain\FinancialDocument\Model\Ithaca\PayableRecoupmentLine;
use App\Infrastructure\FinancialDocument\Ithaca\PayableBalanceToAccountingInvoiceConverter;

$c = new PayableBalanceToAccountingInvoiceConverter();
$m = new ReflectionMethod($c, 'groupRecoupmentLines');   // private method
$m->setAccessible(true);

foreach ($m->invoke($c, [
    new PayableRecoupmentLine('ITM-1', 'DDA', 'PRJ-1', '2025-03', 500.0),
    new PayableRecoupmentLine('ITM-1', 'DDA', 'PRJ-1', '2025-09',   0.0),
]) as $g) {
    printf("period='%s' amount=%s\n", $g->period, $g->amount);
}
PHP

USER_ID=$(id -u) GROUP_ID=$(id -g) docker compose \
  -f .docker/docker-compose.yml -f .docker/docker-compose.override.yml \
  --env-file=.env run --rm php php probe-tmp.php 2>&1 | grep -v "^ Container"

rm -f ./probe-tmp.php     # always clean up
```

Quote the real stdout in the report. Show expected vs obtained side by side.

For a public entry point, prefer calling `convert()` / the public API over reflection —
it proves the defect reaches the actual output rather than an internal helper.

---

## 5. Edge cases worth probing on any grouping / aggregation change

Ordered by how often they turn out to be real:

1. **A guard that ended up on the wrong side of a new step.** Find the guard that filtered
   inputs before the change (`if (0.0 === $x) continue;`). If a grouping/mapping step was
   inserted *before* it, the guard now filters *outputs* and the filtered inputs silently
   feed the new step's side computations (labels, ranges, counters).
2. **`null` vs `''` in a map key.** `$x ?? ''` merges two semantically distinct values, and
   the surviving record takes whichever arrived first → order-dependent output.
3. **A group that nets to zero** and therefore disappears entirely — losing the audit trail
   of two real movements.
4. **Input ordering.** Reverse the input array. Different output = latent bug.
5. **Docblock-only assumptions.** "periods are zero-padded `YYYY-MM`" is enforced by nothing.
   Feed it `2025-Q1` and show what happens.
6. **Rounding placement.** Per item vs per group changes totals at the cent.
7. **Sign conventions.** If amounts became `abs()`, verify every downstream aggregation
   re-applies the sign (`sign * amount`), including VAT bases and auto-liquidated amounts.

---

## 6. Find sibling branches

Twin stories from the same epic routinely edit the same file.

```bash
git ls-remote --heads origin | grep -iE "4576|4577|4515"
git fetch origin <sibling-branch> -q
git diff origin/develop...<sha> --stat           # overlap with this MR?
git log  --oneline origin/develop..<sha>         # rebased, or still carrying old commits?
git merge-base origin/develop <sha> | xargs git log --oneline -1   # fork point
```

What to look for:

- **Same files** → merge conflict; recommend a merge order and a rebase
- **Not rebased** (its diff still replays commits already merged into base) → conflict is certain
- **Same sub-problem solved differently** — different key delimiter, different guard
  placement, different rounding. Cite it: a sibling that handles an edge case this MR
  misses is strong evidence the omission is an oversight, not a decision.

---

## 7. Severity calibration

| | Meaning |
| --- | --- |
| 🔴 | Wrong output reaches a consumer, or an acceptance criterion is unmet. Blocks the merge. |
| 🟠 | Real behaviour change the ticket does not cover, or a data-fidelity edge case. Needs a decision (often the PO's), not necessarily code. |
| 🟡 | Traceability, scope creep, conflict risk, convention divergence. Does not block. |
| ℹ️ | Suggestion, refactor opportunity, question. |

Do not inflate. A single genuine 🔴 with a runnable reproduction carries far more weight
than eight speculative ones — and it is the part that actually gets fixed.
