---
name: github
description: >
  Official GitHub MCP server (remote HTTP) — gives Claude direct access to repositories,
  issues, pull requests, Actions, code security, and more. Load when working with GitHub
  resources: reviewing PRs, triaging issues, managing workflows, or querying repo structure.
type: http
url: https://api.githubcopilot.com/mcp/
inputs:
  - type: promptString
    id: github_mcp_pat
    description: GitHub Personal Access Token
    password: true
---

# GitHub MCP Server

The official GitHub remote MCP server connects Claude to the full GitHub platform API.
Use it to read and write repositories, issues, pull requests, Actions workflows, security
alerts, and GitHub Projects — all through natural language.

## What it provides

| Category | Tools / Resources |
|----------|-------------------|
| Repositories | browse code, manage files, branches, releases |
| Issues | create, update, search, manage issues and sub-issues |
| Pull Requests | create, review, merge, manage PRs |
| Actions | trigger runs, fetch job logs, manage workflows |
| Projects | manage GitHub Projects items and status |
| Code Security | code scanning alerts, Dependabot, secret scanning, advisories |
| Discussions | create comments, manage GitHub Discussions |
| Notifications | manage notification subscriptions and status |
| Git | low-level git operations, tree exploration |
| Context | current user profile, organization, team info |
| Gists | create, retrieve, update code snippets |
| Users / Orgs | search profiles, browse org structure |
| Copilot | assign Copilot agents to issues, request reviews |

Full tool list: [github/github-mcp-server](https://github.com/github/github-mcp-server).

## Setup

This is a remote HTTP server — no local installation required.

Generate a GitHub Personal Access Token (classic or fine-grained) with the scopes needed
for your use case (e.g. `repo`, `read:org`, `workflow`).

When the host loads this server definition it will prompt securely for the token value.
The value is injected as the `Authorization: Bearer` header and is never stored in plain text.
