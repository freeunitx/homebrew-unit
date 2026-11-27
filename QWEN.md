# QWEN.md — freeunitorg/homebrew-unit

## Repository

**URL:** https://github.com/freeunitorg/homebrew-unit
**Fork (push target):** https://github.com/freeunitx/homebrew-unit
**Current release:** 1.37.2

## Accounts

| Account | Push to freeunitorg/* | Notes |
|---------|----------------------|-------|
| `freeunitx` | No — 403 read-only | Push goes to freeunitx fork. Then open PR to upstream. |
| `phpclub` | Yes — admin | Do NOT use. User instruction dated 2026-11-21. |

## Workflow

1. Create a `fix/…` branch from `origin/master`.
2. Commit changes locally.
3. Push branch to `freeunitx/homebrew-unit`.
4. Open PR: `freeunitx/<branch>` to `freeunitorg/master`.
5. CI runs automatically on PR open and on every push.

## GitHub CLI (`gh`)

Run all commands from the repo root.

### Authenticate

```bash
gh auth status   # Verify the active account.
gh auth login    # First-time setup.
```

### Pull requests

```bash
gh pr list                      # List open PRs for the current repo.
gh pr view <N>                  # Show PR details.
gh pr diff <N>                  # Show PR diff.
gh pr close <N>                 # Close PR. No upstream write needed.
gh pr reopen <N>                # Reopen PR. Retriggers all workflows.
gh pr comment <N> --body "..."  # Post a comment on the PR.
```

`gh pr merge --admin` needs write access to the upstream repo. The `freeunitx` account has none, so the upstream maintainer merges the PR.

### PR status and checks

```bash
# Every check of a PR, with the conclusion of each one.
gh pr checks <N> --repo freeunitorg/homebrew-unit

# The merge state and every check in one call.
gh pr view <N> --repo freeunitorg/homebrew-unit \
  --json mergeStateStatus,statusCheckRollup

# The checks of one commit, without the PR.
gh api repos/freeunitorg/homebrew-unit/commits/<sha>/check-runs \
  --jq '.check_runs[] | "\(.conclusion)\t\(.name)"'
```

`gh pr checks` exits with code 1 when a check fails. This exit code reports the failure. The command itself does not fail.

`gh run list` has no `--pull-request` flag. Filter by commit instead.

```bash
gh run list --repo freeunitorg/homebrew-unit --commit <sha> \
  --json status,conclusion,workflowName,url
```

### CI logs

```bash
# The log of one job. This works when gh run view --log-failed returns nothing.
gh api repos/freeunitorg/homebrew-unit/actions/jobs/<job_id>/logs

# The job id of one check.
gh api repos/freeunitorg/homebrew-unit/commits/<sha>/check-runs \
  --jq '.check_runs[] | select(.name | test("php-embed")) | .details_url'
```

`gh run rerun` needs write access to the upstream repo. The `freeunitx` account has none. Use close and reopen instead. That retriggers CI without upstream write.

```bash
gh pr close <N> && gh pr reopen <N>
```

### Push (freeunitx fork target)

```bash
git push origin HEAD:<branch-name>   # Push a feature branch.
```

### CI in the fork (no upstream write needed)

A pull request that goes from the fork to the upstream runs in the upstream repo.
The Actions page of the fork stays empty. To watch the checks in the fork, open
the pull request inside the fork: `freeunitx:<branch>` to `freeunitx/master`.

The fork also has a `Rebuild everything` workflow with `workflow_dispatch`.
It runs `brew test-bot --only-tap-syntax` and then builds every formula on
ubuntu-24.04, macos-15, and macos-26. The `freeunitx` account can start it.

```bash
gh workflow list --repo freeunitx/homebrew-unit
gh workflow run "Rebuild everything" --repo freeunitx/homebrew-unit
gh run list --repo freeunitx/homebrew-unit
```

The workflow runs the code of the default branch of the fork.

## Homebrew style

Run before every push.

```bash
brew test-bot --only-tap-syntax
```

Enforced rules:

- `post_install` becomes `post_install_steps` in formulae.
- `assert_predicate f, :exist?` becomes `assert_path_exists f`.
- Remove redundant string interpolation.
- Replace complex ternary with if-else-end.
- Use `formula_opt_bin`, `formula_opt_include`, `formula_opt_lib` instead of `Formula["name"].opt_bin`.
- Keep the formula component order: `livecheck` and `head` go above `keg_only`.
- Do not hard-code paths.

## Local checks

Run the checks in a container. The container holds Homebrew on Linux. It runs
the same checks as the CI job `check-generate`. The full run takes about 20
seconds. A CI cycle takes about 7 minutes.

Build the image once:

```bash
docker build -t homebrew-unit-test test/
```

Run the checks from the repository root:

```bash
docker run --rm -v "$PWD:/mnt/homebrew-unit:ro" homebrew-unit-test
```

Add `--eol` to also check the EOL data against the live Homebrew API:

```bash
docker run --rm -v "$PWD:/mnt/homebrew-unit:ro" homebrew-unit-test --eol
```

Add `--inreplace` to check the inreplace patterns of the php embed formulae
against the configure script of the PHP source:

```bash
docker run --rm -v "$PWD:/mnt/homebrew-unit:ro" homebrew-unit-test --inreplace
```

Add `--patch` to check the patches of the php embed formulae against the PHP
source:

```bash
docker run --rm -v "$PWD:/mnt/homebrew-unit:ro" homebrew-unit-test --patch
```

Add `--build <formula>` to build a formula and to run its audit, the way the
CI job does it:

```bash
docker run --rm -v "$PWD:/mnt/homebrew-unit:ro" homebrew-unit-test --build php-embed@8.3
```

The component order check needs only Python 3. It needs no Docker:

```bash
python3 test/check-components-order.py Formula
```

The inreplace check needs only Python 3. It needs no Docker:

```bash
python3 test/check-inreplace-patterns.py
```

The patch check needs only Python 3 and the program `patch`. It needs no Docker:

```bash
python3 test/check-patches.py
```

Read `test/README.md` for the details.

Do not install Homebrew on the host machine. Use the container.

## PHP versions

PHP changed the quoting of the APXS lines in the `configure` script between
the series 8.3 and 8.4. The series 8.3 uses backticks, the later series use
the `$()` form. Every php embed formula needs the patterns of its own series.

Check the patterns after every change of a php embed formula:

```bash
python3 test/check-inreplace-patterns.py
```

## Version and EOL check

The `eol/` directory holds the EOL state of every package. Read `eol/README.md` before you change a dependency.

```bash
python3 eol/check.py            # Print the report. Change nothing.
python3 eol/check.py --write    # Update eol/eol.json.
python3 eol/check.py --check    # Exit 1 if eol.json is stale.
```

The script also checks the PHP version coherence. Every php formula must depend on the homebrew-core php formula of the same series.

```bash
python3 eol/check.py --check
```

## PHP versioning

The tap ships one formula per supported PHP series: `php-embed`, `php-embed@8.5`, `php-embed@8.4`, `php-embed@8.3`, and one `unit-php` module per series.

Rules:

- A php-embed formula must build the PHP version of its own series.
- A versioned php-embed formula must depend on `php@<series>` of the same series.
- The unversioned php-embed formula builds the newest series. It depends on the unversioned `php` formula of homebrew-core, because that formula holds the newest series. homebrew-core adds a versioned formula for the series when it ships the next one.
- A unit-php module must depend on `php-embed@<series>` of the same series.
- A unit-php module must link the library of that series with `--lib-path`.
- The module of the newest series is the unversioned `unit-php` formula with the module name `php`. The module names of the versioned formulae are `php85`, `php84`, and `php83`.

The php module reads `php-config` from `PATH`. The pin keeps the module headers and the embed library on the same PHP version.

The FreeUnit source comes from the `1.37` branch. The branch carries the PHP 8.6 support and the 1.37.3 release. The `revision` field of the formula pins the commit.

The php embed formulae build PHP against OpenSSL 3.x, like the php images of the FreeUnit project. The `openssl@3` formula is keg-only, so the build points `PKG_CONFIG_PATH` at it.

The whole stack must use one OpenSSL version. The `openssl` formula of homebrew-core is the version 4, so the formulae of the server use the paths of `openssl@3` explicitly. Never use `formula_opt_include("openssl")` in a formula of this tap.

The `curl` formula of homebrew-core is bound to OpenSSL 4. The php embed formulae build the curl extension on macOS only. The library of the system is used there. On Linux the extension is not built, because a process with two OpenSSL versions is not safe. The core `php` formulae of homebrew-core use the curl of the core and OpenSSL 4 together.

Check the patches after every change of a php embed formula. The program `patch` of macOS refuses a patch with the context lines of the wrong series, and the program of Linux applies it with the fuzz.

```bash
python3 test/check-patches.py
```

## Commit convention

Use Conventional Commits.
The token is English.
The body is English or simple-russian (УТР) as context requires.

Use `/caveman-commit` to generate a ready-to-paste message.
