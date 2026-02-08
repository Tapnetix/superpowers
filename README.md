# GGCoder

GGCoder is an extended version of [Superpowers](https://github.com/obra/superpowers) - a complete software development workflow for coding agents. It includes all the original Superpowers capabilities plus specialized code review and fixing for **GridGain 9 / Apache Ignite 3** codebases.

## What's New in GGCoder

In addition to the core Superpowers workflow (brainstorming, planning, TDD, subagent-driven development), GGCoder adds:

- **5 Specialized Reviewers** - Domain-specific code review for GridGain/Ignite
- **6 Automated Fixers** - Apply fixes using patterns from 100+ real PRs
- **9 Pattern Skills** - Concurrency, resource cleanup, async, testing patterns
- **Layered Review** - GridGain reviewers run first, then architecture review

### GridGain Reviewers

| Reviewer | Focus |
|----------|-------|
| `gg-safety-reviewer` | Concurrency, resource leaks, null safety, type safety |
| `gg-quality-reviewer` | Dead code, duplication, logging, style |
| `gg-testing-reviewer` | Coverage gaps, assertions, flakiness |
| `gg-cpp-reviewer` | C++ headers, ownership, shell scripts |
| `gg-build-reviewer` | Dependencies, API consistency |

### How Layered Review Works

When you use `ggcoder:subagent-driven-development` or `ggcoder:requesting-code-review`:

```
Pass 1: GridGain Domain Reviewers (Parallel)
├── .java/.cs files → gg-safety + gg-quality + gg-testing
├── .cpp/.h files   → gg-cpp
└── build.gradle    → gg-build

Pass 2: Architecture Review
└── code-reviewer (plan alignment, design patterns)
```

## How it works

It starts from the moment you fire up your coding agent. As soon as it sees that you're building something, it *doesn't* just jump into trying to write code. Instead, it steps back and asks you what you're really trying to do.

Once it's teased a spec out of the conversation, it shows it to you in chunks short enough to actually read and digest.

After you've signed off on the design, your agent puts together an implementation plan that's clear enough for an enthusiastic junior engineer with poor taste, no judgement, no project context, and an aversion to testing to follow. It emphasizes true red/green TDD, YAGNI (You Aren't Gonna Need It), and DRY.

Next up, once you say "go", it launches a *subagent-driven-development* process, having agents work through each engineering task, inspecting and reviewing their work, and continuing forward. It's not uncommon for Claude to be able to work autonomously for a couple hours at a time without deviating from the plan you put together.

There's a bunch more to it, but that's the core of the system. And because the skills trigger automatically, you don't need to do anything special.

## Credits

GGCoder is built on top of [Superpowers](https://github.com/obra/superpowers) by Jesse Vincent. If you find this useful, consider [sponsoring his opensource work](https://github.com/sponsors/obra).

## Installation

### Claude Code (via Plugin Marketplace)

In Claude Code, register the marketplace first:

```bash
/plugin marketplace add tapnetix/ggcoder
```

Then install the plugin:

```bash
/plugin install ggcoder@ggcoder-marketplace
```

### Verify Installation

Start a new session and ask Claude to help with something that would trigger a skill (e.g., "help me plan this feature" or "let's debug this issue"). Claude should automatically invoke the relevant ggcoder skill.

### Codex

Tell Codex:

```
Fetch and follow instructions from https://raw.githubusercontent.com/tapnetix/ggcoder/refs/heads/main/.codex/INSTALL.md
```

**Detailed docs:** [docs/README.codex.md](docs/README.codex.md)

### OpenCode

Tell OpenCode:

```
Fetch and follow instructions from https://raw.githubusercontent.com/tapnetix/ggcoder/refs/heads/main/.opencode/INSTALL.md
```

**Detailed docs:** [docs/README.opencode.md](docs/README.opencode.md)

## The Basic Workflow

1. **brainstorming** - Activates before writing code. Refines rough ideas through questions, explores alternatives, presents design in sections for validation. Saves design document.

2. **using-git-worktrees** - Activates after design approval. Creates isolated workspace on new branch, runs project setup, verifies clean test baseline.

3. **writing-plans** - Activates with approved design. Breaks work into bite-sized tasks (2-5 minutes each). Every task has exact file paths, complete code, verification steps.

4. **subagent-driven-development** or **executing-plans** - Activates with plan. Dispatches fresh subagent per task with two-stage review (spec compliance, then code quality), or executes in batches with human checkpoints.

5. **test-driven-development** - Activates during implementation. Enforces RED-GREEN-REFACTOR: write failing test, watch it fail, write minimal code, watch it pass, commit. Deletes code written before tests.

6. **requesting-code-review** - Activates between tasks. Reviews against plan, reports issues by severity. Critical issues block progress.

7. **finishing-a-development-branch** - Activates when tasks complete. Verifies tests, presents options (merge/PR/keep/discard), cleans up worktree.

**The agent checks for relevant skills before any task.** Mandatory workflows, not suggestions.

## What's Inside

### Skills Library (23 Total)

**Testing**
- **test-driven-development** - RED-GREEN-REFACTOR cycle (includes testing anti-patterns reference)

**Debugging**
- **systematic-debugging** - 4-phase root cause process (includes root-cause-tracing, defense-in-depth, condition-based-waiting techniques)
- **verification-before-completion** - Ensure it's actually fixed

**Collaboration**
- **brainstorming** - Socratic design refinement
- **writing-plans** - Detailed implementation plans
- **executing-plans** - Batch execution with checkpoints
- **dispatching-parallel-agents** - Concurrent subagent workflows
- **requesting-code-review** - Layered review with GridGain reviewers + architecture check
- **receiving-code-review** - Responding to feedback
- **using-git-worktrees** - Parallel development branches
- **finishing-a-development-branch** - Merge/PR decision workflow
- **subagent-driven-development** - Fast iteration with two-stage review (spec compliance, then code quality)

**GridGain/Ignite Patterns**
- **concurrency-patterns** - Double-checked locking, private locks, volatile flags
- **resource-cleanup-patterns** - Idempotent close, async cleanup, early release
- **null-check-patterns** - Objects.requireNonNull, @Nullable annotations
- **async-patterns** - CompletableFuture chaining, Channels, cancellation
- **test-patterns** - Hamcrest matchers, Awaitility, distributed test data
- **performance-patterns** - Benchmarking, fast paths, executor optimization
- **version-compatibility-patterns** - Protocol feature flags, version checks
- **security-context-patterns** - SecurityContextHolder, credentials handling
- **review-pr** - Orchestrates layered review process

**Meta**
- **writing-skills** - Create new skills following best practices (includes testing methodology)
- **using-ggcoder** - Introduction to the skills system

### Agents (12 Total)

**GridGain Reviewers (5)**
- `gg-safety-reviewer` - Concurrency, resources, null safety, type safety
- `gg-quality-reviewer` - Dead code, duplication, style
- `gg-testing-reviewer` - Coverage, assertions, flakiness
- `gg-cpp-reviewer` - C++/CMake/shell issues
- `gg-build-reviewer` - Dependencies, API consistency

**GridGain Fixers (6)**
- `gg-safety-fixer` - Applies concurrency/resource/null fixes with TDD
- `gg-quality-fixer` - Removes dead code, extracts constants
- `gg-test-fixer` - Adds coverage, converts to Hamcrest
- `gg-doc-fixer` - Fixes typos, Javadoc
- `gg-cpp-fixer` - Adds includes, move semantics
- `gg-build-fixer` - Fixes BOM versions, adds READMEs

**General**
- `code-reviewer` - Plan alignment, architecture review

### Commands

- `/review` - Run layered code review (GridGain + architecture)
- `/fix <category>` - Apply fixes (safety, quality, tests, docs, cpp, build)

## Philosophy

- **Test-Driven Development** - Write tests first, always
- **Systematic over ad-hoc** - Process over guessing
- **Complexity reduction** - Simplicity as primary goal
- **Evidence over claims** - Verify before declaring success

Read more: [Superpowers for Claude Code](https://blog.fsck.com/2025/10/09/superpowers/)

## Contributing

Skills live directly in this repository. To contribute:

1. Fork the repository
2. Create a branch for your skill
3. Follow the `writing-skills` skill for creating and testing new skills
4. Submit a PR

See `skills/writing-skills/SKILL.md` for the complete guide.

## Updating

Skills update automatically when you update the plugin:

```bash
/plugin update ggcoder@ggcoder-marketplace
```

## License

MIT License - see LICENSE file for details

## Support

- **Issues**: https://github.com/tapnetix/ggcoder/issues
- **Original Superpowers**: https://github.com/obra/superpowers
