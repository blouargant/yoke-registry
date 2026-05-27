---
name: k8s-debug-skill-chart-setup
description: Prepare an application's Helm chart or Kubernetes manifests to be debug-skill ready — ensure Deployments, StatefulSets, DaemonSets, and pod templates carry the canonical labels that debug-skill selectors key on, and set up the conventional folder layout for debug-skill ConfigMaps. Use when bootstrapping a new chart, onboarding an existing chart to debug skills, or diagnosing why debug skills are not matching the app's pods.
metadata:
  author: blouargant@chapsvision.com
  tags: "kubernetes, helm, labels, debug, configmap, chart, bootstrap"
---

# Kubernetes Debug-Skill Chart Setup

Debug skills (authored via
[k8s-debug-skill-author](../k8s-debug-skill-author/SKILL.md)) match a
failing pod against a `selector` block. If the pod's labels don't carry
what the selector expects, the skill is invisible — no matter how good
its body is.

> The runtime triage half that consumes these ConfigMaps lives in a
> separate agent profile (DevOps / SRE). A coding agent does not need
> it loaded to prepare a chart.

This skill walks a developer through making their chart "debug-skill ready":
the right labels on the right objects, a Helm helper to keep them
consistent, and a conventional location for the debug-skill ConfigMaps that
the chart will ship.

## When to use it

- A team is **bootstrapping a new chart** and wants debug skills from day one.
- A team is **onboarding an existing chart** and wants to fix labels before
  authoring any debug-skill ConfigMaps.
- Triage reported `0 candidates because no skill's selector matched` and the
  user wants to fix the underlying label gap.
- The user asks "what labels do I need?" or "why aren't my debug skills
  matching?"

Do not use it when:

- The user only wants to author a single ConfigMap and their chart already
  uses `app.kubernetes.io/name` correctly. Go straight to
  [k8s-debug-skill-author](../k8s-debug-skill-author/SKILL.md).
- The user is asking general Helm best-practice questions unrelated to debug
  skills. This skill is debug-skill specific.

## The canonical label set

Two labels are **required** for debug skills to work reliably; three more
are **recommended**.

| Label | Required? | What it does | Used by |
|---|---|---|---|
| `app.kubernetes.io/name` | yes | Names the application (`orders-api`). Stable across releases. | `selector.labels` in every debug skill for the app |
| `app.kubernetes.io/instance` | yes | Names the specific release (`orders-api-prod`). Distinguishes prod/staging. | Operators filtering by release |
| `app.kubernetes.io/component` | recommended | Sub-role (`api`, `worker`, `migration`). | `selector.labels` for component-specific skills |
| `app.kubernetes.io/version` | recommended | App version (`2.4.1`). Mirrored from image tag. | `applies_to` in skills with version-bounded bugs |
| `app.kubernetes.io/part-of` | optional | Higher-level system name (`orders-platform`). | Cross-cutting skills |

Reference: [Kubernetes recommended labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/).

For raw manifests with no Helm release, set `app.kubernetes.io/instance` to
the same value as `app.kubernetes.io/name` or ask the user for an environment
identifier (e.g. `orders-api-prod`).

**Rule of thumb:** if the debug skill team can write `selector.labels: {app.kubernetes.io/name: <app>}` and have it actually match, the chart is ready.

## Where the labels must appear

For a Deployment (and analogously for StatefulSet / DaemonSet / Job):

1. **`metadata.labels`** on the Deployment itself.
   - Lets operators find the workload (`kubectl get deploy -l app.kubernetes.io/name=orders-api`).
2. **`spec.template.metadata.labels`** on the pod template.
   - This is the set the **pods** carry at runtime — what debug-skill
     selectors actually match against.
   - **This is the most commonly forgotten one.** Labels on the Deployment
     do not propagate to pods automatically.
3. **`spec.selector.matchLabels`** on the Deployment.
   - Must be a stable subset (typically `app.kubernetes.io/name` +
     `app.kubernetes.io/instance`) that won't change across releases —
     `matchLabels` is immutable after creation.

See [assets/deployment-example.yaml](assets/deployment-example.yaml) for
a fully labelled Deployment.

## Helm: factor labels with `_helpers.tpl`

Repeating the same eight lines of labels in every template is the path to
drift. Define two named templates once and reuse them everywhere:

- **`<chart>.labels`** — the full set (for `metadata.labels` on workloads,
  Services, and pod templates).
- **`<chart>.selectorLabels`** — the immutable subset (for
  `spec.selector.matchLabels` only; do **not** use on pod templates — use
  the full `<chart>.labels` helper there instead).

A drop-in starter lives at [assets/_helpers.tpl](assets/_helpers.tpl);
adapt the chart name to match your `Chart.yaml`.

For umbrella charts, define helpers in each sub-chart using that sub-chart's
name; do not share a single helper across sub-charts.

## Folder layout for the ConfigMaps

When a chart owns debug skills, put them next to the other templates:

```
charts/orders-api/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── _helpers.tpl
│   ├── deployment.yaml
│   ├── service.yaml
│   └── debug-skills/                  # <-- one ConfigMap per failure mode
│       ├── db-timeout.yaml
│       ├── stripe-401.yaml
│       └── oom-during-import.yaml
```

For raw manifests, the same pattern under `base/` or wherever the
operator-facing manifests live.

## Procedure

1. **Locate the chart.** Ask for the chart root if not provided. Read
   `Chart.yaml` to confirm name and version.
2. **Audit every workload template** (`Deployment`, `StatefulSet`,
   `DaemonSet`, `Job`, `CronJob`). For each:
   - Does `metadata.labels` include `app.kubernetes.io/name` and
     `app.kubernetes.io/instance`?
   - Does `spec.template.metadata.labels` include the **full canonical label
     set** (and therefore is a superset of `spec.selector.matchLabels`)?
   - Does `spec.selector.matchLabels` use only **immutable** labels?
   - **For CronJob**, the pod template lives at
     `spec.jobTemplate.spec.template.metadata.labels`; audit that path
     instead. For Operator-managed CRDs, labels must be set in the CR
     spec — not on auto-generated pods.
   - **2d.** Before proposing any edit to `spec.selector.matchLabels` on an
     existing Deployment, STOP and apply the Hard Rule about immutability
     — emit `blocked` instead.
   - Where the other label-location answers are no, prepare an edit.
3. **Check for an existing `_helpers.tpl`.**
   - If it defines `<chart>.labels` and `<chart>.selectorLabels`, reuse them.
   - If not, propose adding the helpers from
     [assets/_helpers.tpl](assets/_helpers.tpl).
4. **Refactor templates to use the helpers** rather than inlining labels:
   ```yaml
   metadata:
     labels: {{- include "<chart>.labels" . | nindent 4 }}
   spec:
     selector:
       matchLabels: {{- include "<chart>.selectorLabels" . | nindent 6 }}
     template:
       metadata:
         labels: {{- include "<chart>.labels" . | nindent 8 }}
   ```
5. **Create the debug-skills folder** at `templates/debug-skills/` (or, for
   raw manifests, at `<manifest-root>/debug-skills/`, e.g.
   `base/debug-skills/` for Kustomize layouts) so authors have an obvious
   place to drop ConfigMaps. Empty `.gitkeep` is fine for v0.
6. **Verify with a `helm template` dry run** (or `kubectl apply --dry-run=client`
   for raw manifests). Confirm:
   - All workloads render with the canonical labels on `metadata.labels`
     and `spec.template.metadata.labels`.
   - `matchLabels` only uses fields that won't change between releases.
   If `helm template` fails due to missing values, supply a minimal `--set`
   or `-f values-debug.yaml` and re-run; if it still fails, emit
   `needs-input` and report the rendering error.
7. **Hand off to [k8s-debug-skill-author](../k8s-debug-skill-author/SKILL.md).**
   The chart is now ready; authors can start writing ConfigMaps.

## Hard rules

- **Preserve non-canonical labels during migration.** If existing
  `matchLabels` use non-canonical keys (e.g., `app: orders-api`), keep them
  in `matchLabels` and the pod template AND add the canonical labels
  alongside. Do not remove the legacy keys — removing them changes the
  immutable selector.
- **Never change `spec.selector.matchLabels` on an existing Deployment.**
  It is immutable. If the current value is wrong, you must delete and
  recreate the Deployment — flag this to the user and let them decide
  when to absorb the downtime. Do not just propose the edit silently.
- **`spec.template.metadata.labels` must be a superset of
  `spec.selector.matchLabels`**, otherwise the Deployment fails admission.
  Check this before showing edits.
- **Do not invent label values.** `app.kubernetes.io/name` should come
  from `.Chart.Name` (or be asked of the user); never make one up.
- **Helm-only operations.** This skill edits chart sources or proposes
  diffs. It does not run `helm install` or `kubectl apply` — those are
  the team's deploy pipeline.

## Output rule

Always finish with a single line: `Result: ok | needs-input | blocked`.

- `ok` — chart audited, edits proposed or applied, ready for the author skill.
- `needs-input` — stopped because the chart layout was unclear or
  `Chart.yaml` was missing.
- `blocked` — refused because the existing Deployment has wrong
  `matchLabels` and changing it requires the user to authorise a recreate.
