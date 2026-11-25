# CHANGES.md — FreeUnit Homebrew Tap

## 2026-11-25 — Version 1.37.2

### Fixed

- Replace `Homebrew/actions/setup-homebrew@master` with `@2026.11.23.1`.
  The `@master` tag was removed. All CI runs failed at "Getting action download info".
  Affected files: `.github/workflows/main.yml`, `.github/workflows/manual.yml`.

- Replace `Formula["X"].opt_prefix` and `Formula["X"].opt_include` with
  `formula_opt_prefix("X")` and `formula_opt_include("X")`.
  Homebrew test-bot now rejects the deprecated `Formula[]` accessor.
  Affected files: `unit.rb`, `unit-java.rb`, `unit-perl.rb`, `unit-php.rb`,
  `unit-python3.rb`, `unit-ruby.rb`, `unit-wasm.rb`, `php-embed.rb`.

- Replace bare `File.open(...).gets` with block form `File.open(...) { |f| ... }`.
  The bare form leaks a file descriptor. Homebrew style check `Style/FileOpen`
  now reports this as an error.
  Affected files: `unit.rb`, `unit-java.rb`, `unit-perl.rb`, `unit-php.rb`,
  `unit-python3.rb`, `unit-ruby.rb`.

- Remove `unit-python.rb` (Python 2 module).
  The formula uses `depends_on :macos` with `maximum_macos :big_sur` outside
  an `on_macos` block. Homebrew test-bot rejects this pattern on all runners.
  The formula cannot build on any modern macOS or Linux runner.
  The formula was already marked as dead in project documentation.

- Remove FPM artefacts from `php-embed.rb`.
  The formula was copied from Homebrew/core `php.rb` and retained FPM settings.
  `php-embed` builds the embed SAPI for FreeUnit. FPM is not used.
  Removed: `--enable-fpm`, `--with-fpm-user`, `--with-fpm-group`,
  `fpm_user` / `fpm_group` variables, `inreplace` of `php-fpm.conf.in`.

- Inline `php_version` method in `php-embed.rb`.
  Homebrew style check `Homebrew/SingleUseMethod` requires inlining methods
  called from only one place.

- Add missing `test do` block to `unit-wasm.rb`.
  Homebrew style check `FormulaAudit/Test` requires a `test do` block in every
  formula.

- Add missing `test do` block to `php-embed.rb`.
  Same reason as above.
