# Test environment for the FreeUnit Homebrew tap.
#
# The image holds Homebrew on Linux. It runs the same checks as the CI job
# "check-generate". Use it to check a formula before you push it.
#
# Build the image:
#   docker build -t homebrew-unit-test test/
#
# Run the checks:
#   docker run --rm -v "$PWD:/home/brew/homebrew-unit" homebrew-unit-test
#
FROM ubuntu:24.04

LABEL org.opencontainers.image.title="homebrew-unit test environment"
LABEL org.opencontainers.image.description="Homebrew on Linux for the local checks of the freeunitorg/homebrew-unit tap"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    HOMEBREW_PREFIX=/home/linuxbrew/.linuxbrew \
    HOMEBREW_NO_ANALYTICS=1 \
    HOMEBREW_NO_AUTO_UPDATE=1 \
    HOMEBREW_NO_ENV_HINTS=1 \
    HOMEBREW_NO_INSTALL_CLEANUP=1 \
    PATH=/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH

# The rubocop gems have native extensions, so the image needs a compiler.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      curl \
      git \
      python3 \
      tzdata \
 && rm -rf /var/lib/apt/lists/*

# The installer needs a prefix that the build user owns. It does not need sudo.
RUN useradd --create-home --shell /bin/bash brew \
 && mkdir -p /home/linuxbrew \
 && chown -R brew:brew /home/linuxbrew

USER brew
WORKDIR /home/brew

# The mounted directory keeps the rights of the user on the host. Git refuses
# to read such a directory unless the container trusts it.
RUN git config --global --add safe.directory '*'

# The installer takes the same path as the CI job of the setup-homebrew action.
RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
 && brew --version

# The first call of "brew style" installs the rubocop, shellcheck, and shfmt
# tools. The build takes that time, so every later run of the container starts
# fast.
RUN mkdir -p /tmp/dummy/Formula /tmp/dummy/.github/workflows \
 && printf 'class Dummy < Formula\n  desc "Dummy"\n  homepage "https://example.com"\n  url "https://example.com/dummy-1.0.tar.gz"\n  sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"\n  license "MIT"\nend\n' > /tmp/dummy/Formula/dummy.rb \
 && printf '#!/usr/bin/env bash\necho dummy\n' > /tmp/dummy/Formula/dummy.sh \
 && printf 'name: dummy\non: push\njobs:\n  dummy:\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo dummy\n' > /tmp/dummy/.github/workflows/dummy.yml \
 && brew style /tmp/dummy/Formula/dummy.rb /tmp/dummy/Formula/dummy.sh \
      /tmp/dummy/.github/workflows/dummy.yml || true

COPY --chown=brew:brew . /opt/homebrew-unit-test/
RUN chmod +x /opt/homebrew-unit-test/entrypoint.sh /opt/homebrew-unit-test/run-checks.sh

ENV HOMEBREW_UNIT_SOURCE=/mnt/homebrew-unit \
    HOMEBREW_UNIT_REPO=/home/brew/homebrew-unit

ENTRYPOINT ["/opt/homebrew-unit-test/entrypoint.sh"]
CMD []
