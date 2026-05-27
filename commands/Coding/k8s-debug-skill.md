---
description: Author a Kubernetes debug-skill ConfigMap and wire it into the project's Helm chart (or raw manifests). Verifies the chart is debug-skill ready, drafts the ConfigMap covering the described failures, and places it in the right folder.
argument-hint: [short description of the failure(s) to encode]
---

You are helping the developer create a Kubernetes **debug-skill ConfigMap**
for their application and integrate it into the project's Helm chart (or
raw Kubernetes manifests). The final output is repo changes the developer
will commit — never `kubectl apply` to a live cluster.

User intent: $ARGUMENTS

If the user intent above is empty, start by asking: which application,
which failure(s) to encode (one symptom per error, with a real log line
or event reason where possible), and whether they want to cover one
specific error or a family of related errors.

## Workflow

Follow these phases in order. Use the relevant skill for each phase; do
not improvise the contents — the skills know the schema.

### Phase 1 — Chart readiness

Invoke the **k8s-debug-skill-chart-setup** skill. It will:

- Locate the chart (`Chart.yaml`, `templates/`) or manifest tree.
- Audit every workload template for the canonical labels
  (`app.kubernetes.io/name`, `app.kubernetes.io/instance`, and the
  recommended set) on both the workload `metadata.labels` and the
  pod-template `spec.template.metadata.labels`.
- Propose edits — including introducing or extending `_helpers.tpl`
  helpers (`<chart>.labels`, `<chart>.selectorLabels`) — when labels are
  missing or inconsistent.
- Refuse to silently change immutable `spec.selector.matchLabels`; if
  that's required, surface it as a `blocked` result for the user to
  decide.
- Create `templates/debug-skills/` (or the manifest-equivalent folder)
  if it doesn't already exist.

Apply the proposed edits once the user agrees. Move on only when the
chart is debug-skill ready — otherwise the skill will never match the
running pods.

### Phase 2 — Author the ConfigMap

Invoke the **k8s-debug-skill-author** skill. It will:

- Elicit the five required inputs (pod identity, optional version
  constraint, error signatures, diagnosis, safe next step).
- Apply the grouping rule: if the user described multiple errors,
  decide whether they share a diagnosis family (one CM, multi-variant
  body) or need separate CMs.
- Draft `data.meta` (selector + matchers + applies_to) and `data.body`
  (single-variant or multi-variant markdown).
- Lint the result against the contract.
- Suggest a filename: `<app>-<short-cause>.yaml` for a single-variant
  CM, `<app>-<family>.yaml` for a family CM.

Place the file(s) at `<chart-root>/templates/debug-skills/<name>.yaml`
for a Helm chart, or the manifest-equivalent location. Template the
`metadata.name` and `metadata.namespace` with Helm values where it makes
sense.

### Phase 3 — Verify the chart still renders

For a Helm chart:

```bash
helm template <chart-root>
```

Confirm in the rendered output that:

- The new ConfigMap is present in `templates/debug-skills/`.
- It carries `metadata.labels["yoke.dev/debug-skill"] = "true"`.
- The selector's `labels` and/or `image` values match what the chart's
  Deployment template renders for its pods.

For raw manifests, the equivalent is `kubectl apply --dry-run=client -f`
on the new file plus the affected workload templates.

### Phase 4 — Hand back

Report to the user:

- Path(s) of new debug-skill ConfigMap file(s).
- Path(s) of any chart edits made in Phase 1.
- A one-line suggested commit message, e.g.
  `feat(debug-skills): add orders-api postgres connectivity skill`.

## Hard rules

- Never run `kubectl apply`, `helm install`, or any cluster-mutating
  command. This command produces repo changes only.
- Never invent failure modes or causes. If the user can't provide a
  concrete error signature, pause and ask them to grab one.
- Never bundle unrelated errors into a single ConfigMap to keep the
  CM count down — the grouping rule in the author skill is the
  authority on when to merge and when to split.
- If the chart can't be made debug-skill ready in Phase 1 (e.g. an
  immutable `matchLabels` would have to change), stop and report —
  don't paper over it by leaning on `selector.image` alone unless the
  user explicitly accepts that trade-off.
