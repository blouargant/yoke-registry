---
name: tokensave
description: >
  Set up and use tokensave — a code-graph MCP server that indexes a project into a SQLite graph
  and gives Claude 37 specialized tools for symbol search, call-graph analysis, impact analysis,
  and code quality checks. Use when the user wants to install tokensave, index a project, run
  tokensave commands, or troubleshoot why tokensave tools are not working.
license: Apache-2.0
compatibility: Requires tokensave CLI (install via Homebrew or Cargo)
---

# Tokensave Setup and Usage

Tokensave builds a code graph from the project source and exposes it to Claude through an MCP
server. Once configured, Claude can answer structural questions about any codebase without
reading every file.

Follow the phases below in order. Stop at the earliest phase that fully addresses the user's request as described. Use the decision tree below to select the correct starting phase:

- **User wants to install tokensave** → start at Phase 1
- **CLI is installed but MCP tools are missing in Claude** → start at Phase 2
- **MCP tools are visible but return empty results** → start at Phase 3
- **User wants per-branch graphs** → start at Phase 4

---

## Phase 1 — Install the CLI

Detect whether `tokensave` is already installed:

```bash
tokensave --version
```

If the command is not found, install it:

**macOS (Homebrew):**
```bash
brew install aovestdipaperino/tap/tokensave
```

**Any platform (Cargo):**
```bash
cargo install tokensave
```

Verify after install:
```bash
tokensave --help
```

---

## Phase 2 — Configure Claude Code

Run the single-command setup. This is idempotent and safe to re-run after upgrades:

```bash
tokensave claude-install
```

This configures four things automatically:
- MCP server entry in Claude Code settings
- Tool permissions for all `tokensave_*` tools
- `PreToolUse` hook that intercepts read-only calls and routes them through the graph
- `CLAUDE.md` rules that instruct Claude to prefer tokensave over file reads

**Manual MCP config (Claude Desktop or custom setups):** point to `mcp/Coding/tokensave.json`
in this registry, then set `--path` to the absolute path of the target project:

```json
{
  "mcpServers": {
    "tokensave": {
      "command": "tokensave",
      "args": ["serve", "--path", "/absolute/path/to/project"]
    }
  }
}
```

---

## Phase 3 — Index the project

Move into the project root and initialize:

```bash
cd /path/to/project
tokensave init
```

This creates `.tokensave/` and indexes all supported files (15 languages). Check what was indexed:

```bash
tokensave status
```

After making code changes, keep the graph current:

```bash
tokensave sync            # incremental — only changed files
tokensave sync --force    # full re-index
```

The MCP server reads from the database on each request, so synced changes are available
immediately — no restart needed.

---

## Phase 4 — Multi-branch support (optional)

If the user works across multiple git branches, activate per-branch graphs:

```bash
tokensave branch add      # snapshot current branch; syncs only diffs going forward
```

Switching branches with stale results? Run `tokensave branch add` on each branch once, then
`tokensave sync` after each checkout.

---

## Using tokensave tools in Claude

Once the MCP server is running, Claude has access to these tools. Use them instead of reading
files directly.

### Core exploration tools

| Tool | When to use |
|------|-------------|
| `tokensave_context` | **Start here** — builds AI-ready context for any natural-language task |
| `tokensave_search` | Find symbols by name or keyword |
| `tokensave_node` | Get detailed info (signature, file, line) for one symbol |
| `tokensave_files` | List indexed files with optional path/extension filters |

### Call-graph and impact tools

| Tool | When to use |
|------|-------------|
| `tokensave_callers` | Who calls this function? |
| `tokensave_callees` | What does this function call? |
| `tokensave_impact` | If I change symbol X, what else breaks? |
| `tokensave_affected` | Which test files need to run after source changes? |

### Code quality tools

| Tool | When to use |
|------|-------------|
| `tokensave_complexity` | Rank functions by composite complexity score |
| `tokensave_god_class` | Find classes with an excessive number of members |
| `tokensave_coupling` | Rank files by fan-in / fan-out coupling |
| `tokensave_recursion` | Detect recursive call cycles |
| `tokensave_doc_coverage` | Find public symbols missing documentation |
| `tokensave_largest` | Rank classes or methods by size |
| `tokensave_rank` | Rank by relationship count (most implemented interface, etc.) |

### Session and session-recall tools

| Tool | When to use |
|------|-------------|
| `tokensave_session_start` | Begin a tracked session (records decisions and context) |
| `tokensave_session_recall` | Replay prior session context in a new conversation |
| `tokensave_record_decision` | Persist an architectural decision in the graph |

See the [tokensave README](https://github.com/aovestdipaperino/tokensave) for the full list of 37 tools.

---

## Workflow rules

1. **Always start with `tokensave_context`** for any code exploration task. Pass the user's
   question verbatim as the `task` argument. Use `exclude_node_ids` from each response in the
   next call to avoid repeating nodes.
2. **Call budget**: respect the per-tool call budget in the tool descriptions. For
   `tokensave_context` this is typically 4 calls per session.
3. **Do not read files you could graph instead.** If `tokensave_context` returns source
   snippets, treat those as the authoritative code — do not re-read the same file.
4. **After edits, remind the user to sync**: any structural change (new function, rename,
   delete) should be followed by `tokensave sync` before the next exploration session.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `tokensave_*` tools not visible in Claude | Re-run `tokensave claude-install` and restart Claude Code |
| Stale results after code changes | Run `tokensave sync` in the project root |
| Tool returns empty results | Run `tokensave status` to confirm files were indexed; re-run `tokensave init` if the count is 0 |
| Wrong project indexed | Check the `--path` argument in the MCP config matches the actual project root |
| Branch switch causes stale graph | Run `tokensave branch add` on the new branch, then `tokensave sync` |
| MCP server fails to start | Check the `command` in the MCP config points to a valid `tokensave` binary (`which tokensave`); verify the `--path` argument exists; inspect Claude Code's MCP logs for error details; re-run `tokensave claude-install` to reset the config |
