const CLOSING_KEYWORD_PATTERN = /\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s*:?\s*#(\d+)\b/gi

function extractClosingIssueNumbers(body) {
  const issueNumbers = new Set()

  for (const match of (body || '').matchAll(CLOSING_KEYWORD_PATTERN)) {
    issueNumbers.add(Number(match[1]))
  }

  return [...issueNumbers]
}

async function closeLinkedIssues({ github, context, core = console }) {
  const pullRequest = context.payload.pull_request
  if (!pullRequest?.merged) return []

  const issueNumbers = extractClosingIssueNumbers(pullRequest.body)
  const closedIssueNumbers = []

  for (const issueNumber of issueNumbers) {
    const issueInput = {
      ...context.repo,
      issue_number: issueNumber,
    }
    const { data: issue } = await github.rest.issues.get(issueInput)

    if (issue.pull_request || issue.state === 'closed') continue

    await github.rest.issues.createComment({
      ...issueInput,
      body: `已由合并到 \`${pullRequest.base.ref}\` 的 PR #${pullRequest.number} 自动关闭。`,
    })
    await github.rest.issues.update({
      ...issueInput,
      state: 'closed',
      state_reason: 'completed',
    })

    closedIssueNumbers.push(issueNumber)
    core.info(`Closed issue #${issueNumber} from merged PR #${pullRequest.number}`)
  }

  return closedIssueNumbers
}

module.exports = {
  closeLinkedIssues,
  extractClosingIssueNumbers,
}
