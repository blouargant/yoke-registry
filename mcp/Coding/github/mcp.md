---
name: github
description: >
  GitHub MCP server — connects Claude to GitHub via the Copilot MCP API to manage issues, pull
  requests, repositories, notifications, projects, and more. Load when you need to read or write
  GitHub resources without leaving the chat.
type: http
url: https://api.githubcopilot.com/mcp/
headers:
  Authorization: Bearer ${input:github_mcp_pat}
inputs:
  - type: promptString
    id: github_mcp_pat
    description: GitHub Personal Access Token
    password: true
---

# GitHub MCP Server

The GitHub MCP server exposes the GitHub API through the MCP protocol, letting Claude create and
update issues, review and merge pull requests, search code and repositories, manage notifications,
and more — all without leaving the chat. The remote endpoint is hosted by GitHub; no local install
is needed.

## What it provides

| Category | Tools |
|----------|-------|
| Issues | `issue_read`, `issue_write`, `add_issue_comment`, `list_issues`, `search_issues`, `sub_issue_write` |
| Pull Requests | `pull_request_read`, `create_pull_request`, `update_pull_request`, `merge_pull_request`, `list_pull_requests`, `search_pull_requests`, `pull_request_review_write` |
| Repositories | `get_file_contents`, `create_or_update_file`, `push_files`, `create_repository`, `fork_repository`, `create_branch`, `list_branches`, `search_code`, `search_repositories` |
| Notifications | `list_notifications`, `get_notification_details`, `mark_all_notifications_read`, `dismiss_notification` |
| Projects | `projects_list`, `projects_get`, `projects_write` |
| Actions | `actions_list`, `actions_get`, `actions_run_trigger`, `get_job_logs` |
| Discussions | `list_discussions`, `get_discussion`, `get_discussion_comments`, `discussion_comment_write` |
| Security | `list_code_scanning_alerts`, `list_secret_scanning_alerts`, `list_dependabot_alerts` |
| Context | `get_me`, `get_teams`, `get_team_members` |
| Copilot (remote only) | `create_pull_request_with_copilot`, `assign_copilot_to_issue`, `request_copilot_review`, `get_copilot_space` |

Full tool list: [github/github-mcp-server](https://github.com/github/github-mcp-server).

## Setup

No local installation required — the server runs at `https://api.githubcopilot.com/mcp/`.

Generate a GitHub Personal Access Token (classic or fine-grained) with the scopes needed for your
workflow (e.g. `repo`, `read:org`, `notifications`). When the MCP host loads this server it will
prompt you for the token; the value is stored securely and never written to plain text.

> **Copilot Business / Enterprise users:** your organisation must have the
> *MCP servers in Copilot* policy enabled before the remote endpoint is accessible.
