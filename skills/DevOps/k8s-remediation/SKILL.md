---
name: k8s-remediation
description: Fix a broken Kubernetes cluster or workload. Use when the user wants to repair, remediate, recover, or unstick something in k8s — a pod stuck in Terminating, CrashLoopBackOff, ImagePullBackOff, OOMKilled, Evicted pods, a namespace or PVC stuck Terminating, a node NotReady, a stuck rollout, CoreDNS/etcd/apiserver problems, finalizers, drain, or "broken cluster".
metadata:
  author: blouargant@chapsvision.com
  tags: "kubernetes, remediation, repair, recovery, finalizers, playbook"
---

# Kubernetes Remediation

This skill is the *fix-it* playbook — what to actually **do** once a failure
is identified. It is the remediation counterpart to the diagnosis skills.

## When to use it

- Use **`k8s-triage`** first to *classify* the failure (it gathers state and
  names the category). Use **this** skill to *apply the fix*.
- Use **`k8s-log-investigation`** when the cause is hidden in large logs.
- Reach for this skill when the user says "fix", "repair", "unstick",
  "recover", or names a specific stuck/broken state.

If you have not yet confirmed the failure category, run `k8s-triage` first —
do not guess at a remedy.

## Prerequisites

A `kubectl` reachable via `Bash`, **or** a Kubernetes MCP server. The runbook
commands are written as `kubectl`; with an MCP server, issue the equivalent
read/patch/delete operations through its tools (the same resource, namespace,
and gating apply). Control-plane and node-level fixes additionally need
host/SSH access (or `kubeadm` on the node); when only `kubectl`/MCP is
available and a fix needs host access, hand the exact command to the user
instead of running it.

## Safety procedure — follow on EVERY remediation

1. **Confirm context and namespace.** Run `kubectl config current-context`
   and quote it back. Treat any context **or** target namespace whose name
   contains `prod`/`prd`/`production` as production: refuse to mutate it
   without an explicit per-action user override.
2. **Confirm the diagnosis.** State the failure category and name the single
   resource you are about to change. Change exactly one resource per step,
   and report it before moving to the next.
3. **Dry-run first.** For any mutation, prefer `--dry-run=server` (or show
   the patch/diff) and present it before applying.
4. **Gate destructive actions.** Force-delete, finalizer edits, `delete`,
   `drain`, `cordon`, scale-to-zero, and control-plane changes each require
   an explicit "yes" for *that specific action* — never a blanket approval.
   Force-delete only after confirming the pod's node is genuinely gone or the
   kubelet is unrecoverable — a force-delete on a live node can double-run a
   stateful workload and corrupt data.
5. **Apply the smallest reversible step**, capturing the current spec
   (`kubectl get -o yaml`) before mutating. Re-check state before the next
   step, and report what changed and what to watch.

## Problem → fix index

Open `references/runbook.md` and read the matching section for exact,
gated commands. Categories covered:

| Symptom | Runbook section |
|---|---|
| Pod stuck `Terminating` forever | Pod stuck Terminating |
| Pod stuck `Pending` / Unschedulable | Pod Pending / Unschedulable |
| `CrashLoopBackOff` | CrashLoopBackOff |
| `ImagePullBackOff` / `ErrImagePull` | Image pull failures |
| `OOMKilled` | OOMKilled |
| Pod `Evicted` (node pressure) | Evicted pods |
| Service has no endpoints | Service / endpoints |
| Rollout stuck / not progressing | Stuck rollout |
| Namespace stuck `Terminating` | Namespace stuck Terminating |
| PVC/PV stuck `Pending` or `Terminating` | Storage (PVC/PV) |
| Custom resource (CR) won't delete | Stuck finalizers (generic) |
| Node `NotReady` | Node NotReady |
| Drain blocked by PodDisruptionBudget | Draining a node |
| Cluster DNS failing | CoreDNS |
| API server unreachable | Control plane: API server |
| etcd unhealthy / out of space | Control plane: etcd |
| kubelet down on a node | Control plane: kubelet |
| Expired cluster certificates | Control plane: certificates |

## Hard rules

These hold in addition to the safety procedure above (which already covers
gating, production guardrails, and reversibility):

1. **Access boundaries.** On RBAC denial, escalate to the user — never retry
   with different credentials.
2. **No secrets.** Never echo secret/token values surfaced during a fix.

## Output rule

End every run with `Result: ok | needs-attention | blocked`.
