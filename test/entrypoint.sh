#!/usr/bin/env bash
# Prepare the working copy and start the checks.
#
# The script copies the mounted repository into the container. The files of a
# mounted directory keep the rights of the user on the host. The "brew style"
# command needs to write to the files that it checks, so it can not read the
# mount directly.
#
# Usage:
#   docker run --rm -v "$PWD:/mnt/homebrew-unit:ro" homebrew-unit-test
#
set -euo pipefail

SOURCE_DIR="${HOMEBREW_UNIT_SOURCE:-/mnt/homebrew-unit}"
WORK_DIR="${HOMEBREW_UNIT_REPO:-/home/brew/homebrew-unit}"

if [[ ! -d "${SOURCE_DIR}" ]]
then
  echo "error: the repository is not at ${SOURCE_DIR}" >&2
  echo "Mount it with: docker run --rm -v \"\$PWD:${SOURCE_DIR}:ro\" homebrew-unit-test" >&2
  exit 2
fi

rm -rf "${WORK_DIR:?}"
mkdir -p "${WORK_DIR}"
tar -C "${SOURCE_DIR}" --no-same-owner --ignore-failed-read \
  --exclude=.qwen --exclude=__pycache__ --exclude=.DS_Store \
  -cf - . | tar -C "${WORK_DIR}" --no-same-owner --ignore-failed-read -xf -

export HOMEBREW_UNIT_REPO="${WORK_DIR}"
exec "${WORK_DIR}/test/run-checks.sh" "$@"
