#!/usr/bin/env python3
"""Check the inreplace patterns of the php embed formulae.

PHP changed the quoting of the APXS lines between the series 8.3 and 8.4.
The series 8.3 uses backticks, the later series use the $() form. A formula
with the patterns of the wrong series fails the build with the message
"inreplace failed".

This script reads the patterns from the formula, downloads the source of the
PHP version of the formula, and checks that every pattern occurs in the
configure script of the source.

Usage:
    python3 test/check-inreplace-patterns.py [--cache DIR]
"""
import argparse
import re
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FORMULA_DIR = ROOT / "Formula"

USER_AGENT = "homebrew-unit-inreplace-check"

# The version of the PHP source comes from the url of the formula.
URL_PATTERN = re.compile(r'url "https://www\.php\.net/distributions/php-(\d+\.\d+\.\d+)\.tar\.xz"')

# The patterns of the inreplace block of the formula.
GSUB_PATTERN = re.compile(r'^\s*s\.gsub!\s+"(.*)",\s*$', re.M)


def fetch_tarball(version: str, cache: Path) -> Path:
    """Download the PHP source. Keep it in the cache."""
    cache.mkdir(parents=True, exist_ok=True)
    tarball = cache / f"php-{version}.tar.xz"
    if not tarball.exists():
        url = f"https://www.php.net/distributions/php-{version}.tar.xz"
        print(f"  downloading {url}")
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=120) as response:
            tarball.write_bytes(response.read())
    return tarball


def read_configure(tarball: Path) -> str:
    """Read the configure script from the source archive."""
    with tarfile.open(tarball, "r:xz") as archive:
        for member in archive:
            if member.name.endswith("/configure") and member.name.count("/") == 1:
                extracted = archive.extractfile(member)
                if extracted is None:
                    break
                return extracted.read().decode("utf-8", "replace")
    return ""


def formula_patterns(source: str) -> list[str]:
    """Return the patterns of the inreplace block for the configure script."""
    block = re.search(r'inreplace "configure" do \|s\|(.*?)\n    end', source, re.S)
    if not block:
        return []
    patterns = []
    for line in block.group(1).splitlines():
        match = GSUB_PATTERN.match(line)
        if match:
            patterns.append(match.group(1))
    return patterns


def ruby_to_plain(pattern: str) -> str:
    """Turn a Ruby string literal into the text that it holds.

    Ruby uses # for an interpolation. The formulae do not use it in these
    patterns, so the text stays the same.
    """
    return pattern.replace('\\"', '"').replace("\\\\", "\\")


def check(path: Path, cache: Path) -> list[str]:
    """Return the list of problems of one formula."""
    source = path.read_text()
    version_match = URL_PATTERN.search(source)
    if not version_match:
        return [f"{path.name}: no PHP source url found"]

    version = version_match.group(1)
    patterns = formula_patterns(source)
    if not patterns:
        return [f"{path.name}: no inreplace patterns found for configure"]

    tarball = fetch_tarball(version, cache)
    configure = read_configure(tarball)
    if not configure:
        return [f"{path.name}: the configure script is not in the archive"]

    problems = []
    for pattern in patterns:
        if ruby_to_plain(pattern) not in configure:
            problems.append(f"{path.name}: the pattern is not in the configure "
                            f"script of PHP {version}: {pattern}")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", default=None,
                        help="directory for the downloaded source archives")
    args = parser.parse_args()

    cache = Path(args.cache) if args.cache else Path(tempfile.gettempdir()) / "php-sources"

    problems = []
    for path in sorted(FORMULA_DIR.glob("php-embed*.rb")):
        print(f"checking {path.name}")
        problems.extend(check(path, cache))

    for problem in problems:
        print(f"error: {problem}", file=sys.stderr)
    print(f"{len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
