# Changelog

## [Unreleased]

### Dependencies

- **php-embed.rb**: `icu4c@76` → `icu4c@79`. The `icu4c@76` formula was disabled in homebrew-core on 2026-03-29, so the tap build failed at the dependency step.
- **php-embed.rb**: `php` → `php@8.5`. The unversioned `php` formula tracks the newest PHP release. The php module reads `php-config` from `PATH`, so the pin keeps the module headers and the embed library on the same PHP version.
- **unit-java.rb**: `openjdk@11` → `openjdk@21`. The `openjdk@11` formula was deprecated on 2023-09-30. The main project tests the java module with Java 17, 21, 25, 26, and 27.

### New formulae

- **php-embed@8.4.rb**: the PHP 8.4 series, with the patch for the 8.4 source layout.
- **php-embed@8.3.rb**: the PHP 8.3 series, with its own patch. The `PHP_ADD_INCLUDE` macro differs in 8.3, so the 8.4 patch does not apply.
- **unit-php@8.4.rb**: the PHP module for the 8.4 series.
- **unit-php@8.3.rb**: the PHP module for the 8.3 series.

The supported PHP series are 8.3, 8.4, and 8.5. The main project lists the same set in `pkg/eol.json`.

### Changed

- **php-embed.rb**: PHP 8.4.28 → 8.5.13.
- **unit-php.rb**: the module now takes the php-config of its own series with `--config`, and links the embed library of that series with `--lib-path`. Without `--lib-path` the linker does not find an embed-enabled `libphp`, because the homebrew-core php formula does not build the embed SAPI. Without `--config` the module reads the php-config of the unversioned php formula, which tracks the newest PHP release.
- **unit-php@8.4.rb**, **unit-php@8.3.rb**: each series gets its own module name (`php84`, `php83`), so the object files and the make targets differ. The three series can run at the same time.
- **.github/workflows/main.yml**: added `fail-fast: false` to the build matrix. One failed job no longer cancels the other jobs.
- **.github/workflows/main.yml**: removed `--fail-fast` from `brew test-bot`. Every formula of the job now gets built.
- **.github/workflows/main.yml**: the matrix now builds the versioned php module with the versioned embed library of the same series.
- **.github/workflows/main.yml**: the build step takes the tap name from the formula name. The name of the tap works for the upstream repo and for a fork. The case patterns use the bare name of the formula, because the patterns of bash need it.
- **.github/workflows/manual.yml**: added jobs for the php embed formulae and the versioned php modules.
- **Aliases/**: `php-embed@8.4` → `php-embed@8.5`. Added `unit-php@8.5`.

### Formula fixes

- **unit.rb**: renamed `post_install` → `post_install_steps` (current Homebrew DSL)
- **unit-ruby.rb**: removed unnecessary string interpolation around `formula_opt_bin("gem")` call
- **php-embed.rb**: replaced `assert_predicate …, :exist?` with `assert_path_exists` in test block
- **unit-wasm.rb**: replaced `assert_predicate …, :exist?` with `assert_path_exists` in test block
- **php-embed@8.3.rb**, **php-embed@8.4.rb**: moved the `livecheck` and `head` blocks above `keg_only`. Homebrew checks the order of the formula components.
- **unit-php.rb**, **unit-php@8.4.rb**, **unit-php@8.3.rb**: replaced `Formula["…"].opt_bin` and `Formula["…"].opt_lib` with `formula_opt_bin` and `formula_opt_lib`. The resulting path is the same.
- **php-embed@8.3.rb**: the inreplace patterns of the configure script now use the backticks. PHP changed the quoting of the APXS lines between the series 8.3 and 8.4. The series 8.3 uses backticks, the later series use the `$()` form. The build failed with the message `inreplace failed`.
- **php-embed.rb**, **php-embed@8.4.rb**, **php-embed@8.3.rb**: the `head` block now has the branch name. The audit reported `Git head URL must specify a branch name`.
- **php-embed.rb**, **php-embed@8.4.rb**, **php-embed@8.3.rb**: the livecheck block uses the page `https://www.php.net/downloads?source=Y` and the version of the series. The old page holds no tarball, so the livecheck reported `Unable to get versions`. The old regex also found the versions of the other series.

### Added

- `eol/eol.json`: the EOL state of every package the tap depends on
- `eol/check.py`: the script that refreshes `eol.json` and checks the PHP version coherence
- `eol/README.md`: the description of the EOL data and the update procedure
- `test/`: a container that runs the local checks of the tap. It holds Homebrew on Linux.
- `test/README.md`: the description of the local checks
- `test/check-components-order.py`: the check of the formula component order. It needs only Python 3.
- `test/check-inreplace-patterns.py`: the check of the inreplace patterns of the php embed formulae. It reads the configure script of the PHP source of the formula. It needs only Python 3.
- `test/run-checks.sh`: the script that runs the local checks. It runs the livecheck of every formula now. The flag `--build` builds a formula and runs the audit of it, like the CI job does.
- `test/run-checks.sh`: the script that runs the local checks
- `test/entrypoint.sh`: the script that prepares the working copy in the container
- `.gitignore` for editor artefacts and OS metadata files
- `CHANGES.md` to track formula-level changes

### Checks

- **.github/workflows/main.yml**, **test/run-checks.sh**: run `brew linkage --test` directly after the build. `test-bot` can ignore this failure for a formula without a bottle and return success.
- `eol/check.py`: the mode `--check` reported the file as stale on every run. It compared the date of the check with itself. The day counters change every day, so they did the same.
- `eol/check.py`: the formulae of the tap no longer appear in the list of the packages. The script reads the names from the `Formula` and `Aliases` directories.
- `eol/check.py`: the script retries a request when the Homebrew API answers with the code 503.
- `eol/eol.json`: the versions of `php-embed@8.3` and `php-embed@8.4` are now in the section `tap_formulae`. The section `packages` holds 39 packages.
