#!/usr/bin/env bash
# Run the local checks of the tap.
#
# The script runs the same checks as the CI job "check-generate".
# It also runs the Python checks of this repository.
#
# Usage:
#   test/run-checks.sh                     run the checks
#   test/run-checks.sh --eol               add the EOL check
#   test/run-checks.sh --inreplace         add the inreplace check
#   test/run-checks.sh --build <formula>   build the given formulae
#
set -euo pipefail

REPO_DIR="${HOMEBREW_UNIT_REPO:-/home/brew/homebrew-unit}"

if [[ ! -d "${REPO_DIR}" ]]
then
  echo "error: the repository is not at ${REPO_DIR}" >&2
  echo "Mount it with: docker run --rm -v \"\$PWD:${REPO_DIR}\" homebrew-unit-test" >&2
  exit 2
fi

# Use the scripts of the working copy. Fall back to the copy in the image
# when the working copy does not hold the test directory.
SCRIPT_DIR="${REPO_DIR}/test"
if [[ ! -f "${SCRIPT_DIR}/check-components-order.py" ]]
then
  SCRIPT_DIR="/opt/homebrew-unit-test"
fi

cd "${REPO_DIR}"

RUN_EOL=false
RUN_INREPLACE=false
BUILD_TARGETS=()

while [[ $# -gt 0 ]]
do
  case "$1" in
    --eol)
      RUN_EOL=true
      ;;
    --inreplace)
      RUN_INREPLACE=true
      ;;
    --build)
      shift
      while [[ $# -gt 0 && "$1" != --* ]]
      do
        BUILD_TARGETS+=("$1")
        shift
      done
      continue
      ;;
    *)
      echo "error: unknown argument $1" >&2
      exit 2
      ;;
  esac
  shift
done

# The tap name comes from the remote. A fork has another owner than the tap
# on GitHub, so the name must not be hard coded.
REMOTE_URL="$(git -c safe.directory='*' remote get-url origin)"
REMOTE_URL="${REMOTE_URL%.git}"
OWNER="$(echo "${REMOTE_URL}" | sed -E 's#^.*github\.com[:/]+([^/]+)/.*$#\1#')"
REPO="$(echo "${REMOTE_URL}" | sed -E 's#^.*github\.com[:/]+[^/]+/([^/]+)$#\1#')"

# The tap "owner/unit" lives in the directory "owner/homebrew-unit".
TAP="${OWNER}/${REPO#homebrew-}"
TAP_DIR_NAME="${OWNER}/${REPO}"

echo "==> Tap: ${TAP}"
echo "==> Repository: ${REPO_DIR}"

# Point the tap at this working copy. A symlink keeps the link live, so
# Homebrew checks the files in this directory and not a copy of them.
TAPS_DIR="$(brew --repository)/Library/Taps"
mkdir -p "${TAPS_DIR}/${OWNER}"
rm -rf "${TAPS_DIR:?}/${TAP_DIR_NAME:?}"
ln -s "${REPO_DIR}" "${TAPS_DIR}/${TAP_DIR_NAME}"

# Homebrew 4.6 and later load a tap only when it is trusted. The CI job does
# the same.
brew trust "${TAP}" >/dev/null 2>&1 || true

# The names of all formulae of the tap, with the aliases.
FORMULA_NAMES=()
for file in "${REPO_DIR}"/Formula/*.rb
do
  FORMULA_NAMES+=("$(basename "${file}" .rb)")
done
if [[ -d "${REPO_DIR}/Aliases" ]]
then
  for link in "${REPO_DIR}"/Aliases/*
  do
    FORMULA_NAMES+=("$(basename "${link}")")
  done
fi

status=0

echo
echo "==> brew style"
brew style "${TAP}" || status=1

echo
echo "==> brew readall"
brew readall --aliases --os=all --arch=all "${TAP}" || status=1

echo
echo "==> brew audit"
brew audit --except=installed --tap="${TAP}" || status=1

echo
echo "==> Component order"
python3 "${SCRIPT_DIR}/check-components-order.py" "${REPO_DIR}/Formula" || status=1

# The CI job runs the livecheck command for every formula.
echo
echo "==> brew livecheck for every formula"
for name in "${FORMULA_NAMES[@]}"
do
  brew livecheck --formula "${TAP}/${name}" || status=1
done

if [[ "${RUN_INREPLACE}" == true ]]
then
  echo
  echo "==> inreplace patterns"
  python3 "${SCRIPT_DIR}/check-inreplace-patterns.py" || status=1
fi

if [[ "${RUN_EOL}" == true ]]
then
  echo
  echo "==> EOL state"
  python3 "${REPO_DIR}/eol/check.py" --check || status=1
fi

if [[ ${#BUILD_TARGETS[@]} -gt 0 ]]
then
  for name in "${BUILD_TARGETS[@]}"
  do
    echo
    echo "==> Building ${name}"
    brew install --build-bottle "${TAP}/${name}" || status=1
    echo
    echo "==> brew linkage ${name}"
    brew linkage --test "${TAP}/${name}" || status=1
    # The CI job runs the audit after the install. The audit checks the
    # files of the installed formula.
    echo
    echo "==> brew audit ${name}"
    brew audit --formula "${TAP}/${name}" --online --git --skip-style || status=1
  done
fi

echo
if [[ "${status}" -eq 0 ]]
then
  echo "All checks passed."
else
  echo "Some checks failed." >&2
fi
exit "${status}"
