# QWEN.md — FreeUnit Homebrew Tap

## Project overview

This repository is the official Homebrew tap for FreeUnit.
FreeUnit is the community fork of NGINX Unit.
The tap contains Ruby formula files and versioned aliases.
Homebrew uses these files to build and install FreeUnit from source.

**Repository:** `freeunitorg/homebrew-unit`
**Upstream source:** `https://github.com/freeunitorg/freeunit`

---

## Repository layout

```
.                                     # Repository root
├── README.md                         # Tap overview and install instructions
├── QWEN.md                           # This file
├── Formula/                          # Formula Ruby files
│   ├── unit.rb                       # Server formula
│   ├── unit-php.rb                   # PHP module
│   ├── unit-python3.rb               # Python 3 module
│   ├── unit-python.rb                # Python 2 module (DEAD)
│   ├── unit-java.rb                  # Java module
│   ├── unit-perl.rb                  # Perl module
│   ├── unit-ruby.rb                  # Ruby module
│   ├── unit-wasm.rb                  # WASM module
│   └── php-embed.rb                  # PHP embed SAPI
├── Aliases/                          # Versioned formula aliases
│   ├── unit@1.37.2                   # Current release pin
│   └── php-embed@8.4                 # PHP 8.4 series pin
└── .github/
    └── workflows/                    # GitHub Actions workflows
        ├── main.yml                  # PR CI
        └── manual.yml                # Weekly and manual rebuilds
```

---

## Formulae

| Formula | What it gives | Language deps |
|---|---|---|
| `unit` | `unitd` server + `njs-unit` + `unitctl` | Rust, libedit, openssl@3, pcre2 |
| `unit-php` | PHP language module | `php-embed`, `unit@1.37.2` |
| `unit-python3` | Python 3 language module | `python@3.12`, `unit@1.37.2` |
| `unit-python` | Python 2 module **DEAD** | `:macos` / `maximum_macos :big_sur` — blocks all modern runners |
| `unit-java` | Java language module | `openjdk@11`, `unit@1.37.2` |
| `unit-perl` | Perl language module | `perl`, `unit@1.37.2` |
| `unit-ruby` | Ruby language module | `ruby`, `unit@1.37.2` |
| `unit-wasm` | WebAssembly language module | `rust`, `wasmtime`, `unit@1.37.2` |
| `php-embed` | PHP library (embed SAPI) | php.net tarball, ~30 build deps |

**Dead formula — remove before PR:**
`unit-python.rb` has `depends_on :macos` with `maximum_macos :big_sur`.
This setting blocks every GitHub Actions runner in current use.
Do not include `unit-python.rb` in new PRs.
Request its removal before merging any PR that touches the formula list.

---

## Key version data

- **Current released version:** `1.37.2`
- **Git tag for source:** `1.37.2` (revision `b36f46297b8bf3e075f293f72b206daa72015ed8`)
- **Git branch for HEAD builds:** `master`
- **UNIT_VERSION vs UNIT_REF:** `UNIT_VERSION` is the display string (for example `1.37.2`).
  `UNIT_REF` is the git ref to clone (for example branch `1.37`).
  Tag `1.37.3` does not exist upstream.
  Branch `1.37` carries v1.37.3 with 13 security fixes.
  When building Docker images, use `UNIT_REF` that points to branch `1.37`.
  Do not use the non-existent tag `1.37.3`.

---

## Common formula patterns

All module formulae share this structure:

1. **`url`** — same git repo as `unit.rb`, same tag and revision.
2. **`depends_on "unit@<version>"`** — hard dependency on the server formula of the same version.
3. **`def install`** — run `./configure` with common flags.
   Then `inreplace` the `NXT_MODULESDIR` path in `build/autoconf.data`.
   This redirects modules into `#{lib}/unit/modules` instead of the global prefix.
4. **`test do`** — start `unitd`, push a config via the control socket.
   Then `curl` the listener port and check the expected output.

Use this `inreplace` line in every module formula:

```ruby
inreplace "build/autoconf.data",
          "NXT_MODULESDIR='#{HOMEBREW_PREFIX}/lib/unit/modules'",
          "NXT_MODULESDIR='#{lib}/unit/modules'"
```

---

## `unit.rb` — server formula specifics

- **Resources:** `njs` (NGINX JavaScript, built from source) and `unitctl` (pre-built binary).
  The build selects the correct binary for the OS and CPU architecture.
- **Configure flags:** `--openssl`, `--njs`, `--otel`.
  `--cc-opt` and `--ld-opt` point to `openssl@3` headers and libraries.
- **Installed tools:** `unitd`, `unitctl`, `njs-unit`, `setup-unit`, `unitc`.
- **Service block:** starts `unitd --no-daemon`, `run_type :immediate`.

---

## `php-embed.rb` — PHP embed SAPI

- **Source:** `https://www.php.net/distributions/php-8.4.28.tar.xz` (PHP 8.4 series).
- **macOS patch (`__END__` block):** fixes system-library linking.
  The patch adds `--with-os-sdkpath` support to PHP's build system.
  The patch modifies `php.m4` and `configure.ac`.
- **Build output:** `libphp.dylib` on macOS, `libphp.so` on Linux.
  Both go into `#{lib}/`.

---

## CI workflows

### `main.yml` — PR CI

Triggered on `pull_request`.
Two jobs:

1. **`check-generate`** — runs `brew test-bot --only-tap-syntax` and `--only-formulae-detect`.
   Then builds a build matrix from detected formulae.
   The matrix runs on `macos-26` and `ubuntu-24.04`.

2. **`build-formulae`** — for each `(os, formula)` pair, runs `brew test-bot --only-formulae`.
   `*-php` formulae install `php-embed` and `unit` first.
   `unit-*` formulae install `unit` first.

### `manual.yml` — weekly and manual rebuild

Triggered on schedule (`30 0 * * Mon`) and `workflow_dispatch`.

`test-bot` runs on `macos-26` and checks syntax.
`build-unit` runs on `ubuntu-24.04`, `macos-15`, and `macos-26`.
Module build jobs run after `build-unit` and also run on all three OS images:

`build-unit-perl` / `build-unit-python3` / `build-unit-java` /
`build-unit-ruby` / `build-unit-php` / `build-unit-wasm`.

---

## Version update checklist

When bumping to a new release:

1. Update `tag:` and `revision:` in all formulae that reference the release.
2. Update `depends_on "unit@<old>"` in every module formula.
3. Regenerate `Aliases/unit@<version>` to match the new `unit.rb`.
4. Update version strings in `README.md` (formula table and versioned aliases).
5. Update `revision:` in `unit.rb` `unitctl` resource blocks.
   SHA-256 values stay the same unless `unitctl` binaries were re-signed.

---

## Commit conventions

- Write commit messages in English.
- Use Conventional Commits: `fix:`, `feat:`, `chore:`, `docs:`, and so on.
- Use `/caveman-commit` to generate a ready-to-paste message.
- Split commits by logical meaning. One concern per commit.

---

## Branch and access model

- **Primary branch:** `master` on `freeunitorg/homebrew-unit`.
- `freeunitx` has write access to `freeunitorg/homebrew-unit`.
- `freeunitx` does not have write access to `freeunitorg/freeunit`.
  PRs against `freeunitorg/freeunit` require a fork and a pull request via `freeunitx`.
- Required status checks are in the GitHub UI (Settings → Branches → Branch protection).
  They are not in any file.
  You cannot add, remove, or change them with a commit.

---

## Lessons learned from CI failures

These patterns were discovered through actual CI runs. Follow them to avoid repeated failures.

### CI workflow setup-homebrew tag

`Homebrew/actions/setup-homebrew@master` was removed.
Use a pinned version tag instead: `@2026.11.23.1` (or latest stable).
Check available tags: `gh api repos/Homebrew/actions/tags --jq '.[].name'`.

### Deprecated `Formula["X"]` accessor

Homebrew test-bot now rejects `Formula["X"].opt_prefix`, `opt_include`, `opt_lib`, `opt_bin`.
Replace with the accessor methods:
`formula_opt_prefix("X")`, `formula_opt_include("X")`,
`formula_opt_lib("X")`, `formula_opt_bin("X")`.

### Bare `File.open(...).gets` leaks a file descriptor

Homebrew style check `Style/FileOpen` requires block form.
Wrong: `File.open(path).gets.chop.to_i`
Right: `File.open(path) { |f| f.gets.chop.to_i }`

### `post_install` is deprecated

Homebrew now requires `post_install_steps` instead of `post_install`.
Wrong: `def post_install`
Right: `def post_install_steps`

### Use `assert_path_exists` instead of `assert_predicate ... :exist?`

Homebrew style check `FormulaAudit/AssertStatements` requires `assert_path_exists`.
Wrong: `assert_predicate libphp, :exist?, "expected #{libphp} to be built"`
Right: `assert_path_exists libphp, "expected #{libphp} to be built"`

### Avoid complex ternary operators

Homebrew style check `Homebrew/SimpleTernary` requires `if`/`else` for complex ternaries.
Wrong: `libphp = OS.mac? ? lib/"libphp.dylib" : lib/"libphp.so"`
Right:
```ruby
libphp = if OS.mac?
  lib/"libphp.dylib"
else
  lib/"libphp.so"
end
```

### Align multi-line method arguments

Homebrew style check `Style/AlignArguments` requires aligned arguments when they span multiple lines.
Wrong:
```ruby
inreplace "build/autoconf.data",
    "NXT_MODULESDIR='#{HOMEBREW_PREFIX}/lib/unit/modules'",
    "NXT_MODULESDIR='#{lib}/unit/modules'"
```
Right:
```ruby
inreplace "build/autoconf.data",
          "NXT_MODULESDIR='#{HOMEBREW_PREFIX}/lib/unit/modules'",
          "NXT_MODULESDIR='#{lib}/unit/modules'"
```

### Prefer `to_s` over string interpolation for single variables

Homebrew style check `Style/RedundantInterpolation` requires `to_s` for single variable interpolation.
Wrong: `"#{pid}"`
Right: `pid.to_s`

### Inline single-use methods

Homebrew style check `Homebrew/SingleUseMethod` requires inlining methods called from only one place.
Wrong:
```ruby
def php_version
  version.to_s.split(".")[0..1].join(".")
end
```
args << "--with-config-file-path=#{etc}/php/#{php_version}"
Right: `args << "--with-config-file-path=#{etc}/php/#{version.to_s.split(".")[0..1].join(".")}"`

### Every formula needs a `test do` block

Homebrew style check `FormulaAudit/Test` requires a `test do` block in every formula.
Add a minimal test that verifies the build artefact exists.

### Dead formulae must not be included in PRs

`unit-python.rb` uses `depends_on :macos` with `maximum_macos :big_sur` outside
an `on_macos` block. This blocks every GitHub Actions runner.
Do not include it in new PRs — remove it before merging.

### FPM artefacts do not belong in embed SAPI formulae

When creating an embed SAPI formula, do not copy FPM settings from the main `php.rb` formula.
Remove: `--enable-fpm`, `--with-fpm-user`, `--with-fpm-group`,
`fpm_user` / `fpm_group` variables, `inreplace` of `php-fpm.conf.in`.

### `.gitignore` is required

Always add a `.gitignore` to new or restructured repositories.
Include at minimum: `DS_Store`, editor swap files, `vendor/`, `.bundle/`,
`brew test-bot` artefacts (`/test-bot/`, `/brew-logs/`).

---

## Quick reference commands

```bash
# Tap the repo
brew tap freeunitorg/unit https://github.com/freeunitorg/homebrew-unit

# Install the server
brew install freeunitorg/unit/unit

# Install a module
brew install freeunitorg/unit/unit-php

# Install pinned version
brew install freeunitorg/unit/unit@1.37.2

# Run brew test-bot locally
brew test-bot --only-tap-syntax

# Edit a formula locally
brew edit freeunitorg/unit/unit
```
