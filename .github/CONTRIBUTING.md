# Contributing to homebrew-unit

## Workflow

1. Fork `freeunitorg/homebrew-unit`.
2. Create a branch from `master`.
3. Make the change.
4. Run the relevant checks.
5. Open a pull request with the change description and check results.

Use a real name and email address in the Git configuration. Use Conventional Commits for commit messages.

## Formula style

Follow the Homebrew style rules and the component order of the existing formulae. Run the checks in the project container. Do not install Homebrew on the host for these checks.

Build the container image once:

```bash
docker build -t homebrew-unit-test test/
```

Run the main checks from the repository root:

```bash
docker run --rm -v "$PWD:/mnt/homebrew-unit:ro" homebrew-unit-test
python3 test/check-components-order.py Formula
```

If you change a PHP embed formula, run these checks too:

```bash
python3 test/check-inreplace-patterns.py
python3 test/check-patches.py
```

Read `test/README.md` for build and audit commands.

## GitHub Actions

Keep the formula build in the existing workflows. Put bottle publication only in `publish-commit-bottles.yml`. Give `packages: write` only to the workflow that publishes packages.

Run Actionlint for workflow changes. Do not use `pull_request_target` to build code from a pull request.

## Reporting errors

Open an issue with the appropriate template:

<https://github.com/freeunitorg/homebrew-unit/issues>

Include the formula, operating system, architecture, commands, and logs. Remove tokens and other secrets from the logs.

## Security reports

Do not open a public issue for a security report. Read [SECURITY.md](SECURITY.md).
