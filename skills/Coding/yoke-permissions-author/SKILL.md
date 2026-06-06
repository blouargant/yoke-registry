---
name: yoke-permissions-author
description: Author a yoke permissions.json (or a skill's bundled permission overlay) using Claude Code's permission nomenclature — classify each tool surface as read-only (allow), mutating (ask), or dangerous (deny), confirming every decision with the user. Use whenever the user wants to write, review, or tighten permissions, gate a new tool/command, add a permission rule-set, or asks "what should be allowed/asked/denied".
metadata:
  author: blouargant@chapsvision.com
  tags: "yoke, permissions, security, authoring, claude-code, allow, ask, deny"
---

# Authoring yoke permissions

This skill is the playbook for writing a `permissions.json` for yoke (or the
`permissions.json` overlay bundled inside another skill). yoke uses **Claude
Code's permission nomenclature**. Your job is to (1) discover the tool surfaces
the agent will touch, (2) **ask the user how each should be handled**, and (3)
write correct, minimal rules.

**Golden rule: do not guess the policy.** Read-only vs. mutating vs. dangerous is
a judgement call the *user* owns. Identify candidates, then use the `ask_user`
tool to confirm the tier for each group before writing anything.

## 1. The model you are writing for

`permissions.json` holds a `permissions` object with three tiers plus a
`defaultMode`. Rules are evaluated **deny → ask → allow** (first match wins; deny
always wins). Anything matching no rule falls through to the mode default (in
`default` mode that means **ask**).

```json
{
  "permissions": {
    "defaultMode": "default",
    "deny":  ["Bash(rm -rf /*)", "Read(.env)"],
    "ask":   ["Bash(git push *)"],
    "allow": ["Bash(npm run *)", "Read"]
  }
}
```

| Tier    | Meaning                                              | Use for |
|---------|-----------------------------------------------------|---------|
| `allow` | runs silently, no prompt                            | read-only / non-destructive inspection |
| `ask`   | prompts the user to confirm before running          | anything that **mutates** state |
| `deny`  | rejected outright, the model sees an error          | **dangerous / forbidden** actions |

### Rule syntax (`Tool(specifier)`)

| Form | Matches |
|---|---|
| `Bash` | every Bash command |
| `Bash(kubectl get *)` | commands starting `kubectl get` (`*` spans any text; a trailing ` *` / `:*` is a word boundary, so `ls *` matches `ls -la` but not `lsof`) |
| `Read(.env)` | a `.env` at any depth under the working dir (gitignore semantics) |
| `Edit(/src/**)` | edits under `<project root>/src/` (anchors: `//abs`, `~/home`, `/project-root`, `./cwd`) |
| `Read` / `Edit` / `Write` | every file read / edit / write (bare) |
| `mcp__server` / `mcp__server__tool` | an MCP server's tools / one exact tool |
| `Agent(Explore)` | a specific sub-agent |

Tool fan-out (so you don't double-write rules): a `Read` rule also covers
`Grep`/`Glob`; an `Edit` rule also covers `Write`/`revert`.

**Bash specifics you can rely on:** compound commands are split on `&&`, `||`,
`;`, `|` and matched per-part (a deny on any part denies the whole); wrappers
(`timeout`, `nice`, `xargs`, …) are stripped first; and common read-only
commands (`ls`, `cat`, `grep`, `git status`, …) are allowed by a **built-in
read-only allowlist** — so you rarely need to list them.

### yoke extensions over Claude syntax

- **Reasons + project scope** — write a rule as an object to attach a prompt
  reason and a `cwd` (the rule then only applies inside that directory tree):
  `{ "rule": "Bash(terraform apply *)", "reason": "infra change", "cwd": "/srv/app" }`.
- **Regex escape hatch** — for patterns globs can't express (alternations,
  word boundaries, matching across arguments), use `/regex/` or the object form
  `{ "regex": "...", "tools": ["Bash"], "reason": "..." }`. The pattern is a Go
  regexp matched against `toolName <json args>`. **Always scope a Bash regex with
  `"tools": ["Bash"]`** so it can't accidentally fire on a `Write` whose *content*
  merely mentions the pattern.

### `defaultMode`

`default` (prompt on unmatched), `acceptEdits` (auto-allow edits in the working
dir), `plan` (reads only, edits denied), `dontAsk` (deny unless allowed),
`bypassPermissions` (allow all except the hard safety floor). Leave it
`default` unless the user asks otherwise.

### Safety floor (you don't write this)

The Bash tool has an independent hard floor (`rm -rf /`, `mkfs`, fork bombs, …)
that is refused regardless of any rule or mode. You still add explicit `deny`
rules for project-specific dangers — but you can rely on the floor as a backstop.

## 2. Procedure

### Step 1 — Inventory the tool surfaces

List every command family / tool the agent or skill will realistically use.
Sources to inspect:

- The skill's own instructions and any commands it tells the agent to run.
- The MCP servers it mounts (their `mcp__server__*` tool names).
- The sub-agents it delegates to (`Agent(name)`).
- Files it reads or writes (paths / globs).

Group them by command family (e.g. all `kubectl …`, all `git …`, all `psql …`),
not one rule per invocation.

### Step 2 — Pre-classify each group (your proposal)

For each group, draft a **proposed** tier using this default heuristic:

- **allow** — pure inspection / read-only: `get`, `list`, `describe`, `logs`,
  `status`, `diff`, `view`, `show`, `version`, `cat`, `ls`, dry-runs.
- **ask** — anything that **mutates**: writes/deletes files, `apply`/`create`/
  `delete`/`patch`/`edit`, `push`, package installs, `restart`/`scale`, network
  egress (`curl -o`, `wget`, `ssh`), privilege use (`sudo`).
- **deny** — destructive or forbidden: wiping disks/dirs, disabling
  hooks/signing/firewalls, reading credential files (`.ssh/id_*`, `.aws/credentials`,
  `/etc/shadow`), writing system config.

When unsure, default to the **stricter** tier (deny > ask > allow).

### Step 3 — Ask the user to confirm (REQUIRED)

Do **not** finalise from the heuristic alone. Use the `ask_user` tool to confirm
the policy with the user before writing. Ask **per group**, offering the tier
options and your recommendation. Prefer batching related groups into one
multi-question prompt so the user answers a short wizard, not a stream of cards.

Pattern for each identified group, ask a single-select question:

> **How should `<group>` (e.g. `kubectl apply/delete/patch …`) be handled?**
> - Allow (run silently)
> - Ask the user each time *(recommended)*
> - Deny (forbid entirely)
> - Use the safe default (fall through to ask)

Also confirm, when relevant:

- **Scope** — should an allow/ask be limited to a project directory (`cwd`)?
- **`defaultMode`** — keep `default`, or does the user want `plan` / `acceptEdits`?
- **Sensitive paths** — confirm the deny-list of files the agent must never read
  or write.

Record the user's answers; those, not your heuristic, are the source of truth.

### Step 4 — Write the rules

Translate each confirmed group into the smallest correct rule(s):

- Read-only command family → `Bash(<cmd> <verb> *)` globs in `allow` (skip ones
  already covered by the built-in read-only allowlist).
- Mutating family → put the *whole family* in `ask`. If it's a clean prefix use a
  glob (`Bash(git push *)`); if it's an alternation use the regex hatch with
  `"tools": ["Bash"]` and a `reason`.
- Dangerous → `deny`, regex hatch for anything globs can't express, with a clear
  `reason`.
- File policy → `Read(...)` / `Edit(...)` gitignore-style rules; credential
  files in `deny`.
- Add a human-readable `reason` to every `ask`/`deny` rule — it is shown in the
  prompt and the audit panel.

Keep it **minimal**: fewer, well-grouped rules beat many overlapping ones. Don't
re-allow what the read-only allowlist already covers.

### Step 5 — Validate

- The file must be valid JSON in the shape `{ "permissions": { "allow": [...],
  "ask": [...], "deny": [...] } }`.
- Sanity-check it parses and compiles (no rule silently dropped) with:
  ```bash
  yoke permissions convert <path/to/permissions.json>
  ```
  (prints the normalised config; an invalid rule is dropped, so compare rule
  counts). To rewrite an old-format file in place use `-w` (keeps a `.bak`).
- Spot-check a few decisions in your head against deny → ask → allow: pick one
  representative command per tier and confirm which rule fires first.

## 3. Where the file goes

- **Project / global policy** — `permissions.json` in the config search chain
  (`.agents/`, `$HOME/.yoke/`, `/etc/yoke/`). The web UI **Settings → Permissions**
  panel edits this; saves hot-reload.
- **A skill's bundled overlay** — `permissions.json` next to the skill's
  `SKILL.md`. It is merged **read-only** on top of the active policy when the
  skill is loaded, and shown in a separate block in the Permissions panel. Use
  this to ship the exact allow/ask/deny a skill needs with the skill itself.

## 4. Worked example

User wants a skill that runs Terraform read-only freely, confirms applies, and
forbids state deletion. After Step 3 the user confirmed: plan/show → allow,
apply/import → ask, `state rm`/`destroy` → deny.

```json
{
  "permissions": {
    "allow": [
      "Bash(terraform plan *)",
      "Bash(terraform show *)",
      "Bash(terraform validate *)",
      "Bash(terraform output *)"
    ],
    "ask": [
      { "rule": "Bash(terraform apply *)",  "reason": "applies infrastructure changes — confirm the target workspace" },
      { "rule": "Bash(terraform import *)", "reason": "mutates Terraform state — confirm" }
    ],
    "deny": [
      { "regex": "\\bterraform\\s+(destroy|state\\s+rm)\\b", "tools": ["Bash"], "reason": "destructive Terraform operation is forbidden for this agent" }
    ]
  }
}
```

## Checklist

- [ ] Inventoried every command family / MCP tool / sub-agent / file surface.
- [ ] Pre-classified each group (stricter tier when unsure).
- [ ] **Asked the user to confirm each group's tier** via `ask_user` (recommendation shown).
- [ ] Confirmed `cwd` scope, `defaultMode`, and sensitive-path denies where relevant.
- [ ] Wrote minimal grouped rules; Bash regexes scoped with `"tools": ["Bash"]`; reasons on ask/deny.
- [ ] Validated JSON shape and `yoke permissions convert` (no dropped rules).
- [ ] Placed the file correctly (config layer, or bundled next to the skill).
