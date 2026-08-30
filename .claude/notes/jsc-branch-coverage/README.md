# JSC control-flow-profiler patches for lcov branch coverage

Unfinished work, parked. This branch exists only so the patches survive; it is
not meant to merge into `main` and nothing here is wired into the build.

Context: [oven-sh/bun#7100](https://github.com/oven-sh/bun/issues/7100) asks
`bun test --coverage` to report branch coverage. Bun can emit lcov
`BRDA`/`BRF`/`BRH` from JSC's control-flow profiler, but the numbers come out
wrong, and the root cause is in JSC rather than in Bun's reporter. These patches
are an attempt at the JSC half.

## What is here

| File                            |                                                                                               |
| ------------------------------- | --------------------------------------------------------------------------------------------- |
| `jsc-branch-coverage.patch`     | The real attempt. 15 files, +163/-40.                                                         |
| `jsc-profile-logical-ops.patch` | An earlier, smaller experiment. Probably superseded — see below.                              |
| `ccobj.sh`                      | The script used to compile-validate a single JSC translation unit. Its paths no longer exist. |

Both apply to **oven-sh/WebKit at `d71031a973e6f8838a1b10282dbe332ff012f04a`**,
the revision `scripts/build/deps/webkit.ts` pinned when they were written.
`jsc-branch-coverage.patch` is a `git`-style diff with a `Subject:` header
explaining the design; read that header first, it is the best description of the
change. `jsc-profile-logical-ops.patch` is a plain two-file diff of
`NodesCodegen.cpp`, not a git patch, so it needs `patch -p0` rather than
`git apply`.

## What `jsc-branch-coverage.patch` does

Adds `BasicBlockKind { Continuation, Branch }` and threads it from each
`emitProfileControlFlow` call site through `UnlinkedCodeBlock::RareData` (in a
parallel array, so `op_profile_control_flow`'s shape stays untouched for the
LLInt/DFG/FTL) to the `BasicBlockLocation` the profiler returns. It classifies
all 28 pre-existing emission sites individually and adds 8 new ones so `&&`,
`||` and `??` are profiled at all.

That fixes two of the three things wrong with the current output:

- Blocks opened after `return`/`throw`/`break`/`continue`, and at join points,
  are now marked `Continuation`, so a consumer can stop counting them as
  branches. Today a branchless, fully-exercised function reports `BRF:3 BRH:2`.
- The short-circuit arms of `&&`, `||` and `??` get profile points, so covering
  one changes the numbers.

## Why it is not enough on its own — read this before resuming

**It does not fix the implicit-`else` gap, and that makes it unsafe to land
alone.** In the patched `IfElseNode` codegen the `Branch` point for the else arm
is still inside `if (m_elseBlock)`, so an `if` with no `else` emits a block only
for the arm that runs.

Consequence: with this patch, a consumer that counts only `Branch` blocks sees a
bare `if` as one branch, which the true path already covers — a confident 100%
for code whose false path was never tested. Today's output over-reports, which is
at least visible. This would under-report invisibly, which is worse.

So the JSC-side work is not done. It needs a third change: emit a `Branch` block
for the path a bare `if` does not take. That reasoning is spelled out at more
length in the "Branch records (experimental)" section of
`docs/test/code-coverage.mdx` on the `claude/bun-issue-7100-pr-5coyui` branch.

## Verification status — weak

`jsc-branch-coverage.patch` has been **compile-validated only**: individual
translation units compile with `ccobj.sh`. It has never been linked, never run,
no JSC test has been executed against it, and no coverage output has ever been
produced by a JSC built with it. Treat "it compiles" as the entire evidence.

`jsc-profile-logical-ops.patch` looks superseded — the big patch adds the same
profile points at the same offsets, with kinds attached. That is a reading of the
two diffs, not something confirmed by applying both. Kept in case the smaller
change is worth landing on its own.

## If you pick this up again

The upstream path for a JSC change already has precedent in this project: open a
PR against `oven-sh/WebKit`, then a "Bump WebKit" PR in `oven-sh/bun` that moves
`WEBKIT_VERSION`. See
[oven-sh/WebKit#425](https://github.com/oven-sh/WebKit/pull/425) →
[oven-sh/bun#38321](https://github.com/oven-sh/bun/pull/38321) for the shape.

Before any of that: add the implicit-`else` block, then actually build a JSC with
the patch and check the numbers against a real test file. Landing the JSC half
without that measurement would be shipping a metric nobody has ever seen produced.
