# Working defaults

Sourced from [mchelen/dotfiles-ai](https://github.com/mchelen/dotfiles-ai)
(`INSTRUCTIONS.md`), one module per `#` heading. These 12 of its 16 modules
apply to this project; Code style, Honest reporting, Propose before building,
and Specification were deliberately left out.

Edit these defaults in `defaults/` in the dotfiles-ai fork, not here.

One further module, **Diagnose before fixing**, is local to this project and
is not from dotfiles-ai. It lives at the bottom of this file.

---

# Architecture documentation

**Every project keeps an `ARCHITECTURE.md`, updated in the same change that
rewires a component.**

- Every project keeps an `ARCHITECTURE.md` at the repo root: a high-level
  description of the code — major components, how they fit together, and key
  data flows — including Mermaid diagrams for structure and flows.
- Keep it current: when a change adds, removes, or rewires a component,
  update `ARCHITECTURE.md` in the same change. If it doesn't exist yet,
  create it as part of the first substantial change.
- Stay high level: components and boundaries, not function-by-function
  detail. If the diagram needs updating for small edits, it's too detailed.

# Changelog

**Every project keeps a `CHANGELOG.md`, written for readers rather than
generated from the log.**

- Follow [Keep a Changelog](https://keepachangelog.com). Newest first, an
  `## [Unreleased]` section at the top, and released sections headed
  `## [version] - YYYY-MM-DD`. A project with no versions dates its sections
  instead — the date is the part readers navigate by.
- Group entries by kind: **Added**, **Changed**, **Fixed**, **Removed**, plus
  the format's deprecation and security categories where they apply.
- **Write it for the reader, not from the history.** A commit log answers
  "what changed in the code"; a changelog answers "what changed for me". Most
  commits produce no entry, and one entry often covers several commits.
- Update it in the same change that earns the entry. Written a month later
  from the log, it is a reconstruction — and the details worth recording are
  the ones already forgotten.
- Skip anything invisible from outside: refactors, test additions, formatting.
  If it changed nothing for anyone using the project, it belongs in the
  history and nowhere else.
- Record removals and breaking changes most carefully of all. Those are the
  entries people go looking for, usually after something stopped working.
- **Publish it where the users are**, not only in the repo. If the project has
  a website, the changelog belongs on it — a file in a source tree is not
  where someone checks what changed.

# Cheap git and forge queries

**Ask git and the forge for the smallest thing that answers the question.**

*Tool-agnostic in principle. `minimal_output` is the GitHub MCP server's flag;
elsewhere it's whatever narrows the response at the source.*

History and pull-request APIs return far more than was asked for by default,
and one unbounded response can cost a meaningful share of the context window.
This is the git-shaped half of the compute-offload module.

- **Narrow at the source.** `--stat`, `--name-only`, `--oneline`, `-n`,
  `--no-patch` — reach for these before printing something large and reading
  past most of it. `git log --oneline -10` answers "what happened lately";
  `git log -p` answers the same question at many times the cost.
- **Turn off the pager** (`--no-pager`, or `GIT_PAGER=cat`) so output arrives
  whole instead of a screen at a time.
- **Ask forge tooling for the smallest useful response**: set `minimal_output`
  where the tool supports it, page in small batches, and use server-side
  filters instead of fetching everything and filtering afterwards.
- **Don't pull a large payload to read one field.** When polling something like
  a workflow or check status, request only that status; if a response comes
  back huge anyway, save it and query the field out of the file rather than
  re-fetching.
- **Prefer a scheduled re-check to a tight polling loop** when waiting on CI or
  a deployment.
- **Narrowing is for navigation, not for judgment.** Reviewing a change means
  reading the diff. Use these to find your way to it, not to avoid it.

# Pull requests and a CI-gated `main`

**Changes reach `main` only through a pull request with a green check.**

*The working half is tool-agnostic. The protection half is GitHub-specific in
mechanism — the rule, no unreviewed or untested code on the default branch,
carries to any forge — and needs admin rights, so it's a one-time human step.*

## Working this way

- Once work on a branch is complete and pushed, open a pull request by
  default — no need to ask first.
- After opening it, keep watching it if the tooling allows: respond to review
  comments and fix CI failures until it's merged or closed. A pull request you
  opened and stopped watching is unfinished work, not delivered work.
- Merge by default once automated checks pass and any required reviews are
  approved — no need to ask first.
- Don't merge over failing checks, missing required approvals, or unresolved
  discussions. A red check is an answer, not an obstacle.
- When a check is red for a reason the change didn't cause — a flaky test, a
  failure that reproduces on the base branch — say that in the pull request
  and merge once it recovers, rather than quietly merging past it.
- Squash-merging is fine even though it collapses the branch: `main` is meant
  to carry one commit per change, which is the unit `revert` and `bisect` work
  on, and the commit-by-commit story stays readable in the pull request. That
  is a reason to keep the branch's story clean, not a reason to stop telling
  one — reviewers read it commit by commit.

## Protecting the branch

The rules above are what I want you to do. Branch protection is what the
repository does when nobody is doing it — including when the actor is a script.

- **Protect the default branch.** No direct pushes, no force-pushes, no
  deletion. Changes reach `main` through a pull request.
- **Require at least one status check**, and require it to *pass* — a check
  that runs but isn't required is a suggestion. Include administrators in the
  rule: a gate you can walk around is a gate for other people.
- **The check does real work, honestly.** Install dependencies, build the
  project if it has a build, run the tests if it has tests. Where there is
  neither, the check should say so in its output and pass — not print a green
  tick that means nothing. A check that always passes is worse than no check,
  because it looks like coverage.
- Keep it fast enough that nobody wants to bypass it. If the full suite is
  slow, gate on the fast subset and run the rest after merge.
- **Configure it as code**, through whatever mechanism the repo already uses
  for settings (see the repo-config module) — not by clicking through branch
  protection screens.

## Automation that pushes to `main`

Branch protection blocks bots too. Before enabling it, look for workflows that
commit or push to the default branch — a docs generator, a formatter, a
version bumper — because they will start failing.

Resolve it deliberately, and say which you chose:

- Give that one workflow a documented bypass, narrowest possible; or
- Convert it to open a pull request instead of pushing.

Preferring the second is usually right: it keeps the gate absolute, and the
bot's output gets the same review as anyone else's.

## Setting it up for the first time

Branch protection needs admin rights, so it is a one-time human step. Write out
what to do rather than stalling or assuming, in the same shape the repo-config
module describes: which rule to add, which check to mark required, whether
administrators are included, and what happens to any existing bot pushes.

Then confirm it took effect — read the protection back, or open a throwaway
pull request and check that merge is blocked until the check reports. An
unenforced rule and an enforced one look identical from the settings page.

# Commit and branch conventions

**Nothing is committed or pushed unless I ask; each commit is one logical
change, conventionally named.**

- Never commit or push unless I ask (or I've clearly set up a workflow where
  it's expected). This governs *whether* to commit; the rest of this module
  governs *how* the work is carved up once I've asked.
- Commit in atomic units: one logical change each — one feature, one fix, one
  refactor, one documentation update — so every commit is independently
  revertable and describable in a single line. Don't bundle unrelated changes,
  and don't dump a whole session into one commit called "updates".
- Write the message as a conventional prefix plus an imperative summary, with
  the reasoning in the body when it isn't obvious from the diff. Prefixes:
  `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `style:`, `perf:`, `chore:`.
- Name branches the same way: a type prefix, then a short hyphenated
  description — `fix/marker-trailing-space`, `docs/install-guide`. It should
  still say what it is a month later, read in a list of twenty. If the repo
  already has a convention, follow that one instead of introducing a second.
- Don't commit code that doesn't build, tests that fail (unless a failing test
  is deliberately the point), leftover debugging, or unrelated changes mixed
  together.
- Never commit secrets, `.env` files, or credentials — flag it if you see them
  staged. The scanning layers that back this up are in the secrets module.

## Rewriting history

- Reshaping history on a feature branch is fine and needs no confirmation,
  before or after pushing it: squash the fixups, reorder, reword, split a "wip"
  into the commits it should have been, and force-push the result. Until it
  merges, the branch is yours. `git log origin/main..HEAD` shows what's in
  scope.
- **`main` is the line.** Never rewrite history there — no force-push, no
  rebase, no amending a merged commit — without explicit confirmation. The same
  restraint applies to any branch someone else has started work from, which is
  the reason the rule exists.

# Offloading mechanical work

**Mechanical work belongs in a command, not in your context.**

*Tool-agnostic. The MCP examples assume an assistant with MCP servers attached, which by 2026 includes Claude Code, Cursor, Copilot and Windsurf among others, but the principle holds with any tooling.*

When a shell
command, script, or CI job produces the same answer, run it instead of loading
the material and working it out yourself — it's cheaper, it's reproducible, and
it leaves context for the parts that actually need thought.

- **Query, don't read.** Search, filter, count, and compare with the tools built
  for it — `grep`, `jq`, `diff`, `wc` — rather than reading a large file or a
  large command output to find a small part of it.
- **Ask for the answer, not the transcript.** Prefer flags that narrow at the
  source (`--json` with a filter, `--stat`, `--name-only`, `-o`, `-q`) over
  printing everything and picking through it.
- **Make checks self-reporting.** A verification script should print a verdict —
  expected versus actual — not output for me to eyeball.
- **Batch.** Independent commands go in one call, not one round trip each.
- **If it has to hold every time, put it in CI.** A check you would otherwise
  repeat by hand every session belongs in a workflow.

Don't offload when it costs correctness:

- **Judgment doesn't offload.** Reviewing code, weighing an approach, deciding
  whether wording is right — a command can find candidates, it can't decide.
  Read the code you are reasoning about.
- **Don't write a fragile parser to avoid a short read.** If getting the script
  right is harder than reading the thing, read the thing.
- **Don't trust output you can't sanity-check.** A clever one-liner whose result
  you have no way to verify is worse than the slow, obvious path.
- **Keep the evidence that matters.** When something fails I want the actual
  failure output, not a summarized verdict.
- **Never quietly sample.** If you filtered, truncated, or checked only part of
  something, say so. A partial check reported as a complete one is worse than
  no check at all.

# Decision handoffs

**End every response with the decision I need to make, and keep building when
there isn't one.**

## Ending a response

- Close with the input you actually need: the specific decision, the options,
  and what each one buys and costs. "Let me know what you think" is not a
  handoff — it hands back the work of figuring out what the question was.
- Make the options real. Two choices where one is obviously wrong is a
  recommendation wearing a costume; say it's a recommendation instead.
- Recommend one, and say why. A menu with no recommendation pushes the
  judgment back to me, which is usually the part you're better placed to do
  after an hour inside the problem.
- One decision at a time where you can. If several are open, rank them and say
  which one blocks the others.
- If there's nothing to decide, say that too, and say what you're doing next.
  Silence about next steps reads as finished.

## When no decision is needed

- Keep going. Don't stall on input nobody asked to give.
- Prefer building the thing to describing it. A mockup, a proof of concept, or
  a spike I can look at answers a question that three paragraphs of
  speculation only restates.
- Speculative or optional work goes on its own branch, so it can be judged on
  its merits and dropped at no cost. Name the branch and say what it
  demonstrates.
- This is how `propose-before-building` gets satisfied rather than
  contradicted: a concrete artifact **is** the proposal. Building something
  disposable to show me is not the same as implementing without a yes — the
  difference is whether it's cheap to throw away.

## When something needs real review

- Compile it as a static artifact — a committed markdown document, a page, a
  decision record — not a long chat message. Chat scrolls away; an artifact
  can be re-read, linked, diffed, and revised.
- Carry the context with it: the problem, what was tried, the constraints,
  what was measured, what's still unknown. Assume I've forgotten the details
  and am reading it cold a week later.
- Name at the top the decision the artifact exists to support. A document that
  doesn't say what it's for gets read as background and filed.
- Meta commentary is welcome and usually the most useful part: what you're
  unsure about, where you had to guess, what you'd look at first if it were
  your call, and what would change your mind.

# Project website

**Most projects get a static site, with anything simulated on it labelled as
simulated.**

*Any static host works. GitHub Pages is the default assumed here because the rest of these defaults already assume GitHub.*

- Most projects should have a static website (GitHub Pages or similar)
  covering: what the project is, why it exists, and how to use it.
- Show the project in action. Where real screenshots or live demos aren't
  practical, simulate them — rendered terminal sessions, mocked UI states,
  example output — and label simulated content as such.
- Include a before/after demo showing what the project actually changes:
  the same scenario with and without it, side by side.
- Give install steps for every environment where they differ (local CLI,
  cloud/web, IDE, settings-UI-only tools), not just the common case —
  and say *why* a variant differs, so the reader can generalize.
- Keep the site in the repo (e.g. a `docs/` folder) so it versions with
  the code, and update it alongside user-facing changes.
- Publish via the GitHub Actions Pages path by default: Pages source set
  to "GitHub Actions", with a workflow using `actions/configure-pages`,
  `actions/upload-pages-artifact`, and `actions/deploy-pages` — not the
  legacy deploy-from-branch mode.
- Plain static HTML/CSS is fine; don't introduce a site generator or
  framework unless the project already has one or genuinely needs it.
- Skip the site for internal scratch work, private utilities, or projects
  too small for it to add anything — and ask before publishing anything
  publicly for the first time.

# Repo configuration as code

**Repository settings live in the repo as code, never clicked through the
UI.**

*GitHub-specific. The principle — settings as code, applied automatically,
never clicked — carries to any forge; both implementations below are GitHub's.*

Settings that belong in code: description and homepage, feature toggles, merge
policy, Pages, vulnerability alerts, secret scanning and push protection, and
branch protection rules once they exist. When one must change, change the file
and let it apply — don't flip it in the UI and leave the code lying. If a UI
change already happened, reconcile the code to match (or revert) promptly.

Two implementations, and the trade between them is simple: **Terraform is more
powerful, the Settings app is easier to set up.** Start with the app, and move
to Terraform when you need something it cannot reach — the list below says
exactly where that line falls.

## The Settings GitHub App (default — least to set up)

- [`repository-settings/app`](https://github.com/repository-settings/app),
  hosted at `github.com/apps/settings`. Config lives in
  `.github/settings.yml` and syncs when pushed to the default branch.
- Sections are `repository`, `teams`, `collaborators`, `branches`,
  `environments`, `labels`, `milestones` — all optional. The `repository`
  section takes: `name`, `description`, `homepage`, `topics`, `private`,
  `has_issues`, `has_projects`, `has_wiki`, `has_downloads`,
  `default_branch`, `allow_squash_merge`, `allow_merge_commit`,
  `allow_rebase_merge`, `delete_branch_on_merge`,
  `enable_automated_security_fixes`, `enable_vulnerability_alerts`.
- No PAT to mint or rotate, no state, no workflow to maintain, and settings
  changes arrive as reviewable pull requests like any other diff.
- **Know what it can't reach.** That key list is the whole of it. Pages
  configuration, secret scanning, and secret scanning push protection have no
  keys — a repo that needs those managed as code needs Terraform for them,
  and a repo where they're set by hand has settings-as-documentation for
  exactly the three that matter most.
- **Know the trade you're making on access.** The app's own documentation
  warns that it "inherently escalates anyone with `push` permissions to the
  **admin** role", because pushing config to the default branch is enough to
  change settings. Mitigate it the way the docs prescribe: make an admin the
  `CODEOWNERS` owner of `.github/settings.yml` and require code-owner review.
  If that mitigation isn't in place, prefer Terraform.

## Terraform (when you need more than the app can reach)

The whole GitHub provider surface, at the cost of a PAT to mint and rotate and
a workflow to maintain. Reach for it when the repo needs Pages, secret
scanning, or push protection managed as code, or when the push-to-admin
escalation isn't acceptable and `CODEOWNERS` isn't enough.

- Official GitHub provider (`integrations/github`) with an `import` block to
  adopt the existing repo. Config lives in `infra/`.
- Apply in CI on merge to `main`, stateless: re-import, reconcile, discard
  state. No backend to run.
- The built-in Actions `GITHUB_TOKEN` cannot administer repo settings, so this
  needs a fine-grained PAT (Administration only, this repo only) as an Actions
  secret — and the workflow should skip with a notice when it's absent rather
  than failing.
- Never commit state, `*.tfvars`, or tokens.

Running both on one repo is a mistake unless the key sets are disjoint and the
split is written down. Two systems reconciling the same setting against
different sources means the last one to run wins, silently.

## Setting this up on a repo for the first time

Both options need a one-time human step that an assistant cannot do:
installing a GitHub App, or creating a PAT. Don't stall silently on it and
don't pretend it's done — **write out the exact steps and say what you'll do
once it's finished.**

- **Settings app:** install `github.com/apps/settings` on the repo or org and
  grant it access to that repo, then say that the next push of
  `.github/settings.yml` to the default branch will apply. Mention the
  CODEOWNERS mitigation in the same breath, not later.
- **Terraform:** create a fine-grained PAT scoped to that repo with
  Administration read & write, save it as the `REPO_ADMIN_TOKEN` Actions
  secret, then say which workflow will pick it up. Name any additional
  permission the config needs — Pages settings need their own.

Then check it actually worked: read the settings back and compare against the
file. A workflow that skipped, a token missing a scope, or an app without
access all look identical to success from the outside — which is how a repo
ends up with settings-as-documentation instead of settings-as-code.

Check it again on a schedule, not only when the config changes. Applying on
change means the config is true at the moment it is edited and unverified
after that; a weekly run that compares and reports — without applying — is
what turns "we declared this" into "this is the case". Let drift fail the
run: a failing scheduled job is the notification, and a green one that found
problems quietly is the thing being guarded against.

## Org-owned repos

Prefer the org's existing mechanism if there is one — `safe-settings`, an infra
monorepo, whatever it already runs — over introducing a second, per-repo way of
doing the same thing.

# Secrets and sensitive data

**Secrets are stopped by three independent layers, and a failing check is never
quietly disabled.**

*The scanning layers are tool-agnostic; push protection is GitHub's. On another forge, keep the first two and find the third's equivalent.*

- Every repo gets a pre-commit hook that scans staged changes for
  credentials, key material, and PII before they can be committed. Use
  standard tooling — the pre-commit framework with the official gitleaks
  hook (extra rules via `.gitleaks.toml` `[extend]`) — not hand-rolled
  scanners. Set it up as part of the first substantial change.
- Layer the defenses; don't rely on any single one:
  - **pre-commit** — catches secrets before they enter history
  - **CI** — a secret scanner (e.g. the gitleaks action) on every push/PR
  - **platform** — GitHub secret scanning with push protection enabled in
    repo or org settings
- Never weaken or bypass these checks (`--no-verify`, editing patterns)
  without flagging it to me explicitly first.
- A false positive gets an explicit inline allow-marker, not a disabled
  check.
- If a real secret ever reaches history — even briefly, even in a private
  repo — treat it as compromised: rotate it and say so. Deleting the file
  or force-pushing does not un-leak it.

# Testing

**Start from a failing test, write the code that makes it pass, and show me
both runs.**

- Write tests **before** implementation by default: start from a failing test
  that captures the expected behavior, then write the code to make it pass.
- Show me the failing test run before the fix and the passing run after —
  that's the evidence the test actually exercises the change.
- When fixing a bug, first add a test that reproduces it.
- Test behavior, not implementation details; don't write tests that just
  mirror the code's internals or mock everything into meaninglessness.
- Use the project's existing test framework and conventions. If the project
  has no test setup at all, propose one before introducing it.

Skip test-first when:

- It's a throwaway spike, mockup, or exploration (per the feature workflow)
- The change isn't meaningfully testable (docs, comments, formatting, config)
- I've explicitly said to skip tests

# Tool fallbacks

**When an interactive tool looks stuck, switch to plain text instead of
retrying it.**

*Applies to any assistant that asks through interactive prompts. The linked bug is Claude Code's; the failure mode — a mechanism that loses input being used to ask again — is not.*

- If an interactive tool looks stuck — the same prompt keeps reappearing, a
  response never arrives, or I say I answered something you never received —
  stop using that tool and continue in plain text. Say that you're switching
  and why.
- A rejection is not always a refusal. If a tool reports that I declined but I
  say I answered, treat it as lost input rather than a decision, and re-ask in
  plain text.
- Never re-ask through a mechanism that just failed. Two failures of the same
  kind mean change approach, not retry — retrying is what turns one lost
  answer into a loop.
- Known issue behind this rule: dismissing an `AskUserQuestion` card silently
  discards typed free text, and a resolved card can keep re-rendering on
  mobile until the app restarts —
  <https://github.com/anthropics/claude-code/issues/81223>. If either happens,
  fall back to plain text and suggest restarting the app.
- This applies to any tool, not just question prompts: when something fails
  repeatedly, use the simplest thing that works — plain text, a file, a shell
  command — and tell me what you fell back to.
- When a tool failure may have destroyed something I typed, say so explicitly
  instead of quietly proceeding on a guess.

---

# Diagnose before fixing

*Project-local, not from dotfiles-ai. Written after a session that shipped
three "fixes" for one bug, two of which fixed nothing.*

**Don't change code to fix a bug you haven't reproduced and explained.**

- **Reproduce it first.** A theory that fits the symptom is not a diagnosis.
  Until you have made the bug happen on demand, every change is a guess wearing
  a fix's clothing.
- **Prove the fix with a negative control.** Show the check failing without the
  change and passing with it. If it passes both ways, you have not demonstrated
  anything — and a test that cannot fail is worse than no test, because it
  looks like coverage.
- **Remove a fix that fixed nothing.** When the negative control shows the code
  was never the cause, take it out. Keeping it "just in case", with a comment
  claiming it solved something, puts a lie in the codebase.
- **Reproduce in the real target when the harness can't.** Headless tests drive
  the system differently from the way a user does, and some bugs only exist in
  that difference. If no test reproduces it, get the evidence where the bug
  actually lives — a real browser, the real device — and say plainly in the
  code that the guard is unverifiable by the test suite, so nobody deletes it
  as dead.
- **Never bundle speculative changes with a real fix.** Retuning things that
  looked wrong along the way makes the change set impossible to judge, and
  hides the one edit that mattered among several that did not. Fix the
  diagnosed cause; propose the rest separately.
- **Say which explanation was wrong.** When a first or second theory fails,
  state it. A confident wrong diagnosis quietly retracted is how a codebase
  accumulates cargo-cult code.
