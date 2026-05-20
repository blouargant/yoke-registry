---
name: create-mcp-md
description: >
  Generate a mcp.md for a new MCP server entry in this registry. Use when the user adds a
  mcp.json to mcp/<Category>/<name>/ and wants to create the matching mcp.md. Reads the
  mcp.json, optionally fetches the tool's README or documentation, then writes mcp.md following
  the registry convention.
---

# Create mcp.md from mcp.json

This skill produces a `mcp.md` alongside an existing `mcp.json` in the `mcp/<Category>/<name>/`
directory. The output follows the same structure as `mcp/Coding/tokensave/mcp.md`.

## Steps

### 1. Read the mcp.json

Read the `mcp.json` in the target directory. If the file is missing, malformed, or cannot be parsed, report an error to the user and stop. Extract:
- Server name (key under `mcpServers` or `servers`)
- `command` and `args` (stdio servers) or `type` and `url` (HTTP servers)
- Any `env` vars if present
- Any `headers` if present (HTTP servers)
- Top-level `inputs` array if present — each entry has `type`, `id`, `description`, and optionally `password`

### 2. Gather documentation

Try each source in order, stopping at the first that yields content that includes a description of the tool's functionality or usage instructions:

1. A `README.md` already present in the same directory
2. The tool's upstream documentation (ask the user for the URL if not obvious from the command name). If the upstream URL is not accessible, prompt the user to provide a brief description manually.
3. The tool's `--help` output: `<command> --help`

If no source yields content, include a placeholder `## What it provides` section in `mcp.md` with the information available from `mcp.json`, and notify the user that documentation is missing.

### 3. Write mcp.md

Create `mcp.md` in the same directory as `mcp.json` using this structure:

```markdown
---
name: <server-name>
description: >
  <One or two sentences: what the MCP server does and when to load it.>
command: <command>
args:
  - <arg1>
  - <arg2>
  ...
# For HTTP servers, use type/url instead of command/args:
# type: http
# url: https://...
# headers:
#   Authorization: Bearer ${input:<token-id>}
# Include inputs only when the mcp.json has an "inputs" array:
inputs:
  - type: <promptString|promptPassword>
    id: <input-id>
    description: <Human-readable prompt shown to the user>
    password: <true if the value is secret>
skills:
  - <matching-skill-name-if-one-exists>
---

# <Title>

<One paragraph: what the server provides and the main use cases.>

## What it provides

| Category | Tools / Resources |
|----------|-------------------|
| <category> | `<tool1>`, `<tool2>` |
...

## Setup

<Installation command(s). Include both macOS and cross-platform options when they exist.>

<Any one-time configuration command.>

## Usage

<Key commands the user runs to interact with the server after setup — sync, status, etc.
Omit this section if the server needs no user-facing commands after install.>
```

### 4. Update the README.md (optional)

If a `README.md` exists and duplicates the `mcp.md` content, ask the user if they want to delete
the `README.md` and proceed only if they confirm — `mcp.md` is the single source of truth for
the registry entry.

## Rules

When constraints conflict, apply them in this order: **accuracy first** (match `mcp.json` exactly), then **brevity** (keep the body concise), then **avoiding duplication** (link rather than copy).

### Frontmatter accuracy (highest priority)

- `command` and `args` in the frontmatter must exactly match `mcp.json` — copy them verbatim.
- The top-level key holding servers is either `servers` (VS Code / Cursor style) or `mcpServers` (Anthropic / Claude Desktop style) — both are equivalent; extract the server name and config from whichever key is present.
- For HTTP servers (`type: http`), use `type` and `url` instead of `command`/`args`. If the server config has a `headers` map, copy it verbatim into the frontmatter under `headers:`.
- If `args` contain a placeholder like `/path/to/your/project`, keep it as-is and add a note
  in the body explaining which argument the user must update.
- Only add a `skills:` entry if a matching skill already exists in `skills/` — do not invent
  skill names.
- If `mcp.json` has an `inputs` array, copy every entry verbatim into `inputs:` in the
  frontmatter. Do not add `inputs:` when the array is absent.
- In the **Setup** section, explain each input: what value the user must supply and where to
  obtain it. For `password: true` inputs, note that the host will prompt securely and the
  value will not be stored in plain text.

### Body quality

- Keep the body concise. The `mcp.md` is a registry entry, not full documentation.
- Do not duplicate the upstream README — link to it instead.

## Example

See `mcp/Coding/tokensave/mcp.md` as the canonical reference output.
