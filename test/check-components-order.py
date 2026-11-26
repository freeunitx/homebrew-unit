#!/usr/bin/env python3
"""Check the order of the formula components.

The source of truth is the list of components in the Homebrew code:
    Library/Homebrew/ast_constants.rb
    FORMULA_COMPONENT_PRECEDENCE_LIST

The rubocop cop "FormulaAudit/ComponentsOrder" uses the same list. This
script gives the same result without a Homebrew installation.

Usage:
    python3 test/check-components-order.py [Formula]
"""
import re
import sys
from pathlib import Path

# (name, type) pairs in precedence order.
# type: method_call | block_call | method_definition
PRECEDENCE = [
    ("include", "method_call"),
    ("desc", "method_call"),
    ("homepage", "method_call"),
    ("url", "method_call"),
    ("mirror", "method_call"),
    ("version", "method_call"),
    ("sha256", "method_call"),
    ("license", "method_call"),
    ("revision", "method_call"),
    ("version_scheme", "method_call"),
    ("compatibility_version", "method_call"),
    ("head", "method_call"),
    ("stable", "block_call"),
    ("livecheck", "block_call"),
    ("no_autobump!", "method_call"),
    ("bottle", "block_call"),
    ("pour_bottle?", "block_call"),
    ("head", "block_call"),
    ("bottle", "method_call"),
    ("keg_only", "method_call"),
    ("option", "method_call"),
    ("deprecated_option", "method_call"),
    ("deprecate!", "method_call"),
    ("disable!", "method_call"),
    ("depends_on", "method_call"),
    ("uses_from_macos", "method_call"),
    ("on_macos", "block_call"),
    ("on_system", "block_call"),
    ("on_linux", "block_call"),
    ("on_arm", "block_call"),
    ("on_intel", "block_call"),
    ("conflicts_with", "method_call"),
    ("preserve_rpath", "method_call"),
    ("skip_clean", "method_call"),
    ("cxxstdlib_check", "method_call"),
    ("link_overwrite", "method_call"),
    ("fails_with", "method_call"),
    ("pypi_packages", "method_call"),
    ("resource", "block_call"),
    ("depends_on", "method_call"),
    ("patch", "method_call"),
    ("patch", "block_call"),
    ("needs", "method_call"),
    ("allow_network_access!", "method_call"),
    ("deny_network_access!", "method_call"),
    ("install", "method_definition"),
    ("post_install_steps", "block_call"),
    ("post_install", "method_definition"),
    ("caveats", "method_definition"),
    ("plist_options", "method_call"),
    ("plist", "method_definition"),
    ("test", "block_call"),
]

# The on_<os> blocks come from MacOSVersion::SYMBOLS in the Homebrew code.
MACOS_BLOCKS = [
    "on_ventura", "on_sonoma", "on_sequoia", "on_tahoe", "on_surveyor",
    "on_high_sierra", "on_mojave", "on_catalina", "on_big_sur",
    "on_monterey", "on_el_capitan", "on_yosemite", "on_mavericks",
    "on_mountain_lion", "on_lion", "on_snow_leopard", "on_leopard",
    "on_tiger", "on_panther",
]

RANK = {}
for index, (name, kind) in enumerate(PRECEDENCE):
    RANK.setdefault((name, kind), index)
for offset, name in enumerate(MACOS_BLOCKS):
    RANK.setdefault((name, "block_call"), 28 + offset)

KEYWORDS = {
    "end", "else", "elsif", "when", "rescue", "ensure", "private", "public",
    "protected", "class", "module", "if", "unless", "begin", "case", "while",
    "until", "def", "return", "next", "break", "self",
}

CALL = re.compile(r"^  ([a-z_][a-zA-Z0-9_]*[?!]?)\b(.*)$")
DEF = re.compile(r"^  def ([a-z_][a-zA-Z0-9_]*[?!]?)\b")


def components(path):
    """Return the top level components of the formula, in the order of the file."""
    found = []
    for number, line in enumerate(path.read_text().splitlines(), 1):
        if not line.startswith("  ") or line.startswith("   "):
            continue
        stripped = line.strip()
        if not stripped or stripped in KEYWORDS:
            continue
        match = DEF.match(line)
        if match:
            found.append((number, match.group(1), "method_definition"))
            continue
        match = CALL.match(line)
        if not match:
            continue
        name, rest = match.group(1), match.group(2)
        kind = "block_call" if rest.startswith(" do") or rest.endswith(" do") else "method_call"
        found.append((number, name, kind))
    return found


def check(path):
    """Return the list of order problems of one formula."""
    problems = []
    previous = None
    for number, name, kind in components(path):
        key = (name, kind)
        if key not in RANK:
            continue
        rank = RANK[key]
        if previous and rank < previous[0]:
            problems.append(
                f"{path.name}:{number}: {name} should be put before "
                f"{previous[1]} (line {previous[2]})")
        if previous is None or rank != previous[0]:
            previous = (rank, name, number)
    return problems


def main():
    directory = Path(sys.argv[1] if len(sys.argv) > 1 else "Formula")
    if not directory.is_dir():
        print(f"error: {directory} is not a directory", file=sys.stderr)
        return 2

    problems = []
    for path in sorted(directory.glob("*.rb")):
        problems.extend(check(path))

    for problem in problems:
        print(problem)
    print(f"{len(problems)} problem(s) in {directory}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
