# CLAUDE.md

## Stack

Rails 8.1, SQLite, Tailwind, Minitest with fixtures. Single-user app, no authentication.

## Conventions

- Do not make git commits. If asked for a commit message, print the message without committing.
- Before running any rails or gem commands for the first time, run `bundle check` and `bundle install` if needed.
- Always run rubocop, brakeman, and tests after making changes. Do not run rubocop on `.erb` files.
- When reviewing PRs, do not make comments on the PR. Simply report findings in the conversation.

## Project docs

- `docs/plans/` — Implementation plans and testing plans. Check before starting new phases.
