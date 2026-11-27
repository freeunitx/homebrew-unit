module.exports = async ({github, context, core}, formula_detect) => {
  const { data: { labels: labels } } = await github.rest.pulls.get({
    owner: context.repo.owner,
    repo: context.repo.repo,
    pull_number: context.issue.number
  })
  const label_names = labels.map(label => label.name)

  core.setOutput('syntax-only', label_names.includes('CI-syntax-only') ? 'true' : 'false')
  core.setOutput('linux-runner', 'ubuntu-24.04')
  core.setOutput('fail-fast', 'false')
  core.setOutput('timeout-minutes', label_names.includes('CI-long-timeout') ? '4320' : '180')

  const container = {
    image: 'ghcr.io/homebrew/brew:main',
    options: '--user=linuxbrew'
  }
  core.setOutput('container', JSON.stringify(container))

  // The testing formulae are not set here. The build step of each matrix job
  // passes its own formula with the formulae of this tap that it needs.
  const tap_name = context.repo.repo.replace(/^homebrew-/, '')
  const root_url = `https://ghcr.io/v2/${context.repo.owner}/${tap_name}`
  const test_bot_formulae_args = ['--only-formulae', '--junit', '--only-json-tab', '--skip-dependents']
  test_bot_formulae_args.push(`--root-url="${root_url}"`)
  test_bot_formulae_args.push(`--added-formulae=${formula_detect.added_formulae || ''}`)
  test_bot_formulae_args.push(`--deleted-formulae=${formula_detect.deleted_formulae || ''}`)

  if (label_names.includes('CI-test-bot-fail-fast')) {
    test_bot_formulae_args.push('--fail-fast')
  }
  if (label_names.includes('CI-test-dependents')) {
    const index = test_bot_formulae_args.indexOf('--skip-dependents')
    if (index !== -1) {
      test_bot_formulae_args.splice(index, 1)
    }
  }
  if (label_names.includes('CI-skip-livecheck')) {
    test_bot_formulae_args.push('--skip-livecheck')
  }
  if (label_names.includes('CI-version-downgrade')) {
    test_bot_formulae_args.push('--skip-stable-version-audit')
  }
  if (label_names.includes('CI-skip-revision-audit')) {
    test_bot_formulae_args.push('--skip-revision-audit')
  }

  core.setOutput('test-bot-formulae-args', test_bot_formulae_args.join(' '))
}
