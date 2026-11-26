# Local test environment

This directory holds a container that runs the checks of the tap. Use it to check a formula before you push it.

The container holds Homebrew on Linux. It runs the same checks as the CI job `check-generate`.

## Files

| File | Purpose |
|---|---|
| `Dockerfile` | The image. It holds Homebrew, rubocop, shellcheck, shfmt, and actionlint. |
| `entrypoint.sh` | Copies the working copy into the container. Then it starts the checks. |
| `run-checks.sh` | Runs the checks. |
| `check-components-order.py` | Checks the order of the formula components. |
| `check-inreplace-patterns.py` | Checks the inreplace patterns of the php embed formulae. |

## Requirements

- Docker
- A clone of this repository

## Build the image

Run this command once.

```bash
docker build -t homebrew-unit-test test/
```

## Run the checks

Run this command from the root of the repository.

```bash
docker run --rm -v "$PWD:/mnt/homebrew-unit:ro" homebrew-unit-test
```

The command exits with code 0 when all checks pass. The command exits with code 1 when a check fails.

## What the checks do

The script runs these checks. All of them must pass.

| Check | Purpose |
|---|---|
| `brew style` | Checks the code style of the formulae and the scripts. |
| `brew readall` | Loads every formula. It finds the errors in the formula syntax. |
| `brew audit` | Checks the formulae against the rules of Homebrew. |
| `check-components-order.py` | Checks the order of the formula components. |
| `brew livecheck` | Checks the version detection of every formula. |
| `brew audit --formula` | Checks every formula alone. It needs a network connection. |

The last two checks run for every formula and for every alias. The CI job runs the same commands.

## Check the EOL state

Add the `--eol` flag to check the EOL data of the dependencies. This check reads the Homebrew API. It needs a network connection.

```bash
docker run --rm -v "$PWD:/mnt/homebrew-unit:ro" homebrew-unit-test --eol
```

The check reads `eol/eol.json`. It fails when the file differs from the live data.

## Check the inreplace patterns

Add the `--inreplace` flag to check the inreplace patterns of the php embed formulae. This check downloads the PHP source. It needs a network connection. The first run downloads about 40 MB. The script keeps the archives in the cache of the container.

```bash
docker run --rm -v "$PWD:/mnt/homebrew-unit:ro" homebrew-unit-test --inreplace
```

PHP changed the quoting of the APXS lines between the series 8.3 and 8.4. The series 8.3 uses backticks, the later series use the $() form. A formula with the patterns of the wrong series fails the build with the message `inreplace failed`. This check finds that error without a build.

## Build a formula

The `--build` flag builds the given formulae. The build takes about 10 minutes for one php embed formula.

```bash
docker run --rm -v "$PWD:/mnt/homebrew-unit:ro" homebrew-unit-test --build php-embed@8.3
```

The build also runs `brew linkage --test`. The command fails when the formula has missing libraries or linkage to indirect dependencies. This explicit check is necessary because `test-bot` can ignore a linkage failure for a formula without a bottle and return success.

## Run the component check alone

The component check needs only Python 3. It does not need Docker.

```bash
python3 test/check-components-order.py Formula
```

## Run the inreplace check alone

The inreplace check needs only Python 3. It does not need Docker.

```bash
python3 test/check-inreplace-patterns.py
```

## Notes

- The tap name comes from the `origin` remote. A fork has another owner than the tap on GitHub.
- The container uses the `brew` user. It does not need `sudo`.
- The image holds the linters. A later run of the container starts fast.
- The container does not change the files on the host. It copies them and it removes the copy at the end.
