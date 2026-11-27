## Related issue

<!-- Add the related issue or discussion. -->

Closes #

## Description

<!-- Describe the change and its purpose. -->

## Affected formulae and platforms

<!-- List the formulae, operating systems, and architectures. -->

## Validation

<!-- Mark the completed checks and add the relevant output. -->

- [ ] `docker run --rm -v "$PWD:/mnt/homebrew-unit:ro" homebrew-unit-test`
- [ ] `python3 test/check-components-order.py Formula`
- [ ] Formula tests pass.
- [ ] PHP inreplace and patch checks pass for changed PHP formulae.
- [ ] Workflow changes pass Actionlint.

## Bottles

<!-- Complete this section when the change needs new bottles. -->

- [ ] The build produced the expected bottle artifacts.
- [ ] The package installation was tested without `--build-from-source`.
- [ ] `brew linkage --test` passed.

## Additional context

<!-- Add deployment notes, risks, or reviewer instructions. -->
