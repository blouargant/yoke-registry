# tokensave MCP

[Tokensave](https://github.com/aovestdipaperino/tokensave) indexes a project's source code into
a SQLite graph and exposes it to Claude through 37 MCP tools. Claude can answer structural
questions about any codebase — call graphs, impact analysis, code quality — without reading
every file.

## What it provides

- **Symbol search** — find functions, structs, classes, and constants by name or keyword
- **Call-graph traversal** — trace callers and callees of any function up to N levels deep
- **Impact analysis** — compute the blast radius of a change before making it
- **Code quality** — surface god classes, complexity hotspots, coupling, dead code, and circular dependencies
- **Test coverage** — map source symbols to their test functions and find high-risk untested code
- **Session memory** — persist architectural decisions and replay prior session context

## Setup

1. Install the CLI:
   ```bash
   brew install aovestdipaperino/tap/tokensave   # macOS
   cargo install tokensave                        # any platform
   ```

2. Configure Claude Code (sets up MCP, permissions, hook, and CLAUDE.md rules):
   ```bash
   tokensave claude-install
   ```

3. Index your project:
   ```bash
   cd /path/to/project
   tokensave init
   ```

## Configuration

`mcp.json` registers the MCP server. Replace `--path` with the absolute path to the indexed project:

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

## Keeping the graph fresh

```bash
tokensave sync            # incremental update after code changes
tokensave sync --force    # full re-index
tokensave branch add      # per-branch graph (optional, for multi-branch workflows)
```

## Skill

See [`skills/Coding/tokensave`](../../../skills/Coding/tokensave/SKILL.md) for the guided
setup and usage playbook.
