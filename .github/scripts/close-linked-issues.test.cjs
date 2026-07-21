const test = require('node:test')
const assert = require('node:assert/strict')

const {
  closeLinkedIssues,
  extractClosingIssueNumbers,
} = require('./close-linked-issues.cjs')

test('extracts issue numbers from closing keywords', () => {
  assert.deepEqual(
    extractClosingIssueNumbers('Closes #4\nFixes: #8\nResolved #12'),
    [4, 8, 12],
  )
})

test('ignores references and removes duplicate issue numbers', () => {
  assert.deepEqual(
    extractClosingIssueNumbers('Refs #4\nCloses #7\nFixes #7'),
    [7],
  )
})

test('accepts a pull request without a body', () => {
  assert.deepEqual(extractClosingIssueNumbers(null), [])
})

test('closes open issues after a pull request is merged', async () => {
  const calls = []
  const github = {
    rest: {
      issues: {
        get: async ({ issue_number }) => ({
          data: { number: issue_number, state: 'open' },
        }),
        createComment: async (input) => calls.push(['comment', input]),
        update: async (input) => calls.push(['update', input]),
      },
    },
  }
  const context = {
    repo: { owner: 'xjy264', repo: 'datong-hub-offline-demo' },
    payload: {
      pull_request: {
        number: 9,
        merged: true,
        base: { ref: 'staging' },
        body: 'Closes #4',
      },
    },
  }

  const closed = await closeLinkedIssues({
    github,
    context,
    core: { info: () => {} },
  })

  assert.deepEqual(closed, [4])
  assert.equal(calls[0][0], 'comment')
  assert.match(calls[0][1].body, /PR #9/)
  assert.deepEqual(calls[1], [
    'update',
    {
      owner: 'xjy264',
      repo: 'datong-hub-offline-demo',
      issue_number: 4,
      state: 'closed',
      state_reason: 'completed',
    },
  ])
})

test('does nothing when the pull request was not merged', async () => {
  const context = {
    repo: { owner: 'xjy264', repo: 'datong-hub-offline-demo' },
    payload: {
      pull_request: { number: 9, merged: false, body: 'Closes #4' },
    },
  }

  const closed = await closeLinkedIssues({ github: {}, context })

  assert.deepEqual(closed, [])
})
